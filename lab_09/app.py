import argparse
import csv
import json
import math
import os
import time
import uuid
from pathlib import Path

import psycopg2
import redis

from plot import draw

ROOT = Path(__file__).resolve().parent
QUERY = (ROOT / 'query.sql').read_text()


def get_connection():
    return psycopg2.connect(
        dbname=os.getenv('PGDATABASE', 'warehouse_lab09'),
        user=os.getenv('PGUSER', 'artyom'),
        password=os.getenv('PGPASSWORD', '123'),
        host=os.getenv('PGHOST', 'localhost'),
        port=os.getenv('PGPORT', '5432')
    )


def read_db(conn):
    with conn.cursor() as cur:
        cur.execute(QUERY)
        return [list(row) for row in cur.fetchall()]


def read_cache(conn, cache, prefix):
    # Проверяем маленький счетчик, тяжелую статистику берем из Redis.
    with conn.cursor() as cur:
        cur.execute('select version from sc1.lab09_cache_version where id = 1;')
        version = cur.fetchone()[0]
    key = f'{prefix}:{version}'
    value = cache.get(key)
    if value is not None:
        return json.loads(value), True, version
    rows = read_db(conn)
    cache.set(key, json.dumps(rows, ensure_ascii=False), ex=60)
    return rows, False, version


def add_row(conn, ids):
    with conn.cursor() as cur:
        cur.execute('select coalesce(max(id), 0) + 1 from sc1.arrival_item;')
        next_id = cur.fetchone()[0]
        cur.execute('select min(id) from sc1.arrival;')
        arrival_id = cur.fetchone()[0]
        cur.execute('select min(id) from sc1.product;')
        product_id = cur.fetchone()[0]
        if arrival_id is None or product_id is None:
            raise RuntimeError('Нужна заполненная база из первой лабы')
        cur.execute('''
            insert into sc1.arrival_item(id, arrival_id, product_id, quantity, unit_price)
            values (%s, %s, %s, 50000, 1);
        ''', (next_id, arrival_id, product_id))
    conn.commit()
    ids.append(next_id)


def change_data(conn, mode, ids, change_number):
    if mode == 'insert':
        add_row(conn, ids)
        return
    with conn.cursor() as cur:
        if mode == 'update':
            cur.execute('update sc1.arrival_item set quantity = quantity + 50000 where id = %s;', (ids[0],))
        elif mode == 'delete':
            cur.execute('delete from sc1.arrival_item where id = %s;', (ids[change_number],))
    conn.commit()


def run_scenario(reader, writer, cache, mode, args, output):
    ids = []
    change_count = math.floor((args.samples - 1) * args.interval / args.change_interval)
    prefix = f'lab09:{os.getenv("PGDATABASE", "warehouse_lab09")}:{uuid.uuid4().hex}'
    rows = []
    try:
        if mode == 'update':
            add_row(writer, ids)
        elif mode == 'delete':
            for _ in range(change_count):
                add_row(writer, ids)

        start = time.monotonic()
        next_change = args.change_interval
        changes_done = 0
        for sample in range(args.samples):
            due = start + sample * args.interval
            time.sleep(max(0, due - time.monotonic()))
            elapsed = time.monotonic() - start
            changed = False
            while mode != 'none' and elapsed >= next_change and changes_done < change_count:
                change_data(writer, mode, ids, changes_done)
                next_change += args.change_interval
                changes_done += 1
                changed = True

            # Оба способа читают один снимок: между ними данные не разойдутся.
            try:
                before = time.perf_counter()
                direct_rows = read_db(reader)
                db_ms = (time.perf_counter() - before) * 1000
                before = time.perf_counter()
                cached_rows, hit, version = read_cache(reader, cache, prefix)
                cache_ms = (time.perf_counter() - before) * 1000
                if direct_rows != cached_rows:
                    raise RuntimeError('Результат кэша отличается от PostgreSQL')
                reader.commit()
            except Exception:
                reader.rollback()
                raise
            row = {
                'scenario': mode, 'sample': sample, 'seconds': round(elapsed, 3),
                'db_ms': round(db_ms, 4), 'cache_ms': round(cache_ms, 4),
                'cache_hit': int(hit), 'changed': int(changed),
                'version': version, 'rows_equal': 1
            }
            rows.append(row)
            output.writerow(row)
            print(f'{mode:6} {sample:2}: БД {db_ms:.3f} мс, кэш {cache_ms:.3f} мс, hit={hit}, change={changed}', flush=True)
    finally:
        reader.rollback()
        writer.rollback()
        # Удаляем только записи, которые создал этот запуск.
        if ids:
            with writer.cursor() as cur:
                cur.execute('delete from sc1.arrival_item where id = any(%s);', (ids,))
            writer.commit()
        for key in cache.scan_iter(match=prefix + ':*'):
            cache.delete(key)
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--scenario', choices=['all', 'none', 'insert', 'delete', 'update'], default='all')
    parser.add_argument('--samples', type=int, default=12)
    parser.add_argument('--interval', type=float, default=5)
    parser.add_argument('--change-interval', type=float, default=10)
    parser.add_argument('--output', type=Path, default=ROOT / 'results')
    args = parser.parse_args()
    if args.samples < 2 or args.interval <= 0 or args.change_interval <= 0:
        parser.error('Нужно минимум два замера и положительные интервалы')
    if args.scenario != 'none' and (args.samples - 1) * args.interval < args.change_interval:
        parser.error('Запуск слишком короткий: изменение данных не успеет произойти')

    reader = get_connection()
    writer = get_connection()
    cache = redis.Redis(host=os.getenv('REDIS_HOST', 'localhost'),
                        port=int(os.getenv('REDIS_PORT', '6379')),
                        db=9, decode_responses=True)
    try:
        cache.ping()
        reader.set_session(isolation_level='REPEATABLE READ', readonly=True)
        args.output.mkdir(parents=True, exist_ok=True)
        modes = ['none', 'insert', 'delete', 'update'] if args.scenario == 'all' else [args.scenario]
        fieldnames = ['scenario', 'sample', 'seconds', 'db_ms', 'cache_ms', 'cache_hit', 'changed', 'version', 'rows_equal']
        with (args.output / 'timings.csv').open('w', newline='') as file:
            output = csv.DictWriter(file, fieldnames=fieldnames, lineterminator='\n')
            output.writeheader()
            for mode in modes:
                run_scenario(reader, writer, cache, mode, args, output)
                file.flush()
        draw(args.output / 'timings.csv')
    finally:
        reader.close()
        writer.close()
        cache.close()


if __name__ == '__main__':
    main()

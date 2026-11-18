import argparse
import json
import time
import uuid
from datetime import datetime
from pathlib import Path


def make_file(directory, count):
    directory.mkdir(parents=True, exist_ok=True)
    state = directory / '.next_id'
    first_id = int(state.read_text()) if state.exists() else int(time.time())
    if first_id + count > 2147483647:
        raise ValueError('Закончился диапазон integer для id')
    rows = []
    for i in range(first_id, first_id + count):
        rows.append({'id': i, 'name': f'Поставщик {i}', 'phone': f'+7888{i:010d}'})

    # Сначала резервируем id: после сбоя будут пропуски, но не повторы.
    state_tmp = state.with_suffix('.tmp')
    state_tmp.write_text(str(first_id + count))
    state_tmp.replace(state)
    stamp = datetime.now().strftime('%Y%m%dT%H%M%S%f')
    path = directory / f'{uuid.uuid4().hex}_provider_{stamp}.json'
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding='utf-8')
    temporary.replace(path)
    print('Создан:', path, flush=True)
    return path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--directory', type=Path, default=Path(__file__).parent / 'input')
    parser.add_argument('--count', type=int, default=5)
    parser.add_argument('--interval', type=float, default=300)
    parser.add_argument('--once', action='store_true')
    args = parser.parse_args()
    if args.count < 1 or args.interval <= 0:
        parser.error('Количество записей и интервал должны быть положительными')
    try:
        while True:
            started = time.monotonic()
            make_file(args.directory, args.count)
            if args.once:
                break
            time.sleep(max(0, args.interval - (time.monotonic() - started)))
    except KeyboardInterrupt:
        print('\nГенератор остановлен')


if __name__ == '__main__':
    main()

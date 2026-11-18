import csv
import sys
from collections import defaultdict
from pathlib import Path
from statistics import mean

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

TITLES = {
    'none': 'Без изменения данных', 'insert': 'Добавление строк',
    'delete': 'Удаление строк', 'update': 'Изменение строк'
}


def draw(path):
    path = Path(path)
    groups = defaultdict(list)
    with path.open() as file:
        for row in csv.DictReader(file):
            groups[row['scenario']].append(row)
    summary = ['# Результаты замеров', '',
               'Время в миллисекундах. Это результаты конкретного запуска, а не гарантия ускорения.', '',
               '| Сценарий | PostgreSQL, среднее | Redis, среднее | Попаданий в кэш |',
               '| --- | ---: | ---: | ---: |']
    for mode, rows in groups.items():
        seconds = [float(row['seconds']) for row in rows]
        direct = [float(row['db_ms']) for row in rows]
        cached = [float(row['cache_ms']) for row in rows]
        fig, ax = plt.subplots(figsize=(9, 4))
        ax.plot(seconds, direct, 'o-', label='PostgreSQL')
        ax.plot(seconds, cached, 'o-', label='Redis (включая проверку версии)')
        for row in rows:
            if row['changed'] == '1':
                ax.axvline(float(row['seconds']), color='gray', linestyle=':', alpha=0.6)
        ax.set(title=TITLES[mode], xlabel='Время от начала сценария, с', ylabel='Время запроса, мс')
        ax.grid(alpha=0.25)
        ax.legend()
        fig.tight_layout()
        fig.savefig(path.parent / f'{mode}.png', dpi=140)
        plt.close(fig)
        hits = sum(int(row['cache_hit']) for row in rows)
        summary.append(f'| {TITLES[mode]} | {mean(direct):.4f} | {mean(cached):.4f} | {hits}/{len(rows)} |')
    summary += ['', 'Первый запрос и запрос после изменения данных дают cache miss: статистика пересчитывается.',
                'Пунктир на графиках отмечает изменения данных.',
                'На маленькой базе проверка версии и обмен с Redis могут стоить дороже самого SQL.',
                'Все сравниваемые результаты проверяются на совпадение.']
    (path.parent / 'summary.md').write_text('\n'.join(summary) + '\n')
    print('Графики и summary.md сохранены в', path.parent)


if __name__ == '__main__':
    draw(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).parent / 'results/timings.csv')

import csv
import os
import random
from collections import defaultdict
from datetime import datetime, timedelta

random.seed(42)

OUT_DIR = "/tmp/warehouse_data"

N_PRODUCTS = 1000
N_EMPLOYEES = 1000
N_PROVIDERS = 100
N_ARRIVALS = 1000
N_EXPENSES = 1000
N_STORAGE_LOCATIONS = 1000
ARRIVAL_ITEMS_PER_ARRIVAL = 2
N_INVENTORY = 1000

DATE_START = datetime(2025, 1, 1, 8, 0, 0)
ARRIVAL_DATE_END = datetime(2026, 6, 1, 18, 0, 0)
EXPENSE_DATE_START = datetime(2025, 3, 1, 8, 0, 0)
DATE_END = datetime(2026, 9, 1, 18, 0, 0)


def random_datetime(start, end):
    seconds = int((end - start).total_seconds())
    return start + timedelta(seconds=random.randint(0, seconds))


def write_csv(filename, header, rows):
    path = os.path.join(OUT_DIR, filename)
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter=";")
        writer.writerow(header)
        writer.writerows(rows)


os.makedirs(OUT_DIR, exist_ok=True)

# product.csv
product_kinds = [
    ("Болт М8", "шт"),
    ("Гайка М8", "шт"),
    ("Шайба М8", "шт"),
    ("Кабель", "м"),
    ("Провод", "м"),
    ("Разъем", "шт"),
    ("Предохранитель", "шт"),
    ("Реле", "шт"),
    ("Клемма", "шт"),
    ("Датчик", "шт"),
]

products = []
for i in range(1, N_PRODUCTS + 1):
    base_name, unit = random.choice(product_kinds)
    name = f"{base_name} {i:04d}"[:20]
    article = f"ART-{i:06d}"
    description = f"Складская позиция №{i}: {base_name}"
    products.append([i, name, unit, article, description])

write_csv("product.csv", ["id", "name", "unit", "article", "description"], products)

# employee.csv
surnames = [
    "Иванов", "Петров", "Сидоров", "Смирнов", "Кузнецов",
    "Попов", "Соколов", "Лебедев", "Козлов", "Новиков",
]
initials = ["И.И.", "А.А.", "С.П.", "М.В.", "Д.О.", "Е.Н.", "Р.А.", "П.С.", "В.И.", "Н.М."]
job_titles = ["Кладовщик", "Оператор склада", "Менеджер", "Старший кладовщик", "Инвентаризатор"]

employees = []
employee_names = {}
for i in range(1, N_EMPLOYEES + 1):
    full_name = f"{random.choice(surnames)} {random.choice(initials)}"[:30]
    phone = f"+7999{i:07d}"[:20]
    job_title = random.choice(job_titles)[:30]
    employees.append([i, full_name, phone, job_title])
    employee_names[i] = full_name

write_csv("employee.csv", ["id", "full_name", "phone", "job_title"], employees)

# provider.csv
providers = []
for i in range(1, N_PROVIDERS + 1):
    name = f"Поставщик {i:03d}"[:20]
    phone = f"+7888{i:07d}"[:20]
    providers.append([i, name, phone])

write_csv("provider.csv", ["id", "name", "phone"], providers)

# arrival.csv
arrivals = []
arrival_times = {}
for i in range(1, N_ARRIVALS + 1):
    arrival_time = random_datetime(DATE_START, ARRIVAL_DATE_END)
    provider_id = random.randint(1, N_PROVIDERS)
    invoice_num = f"IN-{i:07d}"
    responsible_employee_id = random.randint(1, N_EMPLOYEES)
    responsible_employee = employee_names[responsible_employee_id]

    arrivals.append([
        i,
        arrival_time.strftime("%Y-%m-%d %H:%M:%S"),
        provider_id,
        invoice_num,
        responsible_employee,
    ])
    arrival_times[i] = arrival_time

write_csv(
    "arrival.csv",
    ["id", "arrival_time", "provider_id", "invoice_num", "responsible_employee"],
    arrivals,
)

# arrival_item.csv
arrival_items = []
batches_by_product = defaultdict(list)
arrival_item_id = 1

for arrival_id in range(1, N_ARRIVALS + 1):
    used_products = set()

    for _ in range(ARRIVAL_ITEMS_PER_ARRIVAL):
        product_id = random.randint(1, N_PRODUCTS)
        while product_id in used_products:
            product_id = random.randint(1, N_PRODUCTS)
        used_products.add(product_id)

        quantity = random.randint(50, 500)
        unit_price = round(random.uniform(10, 5000), 3)

        arrival_items.append([
            arrival_item_id,
            arrival_id,
            product_id,
            quantity,
            f"{unit_price:.3f}",
        ])

        batches_by_product[product_id].append({
            "arrival_item_id": arrival_item_id,
            "arrival_time": arrival_times[arrival_id],
            "remaining": quantity,
        })

        arrival_item_id += 1

for product_id in batches_by_product:
    batches_by_product[product_id].sort(key=lambda x: x["arrival_time"])

write_csv(
    "arrival_item.csv",
    ["id", "arrival_id", "product_id", "quantity", "unit_price"],
    arrival_items,
)

# expense.csv, expense_item.csv, expense_distribution.csv
expenses = []
expense_items = []
expense_distributions = []
expense_item_id = 1
distribution_id = 1

for expense_id in range(1, N_EXPENSES + 1):
    expense_time = random_datetime(EXPENSE_DATE_START, DATE_END)
    recipient = f"Получатель {random.randint(1, 200):03d}"[:30]
    basis = f"Заявка на выдачу №{expense_id}"
    responsible_employee_id = random.randint(1, N_EMPLOYEES)
    responsible_employee = employee_names[responsible_employee_id]

    expenses.append([
        expense_id,
        expense_time.strftime("%Y-%m-%d %H:%M:%S"),
        recipient,
        basis,
        responsible_employee,
    ])

    eligible_products = []
    for product_id, batches in batches_by_product.items():
        available = sum(
            batch["remaining"]
            for batch in batches
            if batch["arrival_time"] <= expense_time
        )
        if available > 0:
            eligible_products.append((product_id, available))

    if not eligible_products:
        continue

    random.shuffle(eligible_products)
    item_count = random.randint(1, 2)

    for product_id, available in eligible_products[:item_count]:
        quantity = random.randint(1, min(available, 100))
        expense_items.append([expense_item_id, expense_id, product_id, quantity, ""])

        need = quantity
        for batch in batches_by_product[product_id]:
            if need == 0:
                break
            if batch["arrival_time"] > expense_time or batch["remaining"] <= 0:
                continue

            take = min(need, batch["remaining"])
            expense_distributions.append([
                distribution_id,
                batch["arrival_item_id"],
                expense_item_id,
                take,
                "",
            ])
            batch["remaining"] -= take
            need -= take
            distribution_id += 1

        if need != 0:
            raise RuntimeError("Ошибка генерации FIFO: не удалось распределить расход.")

        expense_item_id += 1

write_csv("expense.csv", ["id", "expense_time", "recipient", "basis", "responsible_employee"], expenses)
write_csv("expense_item.csv", ["id", "expense_id", "product_id", "quantity", "note"], expense_items)
write_csv(
    "expense_distribution.csv",
    ["id", "arrival_item_id", "expense_item_id", "quantity", "note"],
    expense_distributions,
)

# storage_location.csv
storage_locations = [[1, "Главный склад", "склад", 1000000, ""]]
zone_ids = []
next_id = 2

for zone_num in range(1, 11):
    zone_id = next_id
    next_id += 1
    zone_ids.append(zone_id)
    storage_locations.append([
        zone_id,
        f"Зона {zone_num}",
        "зона",
        random.randint(20000, 50000),
        1,
    ])

rack_ids = []
while next_id <= min(N_STORAGE_LOCATIONS, 210):
    rack_id = next_id
    next_id += 1
    rack_ids.append(rack_id)
    storage_locations.append([
        rack_id,
        f"Стеллаж {rack_id:04d}"[:30],
        "стеллаж",
        random.randint(1000, 5000),
        random.choice(zone_ids),
    ])

while next_id <= N_STORAGE_LOCATIONS:
    location_id = next_id
    next_id += 1
    storage_locations.append([
        location_id,
        f"Полка {location_id:04d}"[:30],
        "полка",
        random.randint(100, 1000),
        random.choice(rack_ids),
    ])

write_csv(
    "storage_location.csv",
    ["id", "name", "location_type", "capacity", "parent_location_id"],
    storage_locations,
)

# inventory.csv
leaf_location_ids = [row[0] for row in storage_locations if row[2] == "полка"]
inventory_rows = []

for i in range(1, N_INVENTORY + 1):
    inventory_rows.append([
        i,
        random.randint(1, N_PRODUCTS),
        random.choice(leaf_location_ids),
        random.randint(1, N_EMPLOYEES),
        random.randint(0, 500),
    ])

write_csv(
    "inventory.csv",
    ["id", "product_id", "storage_location_id", "employee_id", "actual_quantity"],
    inventory_rows,
)

print(f"Готово. CSV-файлы созданы в: {OUT_DIR}")
print(f"product.csv: {len(products)}")
print(f"employee.csv: {len(employees)}")
print(f"provider.csv: {len(providers)}")
print(f"arrival.csv: {len(arrivals)}")
print(f"expense.csv: {len(expenses)}")
print(f"arrival_item.csv: {len(arrival_items)}")
print(f"expense_item.csv: {len(expense_items)}")
print(f"expense_distribution.csv: {len(expense_distributions)}")
print(f"storage_location.csv: {len(storage_locations)}")
print(f"inventory.csv: {len(inventory_rows)}")


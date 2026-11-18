import psycopg2
from psycopg2 import sql

DB_CONFIG = {
    "dbname": "warehouse",
    "user": "artyom",
    "password": "123",
    "host": "localhost",
    "port": "5432"
}

def get_connection():
    return psycopg2.connect(**DB_CONFIG)

def print_table(cursor):
    """Вспомогательная функция для красивого вывода результатов"""
    if cursor.description:
        # Выводим заголовки колонок
        headers = [desc[0] for desc in cursor.description]
        print(" | ".join(headers))
        print("-" * 50)
        # Выводим строки
        for row in cursor.fetchall():
            print(" | ".join(str(item) for item in row))
    else:
        print("Запрос выполнен успешно (нет возвращаемых данных).")

def main():
    while True:
        print("\n" + "="*30)
        print("МЕНЮ (Лабораторная работа №6)")
        print("="*30)
        print("1. Скалярный запрос")
        print("2. Запрос с JOIN")
        print("3. Запрос с CTE и оконными функциями")
        print("4. Запрос к метаданным (колонки таблицы)")
        print("5. Вызвать скалярную функцию")
        print("6. Вызвать табличную функцию")
        print("7. Вызвать хранимую процедуру")
        print("8. Вызвать системную функцию")
        print("9. Создать таблицу")
        print("10. Вставить данные в созданную таблицу")
        print("0. Выход")
        
        choice = input("Выберите пункт: ")

        try:
            conn = get_connection()
            conn.autocommit = True
            cur = conn.cursor()

            if choice == '1':
                print("\n--- 1. Скалярный запрос: Общая сумма приходов ---")
                cur.execute("select sum(quantity * unit_price) from sc1.arrival_item;")
                result = cur.fetchone()[0]
                print(f"Общая сумма: {result}")

            elif choice == '2':
                print("\n--- 2. Запрос с JOIN: Товары и сотрудники ---")
                cur.execute("""
                select p.name, ai.quantity, e.full_name
                from sc1.arrival_item ai
                join sc1.product p on ai.product_id = p.id 
                join sc1.inventory i on i.product_id = p.id 
                join sc1.employee e on i.employee_id = e.id limit 5;
                """)

                print_table(cur)

            elif choice == '3':
                print("\n--- 3. CTE и оконные функции ---")
                cur.execute("""
                    with product_totals as (
                        select product_id, sum(quantity) as total_qty
                        from sc1.arrival_item
                        group by product_id
                    )
                    select p.name, pt.total_qty, 
                           sum(pt.total_qty) over() as grand_total,
                           rank() over(order by pt.total_qty desc) as rank
                    from product_totals pt
                    join sc1.product p on p.id = pt.product_id
                    limit 5;
                """)
                print_table(cur)

            elif choice == '4':
                print("\n--- 4. Метаданные: Колонки таблицы product ---")
                cur.execute("""
                    select column_name, data_type, is_nullable
                    from information_schema.columns
                    where table_schema = 'sc1' and table_name = 'product';
                """)
                print_table(cur)

            elif choice == '5':
                print("\n--- 5. Скалярная функция: Сумма прихода для товара id=1 ---")
                cur.execute("select sc1.get_product_arrival_sum(1);")
                print(f"Сумма прихода: {cur.fetchone()[0]}")

            elif choice == '6':
                print("\n--- 6. Табличная функция: Приходы для товара id=1 ---")
                cur.execute("select * from sc1.get_arrivals_by_product(1);")
                print_table(cur)

            elif choice == '7':
                print("\n--- 7. Хранимая процедура: Сброс нулевых цен ---")
                cur.execute("call sc1.reset_zero_prices();")
                print("Процедура выполнена успешно!")

            elif choice == '8':
                print("\n--- 8. Системная функция: Версия БД ---")
                cur.execute("select version();")
                print(cur.fetchone()[0])

            elif choice == '9':
                print("\n--- 9. Создание таблицы audit_log ---")
                cur.execute("""
                    create table if not exists sc1.audit_log (
                        id serial primary key,
                        action_text text,
                        created_at timestamp default now()
                    );
                """)
                print("Таблица sc1.audit_log создана (или уже существует).")

            elif choice == '10':
                print("\n--- 10. Вставка данных в audit_log ---")
                cur.execute("""
                    insert into sc1.audit_log (action_text) 
                    values ('пользователь запустил приложение');
                """)
                print("Данные успешно вставлены!")

            elif choice == '0':
                print("Выход...")
                break
            else:
                print("Неверный пункт меню.")

        except Exception as e:
            print(f"Ошибка: {e}")
        finally:
            if 'cur' in locals():
                cur.close()
            if 'conn' in locals():
                conn.close()

if __name__ == "__main__":
    main()

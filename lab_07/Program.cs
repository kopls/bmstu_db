using System.Text.Json;
using System.Xml.Linq;
using LinqToDB;
using LinqToDB.Data;
using LinqToDB.Mapping;
using Npgsql;

class Program
{
    static string connection_string = Environment.GetEnvironmentVariable("DB_CONNECTION")
        ?? "Host=localhost;Port=5432;Database=warehouse;Username=artyom;Password=123";

    static void show<T>(string title, IEnumerable<T> rows)
    {
        Console.WriteLine("\n" + title);
        foreach (var row in rows.Take(10))
            Console.WriteLine(row);
    }

    static void objects(DataConnection db)
    {
        // ToList загружает данные. Дальше запросы идут к объектам в памяти.
        var products = db.GetTable<Product>().ToList();
        var items = db.GetTable<ArrivalItem>().ToList();

        var q1 = from p in products
                 where p.unit == "шт"
                 orderby p.name ascending, p.id ascending
                 select new { p.id, p.name, p.unit };
        show("1. Штучные товары", q1);

        var q2 = from ai in items
                 let total = ai.quantity * ai.unit_price
                 where total > 10000
                 orderby total descending
                 select new { ai.id, total };
        show("2. Стоимость позиции поступления", q2);

        var q3 = from p in products
                 group p by p.unit into units
                 orderby units.Count() descending
                 select new { unit = units.Key, count = units.Count() };
        show("3. Количество товаров по единицам измерения", q3);

        var q4 = from p in products
                 join ai in items on p.id equals ai.product_id
                 orderby ai.id
                 select new { p.name, ai.quantity, ai.unit_price };
        show("4. Товары и поступления", q4);

        var q5 = from p in products
                 join ai in items on p.id equals ai.product_id into arrivals
                 let quantity = arrivals.Sum(ai => ai.quantity)
                 orderby quantity descending, p.id
                 select new { p.name, quantity };
        show("5. Суммарное поступление каждого товара", q5);

        var q6 = from p in products
                 select new { p.id, p.name } into short_product
                 where short_product.id <= 5
                 select short_product;
        show("6. Продолжение запроса через into", q6);
    }

    static void xml(DataConnection db)
    {
        // Документ получается SELECT-запросом из настоящей таблицы.
        var products = db.Query<Product>(
            "select id, name, unit, article, description from sc1.product order by id").ToList();
        if (products.Count == 0)
            throw new Exception("Таблица product пустая");

        var document = new XDocument(new XElement("products",
            from p in products
            select new XElement("product",
                new XElement("id", p.id),
                new XElement("name", p.name),
                new XElement("unit", p.unit),
                new XElement("article", p.article),
                new XElement("description", p.description))));
        document.Save("products.xml");

        var loaded = XDocument.Load("products.xml");
        var query = from p in loaded.Root!.Elements("product")
                    where (string?)p.Element("unit") == "шт"
                    select new { id = (int)p.Element("id")!, name = (string?)p.Element("name") };
        show("1. Чтение XML", query);

        var first_id = products[0].id;
        var first = (from p in loaded.Root!.Elements("product")
                     where (int)p.Element("id")! == first_id
                     select p).Single();
        first.SetElementValue("name", "Товар из XML");
        loaded.Save("products.xml");
        Console.WriteLine("2. Название первого товара изменено в XML");

        int next_id = loaded.Root!.Elements("product").Max(p => (int)p.Element("id")!) + 1;
        loaded.Root.Add(new XElement("product",
            new XElement("id", next_id),
            new XElement("name", "Новый товар"),
            new XElement("unit", "шт"),
            new XElement("article", "XML-NEW"),
            new XElement("description", "Добавлен только в XML")));
        loaded.Save("products.xml");
        Console.WriteLine("3. Новый товар добавлен в XML. Таблица БД не менялась");
    }

    static void database(DataConnection db)
    {
        // Здесь IQueryable: LINQ преобразуется в SQL и выполняется PostgreSQL.
        var q1 = from p in db.GetTable<Product>()
                 where p.unit == "шт"
                 orderby p.id
                 select new { p.id, p.name };
        Console.WriteLine(q1.Take(5).ToString());
        show("1. Однотабличный запрос", q1.Take(5));

        var q2 = from p in db.GetTable<Product>()
                 join ai in db.GetTable<ArrivalItem>() on p.id equals ai.product_id
                 orderby ai.id
                 select new { p.name, ai.quantity, ai.unit_price };
        show("2. Многотабличный запрос", q2.Take(5));

        using var transaction = db.BeginTransaction();
        int next_id = db.GetTable<Product>().Max(p => (int?)p.id).GetValueOrDefault() + 1;
        var product = new Product {
            id = next_id, name = "Тест LINQ", unit = "шт",
            article = "L07-" + Guid.NewGuid().ToString("N")[..12],
            description = "Проверка добавления, изменения и удаления"
        };

        Console.WriteLine("3. Добавлено строк: " + db.Insert(product));
        Console.WriteLine("4. Изменено строк: " + db.GetTable<Product>()
            .Where(p => p.id == next_id).Set(p => p.name, "Измененный товар").Update());
        Console.WriteLine("5. Удалено строк: " + db.GetTable<Product>()
            .Where(p => p.id == next_id).Delete());
        transaction.Rollback();
        Console.WriteLine("Тестовая транзакция отменена");
    }

    static void setup(DataConnection db)
    {
        // Нужные объекты создаются перед заданием с базой данных.
        db.Execute("""
            -- Табличная функция из lab_03/data_modules.sql.
            create or replace function sc1.get_arrivals_by_product(p_product_id integer)
            returns table (arrival_item_id integer, quantity integer, unit_price numeric)
            as $$
                select ai.id, ai.quantity, ai.unit_price
                from sc1.arrival_item ai
                where ai.product_id = p_product_id;
            $$ language sql;

            -- Процедура возвращает строки одним JSON-массивом через выходной параметр.
            create or replace procedure sc1.get_arrivals_for_lab07(
                in p_product_id integer,
                inout rows_json jsonb default null
            )
            language plpgsql
            as $$
            begin
                select coalesce(jsonb_agg(to_jsonb(t) order by t.arrival_item_id), '[]'::jsonb)
                into rows_json
                from sc1.get_arrivals_by_product(p_product_id) t;
            end;
            $$;
            """);
    }

    static void procedure()
    {
        using var conn = new NpgsqlConnection(connection_string);
        conn.Open();
        // Приложение посылает только CALL. SELECT находится внутри процедуры.
        using var cmd = new NpgsqlCommand("call sc1.get_arrivals_for_lab07(@id, null)", conn);
        cmd.Parameters.AddWithValue("id", 1);
        using var reader = cmd.ExecuteReader();
        reader.Read();
        using var result = JsonDocument.Parse(reader.GetString(0));
        Console.WriteLine("6. Поступления товара №1 через хранимую процедуру:");
        Console.WriteLine(JsonSerializer.Serialize(result.RootElement,
            new JsonSerializerOptions { WriteIndented = true }));
    }

    static void Main(string[] args)
    {
        try
        {
            using var db = new DataConnection(ProviderName.PostgreSQL, connection_string);
            string choice;
            if (args.Length > 0)
                choice = args[0];
            else
            {
                Console.WriteLine("1. LINQ to Objects\n2. LINQ to XML\n3. LINQ к PostgreSQL\n4. Все задания");
                choice = Console.ReadLine() ?? "";
            }
            if (choice == "1" || choice == "4") objects(db);
            if (choice == "2" || choice == "4") xml(db);
            if (choice == "3" || choice == "4") { setup(db); database(db); procedure(); }
            if (!new[] { "1", "2", "3", "4" }.Contains(choice))
                throw new Exception("Неизвестный пункт меню");
        }
        catch (Exception e)
        {
            Console.Error.WriteLine("Ошибка: " + e.Message);
            Environment.ExitCode = 1;
        }
    }
}

[Table(Schema = "sc1", Name = "product")]
public class Product
{
    [PrimaryKey, Column] public int id { get; set; }
    [Column] public string name { get; set; } = "";
    [Column] public string unit { get; set; } = "";
    [Column] public string article { get; set; } = "";
    [Column] public string? description { get; set; }
}

[Table(Schema = "sc1", Name = "arrival_item")]
public class ArrivalItem
{
    [PrimaryKey, Column] public int id { get; set; }
    [Column] public int arrival_id { get; set; }
    [Column] public int product_id { get; set; }
    [Column] public int quantity { get; set; }
    [Column] public decimal unit_price { get; set; }
}

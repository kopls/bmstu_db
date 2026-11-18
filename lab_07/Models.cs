using LinqToDB.Mapping;

// Поля как в таблицах первой лабы.
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

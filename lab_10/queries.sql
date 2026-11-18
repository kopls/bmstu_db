-- Макросы времени и переменная product подставляются Grafana.

-- Количество товаров
select count(*) as "Товаров"
from sc1.product p
where p.id in (${product:csv});

-- Стоимость поступлений
select coalesce(sum(ai.quantity * ai.unit_price), 0) as "Стоимость"
from sc1.arrival_item ai
join sc1.arrival a on a.id = ai.arrival_id
where $__timeFilter(a.arrival_time)
  and ai.product_id in (${product:csv});

-- Стоимость поступлений по месяцам
select date_trunc('month', a.arrival_time) as "time",
       sum(ai.quantity * ai.unit_price)::double precision as "Стоимость"
from sc1.arrival a
join sc1.arrival_item ai on ai.arrival_id = a.id
where $__timeFilter(a.arrival_time)
  and ai.product_id in (${product:csv})
group by 1
order by 1;

-- Топ-10 товаров по поступлениям
select p.name as "Товар", sum(ai.quantity)::bigint as "Количество"
from sc1.arrival_item ai
join sc1.product p on p.id = ai.product_id
join sc1.arrival a on a.id = ai.arrival_id
where $__timeFilter(a.arrival_time)
  and p.id in (${product:csv})
group by p.id, p.name
order by "Количество" desc, p.id
limit 10;

-- Фактические остатки
select p.id as "ID", p.name as "Товар", p.unit as "Единица",
       coalesce(sum(i.actual_quantity), 0)::bigint as "Остаток"
from sc1.product p
left join sc1.inventory i on i.product_id = p.id
where p.id in (${product:csv})
group by p.id, p.name, p.unit
order by "Остаток" desc, p.id
limit 30;

-- Поступления по поставщикам
select pr.name as "Поставщик", count(distinct a.id)::bigint as "Поступлений"
from sc2.provider pr
join sc1.arrival a on a.provider_id = pr.id
join sc1.arrival_item ai on ai.arrival_id = a.id
where $__timeFilter(a.arrival_time)
  and ai.product_id in (${product:csv})
group by pr.id, pr.name
order by "Поступлений" desc, pr.id
limit 10;

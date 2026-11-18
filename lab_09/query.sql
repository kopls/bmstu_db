-- Суммарное поступление по товарам, как в lab_03 и lab_06.
select p.id, p.name, sum(ai.quantity)::bigint as total_quantity
from sc1.arrival_item ai
join sc1.product p on p.id = ai.product_id
group by p.id, p.name
order by total_quantity desc, p.id
limit 10;

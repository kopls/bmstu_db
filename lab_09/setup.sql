-- Версия результата меняется в той же транзакции, что и данные.
create table if not exists sc1.lab09_cache_version (
    id integer primary key check (id = 1),
    version bigint not null default 0
);
insert into sc1.lab09_cache_version(id) values (1) on conflict do nothing;

create or replace function sc1.lab09_invalidate_cache()
returns trigger
language plpgsql
as $$
begin
    update sc1.lab09_cache_version set version = version + 1 where id = 1;
    return null;
end;
$$;

drop trigger if exists lab09_arrival_changed on sc1.arrival_item;
create trigger lab09_arrival_changed
after insert or update or delete or truncate on sc1.arrival_item
for each statement execute function sc1.lab09_invalidate_cache();

drop trigger if exists lab09_product_changed on sc1.product;
create trigger lab09_product_changed
after insert or update or delete or truncate on sc1.product
for each statement execute function sc1.lab09_invalidate_cache();

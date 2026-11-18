-- Пароль передается через psql -v grafana_password=...
select 'create role warehouse_grafana login'
where not exists (select 1 from pg_roles where rolname = 'warehouse_grafana')
\gexec

alter role warehouse_grafana with password :'grafana_password';
select format('grant connect on database %I to warehouse_grafana', current_database())
\gexec
grant usage on schema sc1, sc2 to warehouse_grafana;
grant select on sc1.product, sc1.arrival, sc1.arrival_item,
    sc1.inventory, sc1.storage_location, sc2.provider to warehouse_grafana;

-- Ejecutar con psql como administrador del clúster.
\pset pager off
\du
SELECT grantee,table_schema,table_name,privilege_type,is_grantable
FROM information_schema.role_table_grants
WHERE table_schema IN ('public','reportes') AND grantee NOT IN ('postgres','admin_datos')
ORDER BY 1,2,3,4;
SELECT grantee,table_name,column_name,privilege_type,is_grantable
FROM information_schema.role_column_grants
WHERE table_schema='public' AND grantee IN
('rol_soporte','rol_auth_owner','rol_operacion_owner','rol_app_escritura')
ORDER BY 1,2,3,4;
SELECT r.rolname AS miembro,g.rolname AS grupo,m.admin_option,m.inherit_option,m.set_option
FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.member
JOIN pg_roles g ON g.oid=m.roleid WHERE r.rolname IN
('app_web','soporte_demo','reportes_demo','admin_datos') ORDER BY 1,2;
SELECT n.nspname,p.proname,r.rolname AS propietario,p.prosecdef,p.proconfig,p.proacl
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
JOIN pg_roles r ON r.oid=p.proowner WHERE n.nspname='public'
AND p.proname IN ('fn_autenticar','fn_resetear_password','sp_crear_pedido') ORDER BY 2;
SELECT n.nspname,c.relname,c.relacl FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relkind='S' ORDER BY 2;
\ddp

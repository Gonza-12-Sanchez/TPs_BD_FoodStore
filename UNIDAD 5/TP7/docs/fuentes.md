# Fuentes técnicas

Material de cátedra y repositorios: ver procedencia.md.

Documentación primaria consultada el 14/15 de octubre de 2026:

- PostgreSQL 16, ALTER DEFAULT PRIVILEGES: https://www.postgresql.org/docs/16/sql-alterdefaultprivileges.html. Los defaults corresponden al rol creador; un REVOKE por esquema no elimina una concesión predeterminada global.
- PostgreSQL 16, Error Reporting and Logging: https://www.postgresql.org/docs/16/runtime-config-logging.html. Alcance de all/mod, prefijo, parámetros Bind y sensibilidad de literales SQL.
- PostgreSQL 16, CREATE FUNCTION: https://www.postgresql.org/docs/16/sql-createfunction.html. Funciones SECURITY DEFINER, search_path y revocación del acceso PUBLIC.
- pgAudit, repositorio oficial: https://github.com/pgaudit/pgaudit. Diferencias entre registro por relación, parámetros y conteos de filas. La documentación de la rama principal puede diferir de versiones compatibles con PostgreSQL 16; no se instaló la extensión en este trabajo.

Los informes se limitan a decisiones técnicas del laboratorio. No presentan asesoramiento jurídico ni declaran que una técnica determinista garantice anonimización irreversible.

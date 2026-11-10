# Entorno de las evidencias entregadas

- PostgreSQL 16.15, binarios de paquetes oficiales de Ubuntu 24.04.
- Instancia temporal exclusiva, base food_store_u5, TCP loopback y puerto 55435.
- Clientes Python/psycopg2 y psql 16.15.
- Usuarios, claves de aplicación, teléfonos y correos completamente ficticios.
- Claves de los logins del motor generadas aleatoriamente y excluidas del repositorio.
- Captura del servidor del 15 de octubre de 2026 a las 00:39:31 UTC (14 de octubre, 21:39:31 en Argentina).

## Particularidad del contenedor de pruebas

El entorno del asistente expone solamente UID 0, no permite crear otro UID y no admite sockets Unix para este proceso. Para ejecutar los binarios de prueba se utilizó una capa temporal de compatibilidad que presenta una identidad de usuario alternativa a sus comprobaciones de identidad/propiedad. El servidor y los clientes se conservaron en la misma sesión y usaron TCP local. Esa adaptación no altera el motor SQL, sus roles o los resultados de las consultas, pero **no acredita aislamiento real mediante un usuario no privilegiado del sistema operativo**.

Las comprobaciones de autorización se realizaron con logins SQL distintos autenticados por SCRAM. La configuración 0600 se verificó en pg_settings; no se afirma que este contenedor demuestre protección productiva del sistema operativo. Para reproducir el proyecto se debe usar una instalación normal y ejecutar PostgreSQL con su cuenta de servicio sin privilegios, como indica README. La adaptación del contenedor no se incorpora como método de instalación para el estudiante.

## Alcance de los resultados

Los scripts, los errores 28P01/42501 y las salidas de consultas proceden de PostgreSQL real; no son resultados estimados ni respuestas simuladas. Los logs entregados se transformaron solo para ocultar identificadores/secretos según la política del laboratorio.

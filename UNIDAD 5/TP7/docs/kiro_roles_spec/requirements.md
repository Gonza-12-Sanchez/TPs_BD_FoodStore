# Requisitos de roles y permisos

Especificación previa a la implementación de `roles.sql`.

## Alcance

Base aislada `food_store_u5`, PostgreSQL 16+, sin datos de personas reales. Se reutilizan las cinco tablas, vistas y lógica de pedidos del repositorio TPI-BD. Las funciones de autenticación, roles y anonimización se reconstruyen porque no estaban en los repositorios aportados.

## Roles y justificación

| Rol | Tipo | Operación y motivo |
|---|---|---|
| rol_app_lectura | NOLOGIN | Consultar las dos vistas del catálogo, sin leer las tablas completas. |
| rol_app_escritura | NOLOGIN | Leer pedidos y detalles, insertar cabeceras con columnas acotadas, cambiar estado y crear compras mediante el procedimiento validado. |
| rol_soporte | NOLOGIN | Leer columnas identificatorias y vistas de atención, y resetear claves de cuentas USUARIO mediante una función controlada. |
| rol_reportes | NOLOGIN | Leer resultados agregados del esquema reportes sin acceso a identidades o hashes. |
| rol_auth_owner | NOLOGIN | Ejecutar internamente la consulta de credenciales y la actualización de contraseña; no es miembro de admin_datos. |
| rol_operacion_owner | NOLOGIN | Ejecutar internamente el procedimiento de compra con permisos puntuales sobre inventario, usuarios y pedidos. |
| app_web | LOGIN | Heredar lectura y escritura, y llamar fn_autenticar como conexión del backend. |
| admin_datos | LOGIN, NOINHERIT | Ser dueño de los objetos de negocio y gestionar sus permisos, sin SUPERUSER, CREATEDB o CREATEROLE. La creación inicial de identidades queda en el administrador del clúster. |
| soporte_demo | LOGIN | Representar una conexión de soporte en el laboratorio. El permiso directo de autenticación se otorga exclusivamente para reproducir la secuencia didáctica. |
| reportes_demo | LOGIN | Verificar mediante una conexión real que los reportes funcionan y que usuario queda inaccesible. |

## Criterios verificables

1. Los grupos no abren sesiones. Los logins operativos no crean objetos, roles ni bases y no tienen membresía ni ADMIN OPTION sobre admin_datos.
2. app_web no accede a usuario, contraseña, celular o modificaciones directas de inventario. No puede alterar el total o el usuario de un pedido existente.
3. Soporte puede consultar `id, nombre, apellido, mail, rol, eliminado`, pero no `contrasena`, `celular` ni `created_at`. La lectura no tiene restricción por fila: es una capacidad de soporte cuyo abuso debe auditarse.
4. El reseteo no puede cambiar credenciales ADMIN, cuentas eliminadas o claves fuera de 12 a 72 bytes. Las funciones usan SQL estático, dueño limitado y search_path fijo.
5. No se otorga DELETE, TRUNCATE ni delegación de permisos a roles operativos. Los DML de prueba se ejecutan en BEGIN/ROLLBACK.
6. Las tablas futuras de public permanecen privadas. Solo los objetos que admin_datos cree en reportes reciben SELECT automático para rol_reportes.
7. Las funciones futuras de admin_datos no reciben EXECUTE para PUBLIC. Los privilegios por defecto se comprueban creando objetos temporales dentro de una transacción revertida.
8. El procedimiento de compra debe seguir funcionando sin conceder a app_web acceso directo a los hashes o UPDATE de stock.

## Exclusiones

RLS no se incorpora en este TP: el backend es una identidad técnica compartida y el diseño heredado no verifica el usuario final en cada operación. No se afirma aislamiento entre clientes. Un `SET app.usuario_actual` controlable por esa misma conexión no prueba por sí solo una identidad confiable.

La instalación se aplica a un clúster de laboratorio nuevo. Los roles de PostgreSQL tienen alcance de clúster: no ejecutar sin adaptación en una instancia compartida.

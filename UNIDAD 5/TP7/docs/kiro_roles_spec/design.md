# Diseño previo a la implementación

Diseño del esquema de identidades y privilegios de FoodStore.

## Separación de responsabilidades

`postgres` crea inicialmente los roles y la base. `admin_datos` posee public, reportes, tablas y vistas de negocio. Dos dueños NOLOGIN permiten funciones SECURITY DEFINER sin darles la autoridad completa del administrador.

El diseño revisa el ejemplo de clase: en lugar de INSERT/UPDATE de tabla completa, concede columnas específicas en pedido y reserva la escritura de detalles y stock a `sp_crear_pedido`. Esto evita que una sesión de aplicación cambie directamente importes calculados. La función de reseteo solo modifica cuentas de negocio USUARIO.

## Matriz de acceso directo

| Identidad | Recurso | Permiso |
|---|---|---|
| rol_app_lectura | public.v_productos_vigentes, public.v_categorias_vigentes | SELECT |
| rol_app_escritura | public.pedido, public.detalle_pedido | SELECT |
| rol_app_escritura | public.pedido(fecha, forma_pago, usuario_id) | INSERT |
| rol_app_escritura | public.pedido(estado) | UPDATE |
| rol_app_escritura | public.pedido_id_seq | USAGE |
| rol_app_escritura | public.sp_crear_pedido(bigint, forma_pago, jsonb) | EXECUTE |
| rol_soporte | public.usuario(id,nombre,apellido,mail,rol,eliminado) | SELECT de columna |
| rol_soporte | public.v_usuarios_publico, public.v_pedidos_resumen | SELECT |
| rol_soporte | public.fn_resetear_password(bigint,text) | EXECUTE |
| rol_reportes | reportes.v_usuarios_por_rol_mes, reportes.v_ventas_categoria_mes | SELECT |
| app_web, soporte_demo | public.fn_autenticar(text,text) | EXECUTE |
| rol_auth_owner | usuario(id,mail,rol,contrasena,eliminado) / usuario(contrasena) | SELECT / UPDATE de columna |
| rol_operacion_owner | producto, detalle_pedido, pedido | SELECT |
| rol_operacion_owner | usuario(id,eliminado) | SELECT de columna |
| rol_operacion_owner | producto(stock) / pedido(total) | UPDATE de columna |
| rol_operacion_owner | pedido, detalle_pedido | INSERT |
| rol_operacion_owner | pedido_id_seq, detalle_pedido_id_seq | USAGE |
| rol_operacion_owner | public.calcular_total_pedido(bigint) | EXECUTE |

Todos los anteriores tienen USAGE en public; solo reportes y admin_datos usan reportes. Los propietarios conservan los derechos inherentes sobre sus objetos, que no se confunden con permisos de aplicación.

## Privilegios futuros

No se copia el ejemplo `GRANT SELECT ON TABLES TO rol_reportes` sobre public. Se limita al esquema reportes, que solo debe contener agregaciones previamente revisadas. Se revoca EXECUTE predeterminado a PUBLIC para funciones de admin_datos **sin IN SCHEMA**, porque la concesión implícita global no se elimina con un REVOKE local de esquema.

## Verificación

Se entregan `\du`, information_schema.role_table_grants, role_column_grants, membresías, ACL de rutinas y secuencias. El programa de pruebas compara permisos efectivos sobre todas las columnas y tablas contra una matriz esperada, además de realizar operaciones permitidas y denegadas con logins reales.

## Auditoría

Conexiones, desconexiones y DML se registran en el servidor. Durante B y C se utiliza log_statement=all para incluir SELECT. La función fn_autenticar emite un evento FS_AUTH con resultado y cuenta, sin contraseña. El registro del SQL podría contener literales: todo el laboratorio es sintético y los archivos compartidos pasan por sanitización.

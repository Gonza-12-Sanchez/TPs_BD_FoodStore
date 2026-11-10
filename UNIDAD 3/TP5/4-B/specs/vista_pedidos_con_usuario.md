# spec: vista_pedidos_con_usuario
Objetivo: exponer pedidos con datos del usuario sin exponer la contraseña.
Columnas a exponer: ped.id, ped.fecha, ped.estado, ped.total, ped.forma_pago, ped.usuario_id, u.nombre, u.apellido, u.mail, u.rol
Filtro de vigencia: ped.eliminado = FALSE AND u.eliminado = FALSE
Columna oculta por seguridad: u.contrasena (y celular si se desea). Se debe poder dar GRANT SELECT sobre la vista sin dar acceso a la tabla usuario.
Equivalencia: debe devolver lo mismo que SELECT con JOIN pedido-usuario y ese filtro.

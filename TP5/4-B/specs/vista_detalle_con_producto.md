# spec: vista_detalle_con_producto
Objetivo: simplificar el detalle de un pedido con el nombre del producto.
Columnas a exponer: dp.id, dp.pedido_id, dp.producto_id, pr.nombre AS producto_nombre, dp.cantidad, dp.precio_unitario, dp.subtotal
Filtro de vigencia: dp.eliminado = FALSE AND pr.eliminado = FALSE
Columna oculta: ninguna.
Equivalencia: debe devolver lo mismo que SELECT con JOIN detalle_pedido-producto y ese filtro.

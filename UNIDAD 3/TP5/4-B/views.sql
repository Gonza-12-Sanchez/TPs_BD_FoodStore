-- V1 — Productos vigentes con su categoría
-- Spec: vista_productos_vigentes.md
CREATE OR REPLACE VIEW v_productos_vigentes AS
SELECT p.id,
       p.nombre,
       p.precio,
       p.stock,
       p.disponible,
       p.categoria_id,
       c.nombre AS categoria_nombre
FROM producto p
JOIN categoria c ON c.id = p.categoria_id
WHERE p.eliminado = FALSE
  AND c.eliminado = FALSE
  AND p.disponible = TRUE;

-- V2 — Pedidos con datos del usuario (vista con criterio de seguridad)
-- Spec: vista_pedidos_con_usuario.md
-- Oculta: usuario.contrasena (y celular) para poder dar GRANT SELECT sin exponer tabla base
CREATE OR REPLACE VIEW v_pedidos_con_usuario AS
SELECT ped.id,
       ped.fecha,
       ped.estado,
       ped.total,
       ped.forma_pago,
       ped.usuario_id,
       u.nombre AS usuario_nombre,
       u.apellido AS usuario_apellido,
       u.mail AS usuario_mail,
       u.rol AS usuario_rol
FROM pedido ped
JOIN usuario u ON u.id = ped.usuario_id
WHERE ped.eliminado = FALSE
  AND u.eliminado = FALSE;

-- V3 — Detalle de pedido con nombre del producto
-- Spec: vista_detalle_con_producto.md
CREATE OR REPLACE VIEW v_detalle_con_producto AS
SELECT dp.id,
       dp.pedido_id,
       dp.producto_id,
       pr.nombre AS producto_nombre,
       dp.cantidad,
       dp.precio_unitario,
       dp.subtotal
FROM detalle_pedido dp
JOIN producto pr ON pr.id = dp.producto_id
WHERE dp.eliminado = FALSE
  AND pr.eliminado = FALSE;



-- V1 - Productos vigentes
(SELECT * FROM v_productos_vigentes EXCEPT SELECT p.id, p.nombre, p.precio, p.stock, p.disponible, p.categoria_id, c.nombre FROM producto p JOIN categoria c ON c.id=p.categoria_id WHERE p.eliminado=FALSE AND c.eliminado=FALSE AND p.disponible=TRUE)
UNION ALL
(SELECT p.id, p.nombre, p.precio, p.stock, p.disponible, p.categoria_id, c.nombre FROM producto p JOIN categoria c ON c.id=p.categoria_id WHERE p.eliminado=FALSE AND c.eliminado=FALSE AND p.disponible=TRUE EXCEPT SELECT * FROM v_productos_vigentes);
-- debe dar 0 filas

-- V2 - Pedidos con usuario (la de seguridad, sin contrasena)
(SELECT * FROM v_pedidos_con_usuario EXCEPT SELECT ped.id, ped.fecha, ped.estado, ped.total, ped.forma_pago, ped.usuario_id, u.nombre, u.apellido, u.mail, u.rol FROM pedido ped JOIN usuario u ON u.id=ped.usuario_id WHERE ped.eliminado=FALSE AND u.eliminado=FALSE)
UNION ALL
(SELECT ped.id, ped.fecha, ped.estado, ped.total, ped.forma_pago, ped.usuario_id, u.nombre, u.apellido, u.mail, u.rol FROM pedido ped JOIN usuario u ON u.id=ped.usuario_id WHERE ped.eliminado=FALSE AND u.eliminado=FALSE EXCEPT SELECT * FROM v_pedidos_con_usuario);
-- debe dar 0 filas. Además verifica: \d v_pedidos_con_usuario no debe mostrar contrasena

-- V3 - Detalle con producto
(SELECT * FROM v_detalle_con_producto EXCEPT SELECT dp.id, dp.pedido_id, dp.producto_id, pr.nombre, dp.cantidad, dp.precio_unitario, dp.subtotal FROM detalle_pedido dp JOIN producto pr ON pr.id=dp.producto_id WHERE dp.eliminado=FALSE AND pr.eliminado=FALSE)
UNION ALL
(SELECT dp.id, dp.pedido_id, dp.producto_id, pr.nombre, dp.cantidad, dp.precio_unitario, dp.subtotal FROM detalle_pedido dp JOIN producto pr ON pr.id=dp.producto_id WHERE dp.eliminado=FALSE AND pr.eliminado=FALSE EXCEPT SELECT * FROM v_detalle_con_producto);
-- debe dar 0 filas

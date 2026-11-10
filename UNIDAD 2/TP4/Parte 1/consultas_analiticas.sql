-- 1) Facturación por categoría y por mes
EXPLAIN ANALYZE
SELECT c.nombre AS categoria,
       date_trunc('month', ped.fecha)::date AS mes,
       SUM(dp.subtotal) AS facturado
FROM detalle_pedido dp
JOIN pedido ped ON ped.id=dp.pedido_id
JOIN producto pr ON pr.id=dp.producto_id
JOIN categoria c ON c.id=pr.categoria_id
WHERE ped.estado='TERMINADO'
  AND ped.eliminado=FALSE AND dp.eliminado=FALSE
  AND pr.eliminado=FALSE AND c.eliminado=FALSE
GROUP BY c.id, c.nombre, date_trunc('month', ped.fecha)
ORDER BY mes, facturado DESC;

-- Consulta Optimizada IA
EXPLAIN ANALYZE
WITH ventas_mensuales AS (
    -- Pre-agregamos el volumen masivo primero
    SELECT dp.producto_id,
           date_trunc('month', ped.fecha)::date AS mes,
           SUM(dp.subtotal) AS total_prod
    FROM pedido ped
    JOIN detalle_pedido dp ON ped.id = dp.pedido_id
    WHERE ped.estado = 'TERMINADO'
      AND ped.eliminado = FALSE
      AND dp.eliminado = FALSE
    GROUP BY dp.producto_id, date_trunc('month', ped.fecha)
)
-- Luego cruzamos el resultado ya achicado con las categorías
SELECT c.nombre AS categoria,
       v.mes,
       SUM(v.total_prod) AS facturado
FROM ventas_mensuales v
JOIN producto pr ON v.producto_id = pr.id
JOIN categoria c ON pr.categoria_id = c.id
WHERE pr.eliminado = FALSE 
  AND c.eliminado = FALSE
GROUP BY c.id, c.nombre, v.mes
ORDER BY v.mes, facturado DESC;

-- 2) Detalles de compra por usuario
EXPLAIN ANALYZE
SELECT u.nombre || ' ' ||
 u.apellido AS usuario,
       ped.id AS pedido_id,
       ped.fecha,
       ped.estado,
       dp.producto_id,
       dp.cantidad,
       dp.precio_unitario,
       dp.subtotal
FROM   pedido ped
JOIN   usuario u ON u.id = ped.usuario_id
JOIN   detalle_pedido dp ON dp.pedido_id = ped.id
WHERE  ped.eliminado = FALSE
  AND  u.eliminado = FALSE
  AND  dp.eliminado = FALSE
ORDER  BY ped.fecha DESC, ped.id;

-- Consulta Optimizada IA (Creacion de un indice)
CREATE INDEX idx_pedido_fecha_desc ON pedido (fecha DESC, id);


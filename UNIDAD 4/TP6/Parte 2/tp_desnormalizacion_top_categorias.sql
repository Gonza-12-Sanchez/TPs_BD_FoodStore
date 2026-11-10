-- 5.1
-- Consulta de ejemplo (top 5 categorias por monto vendido en el dia)
explain analyze 
SELECT c.nombre AS categoria, 
       SUM(dp.subtotal) AS total_vendido 
FROM detalle_pedido dp 
JOIN producto pr ON pr.id = dp.producto_id 
JOIN categoria c ON c.id = pr.categoria_id 
JOIN pedido ped ON ped.id = dp.pedido_id 
WHERE ped.fecha = '2026-09-17' --En lugar de current date utilizo una fecha que tenga registros cargados
  AND dp.eliminado = FALSE 
  AND ped.eliminado = FALSE 
GROUP BY c.nombre 
ORDER BY total_vendido DESC 
LIMIT 5; 

-- 5.2 c)
-- Implementacion del patron elegido (vista materializada)
CREATE MATERIALIZED VIEW mv_ventas_por_categoria_dia AS
SELECT c.nombre AS categoria, ped.fecha,
       SUM(dp.subtotal) AS total_vendido,
       COUNT (DISTINCT ped.id) AS cantidad_pedidos
FROM detalle_pedido dp
JOIN producto pr ON pr.id = dp.producto_id
JOIN categoria c ON c.id = pr.categoria_id
JOIN pedido ped ON ped.id = dp.pedido_id
WHERE dp.eliminado = FALSE AND ped.eliminado = FALSE
GROUP BY c.nombre, ped.fecha;

-- Índice único requerido para poder refrescar de forma concurrente
CREATE UNIQUE INDEX ux_mv_ventas_cat_dia ON mv_ventas_por_categoria_dia (categoria, fecha);

REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ventas_por_categoria_dia;

-- 5.2 d)
-- Consulta reformulada con la ayuda de la vista materializada
EXPLAIN ANALYZE
SELECT categoria, total_vendido
FROM mv_ventas_por_categoria_dia
WHERE fecha = '2026-09-17'
ORDER BY total_vendido DESC
LIMIT 5;

-- 5.2 e)
-- Mecanismo de auditoria
SELECT schemaname, matviewname, definition
FROM pg_matviews
WHERE matviewname = 'mv_ventas_por_categoria_dia';



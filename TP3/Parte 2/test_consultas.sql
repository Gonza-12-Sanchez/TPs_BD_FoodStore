-- Consulta 1
EXPLAIN ANALYZE
SELECT u.nombre, u.apellido, u.mail, SUM(p.total) as total_gastado
FROM usuario u
JOIN pedido p ON u.id = p.usuario_id
WHERE p.fecha >= (CURRENT_DATE - INTERVAL '30 days')
  AND p.estado = 'TERMINADO'
GROUP BY u.id, u.nombre, u.apellido, u.mail
ORDER BY total_gastado DESC
LIMIT 50;

-- Consulta 2 sin optimizar
EXPLAIN ANALYZE
SELECT p.nombre, p.precio, c.nombre AS categoria
FROM producto p
JOIN categoria c ON p.categoria_id = c.id
WHERE p.descripcion ILIKE '%dulce%'
  AND p.disponible = TRUE
ORDER BY p.precio ASC;

-- Consulta 2 optimizada
EXPLAIN ANALYZE
SELECT p.nombre, p.precio, c.nombre AS categoria
FROM producto p
JOIN categoria c ON p.categoria_id = c.id
WHERE to_tsvector('spanish', p.descripcion) @@ to_tsquery('spanish', 'dulce')
  AND p.disponible = TRUE
ORDER BY p.precio ASC;

-- Consulta 3
EXPLAIN ANALYZE
SELECT p.nombre, SUM(dp.cantidad) AS unidades_vendidas, SUM(dp.subtotal) AS recaudacion_total
FROM producto p
JOIN detalle_pedido dp ON p.id = dp.producto_id
GROUP BY p.id, p.nombre
ORDER BY recaudacion_total DESC
LIMIT 10;
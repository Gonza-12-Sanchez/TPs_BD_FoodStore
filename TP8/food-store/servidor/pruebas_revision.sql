-- Pruebas de revisión. Solo copia de pruebas. Todo cambio se revierte.
BEGIN;
SELECT 'H6_antes' AS prueba,count(*) AS pedidos,sum(total) AS total FROM pedido;
UPDATE pedido SET total=total+1 WHERE id=1;
SELECT 'H6_mismo_conteo' AS prueba,count(*) AS pedidos,sum(total) AS total FROM pedido;
SELECT 'H6_incoherencias' AS prueba,count(*) FROM (
 SELECT p.id FROM pedido p LEFT JOIN detalle_pedido d ON d.pedido_id=p.id AND NOT d.eliminado
 WHERE NOT p.eliminado GROUP BY p.id,p.total
 HAVING p.total<>COALESCE(sum(d.subtotal),0)
) diferencias;
ROLLBACK;

-- H7: el control anterior no advierte la ausencia de pedidos; probar el lote esperado.
WITH esperados(id) AS (VALUES (1),(2),(3),(4),(5))
SELECT 'H7_faltante' AS prueba,e.id FROM esperados e
LEFT JOIN pedido p ON p.id=e.id LEFT JOIN usuario u ON u.id=p.usuario_id
WHERE p.id IS NULL OR p.eliminado OR u.id IS NULL OR u.eliminado;

WITH muestra(descripcion) AS (VALUES ('agridulce'),('dulces'),('dulce'))
SELECT 'H2_semantica' AS prueba,descripcion,
 descripcion ILIKE '%dulce%' AS subcadena,
 to_tsvector('spanish',descripcion) @@ to_tsquery('spanish','dulce') AS lexema
FROM muestra;

SELECT 'H6_despues_ROLLBACK' AS prueba,count(*) AS pedidos,sum(total) AS total FROM pedido;

-- Complemento propuesto para validate.sql de U6. Cero filas es éxito.
SELECT 'subtotal_incoherente' AS problema,id
FROM detalle_pedido WHERE subtotal <> cantidad*precio_unitario;

SELECT 'total_incoherente' AS problema,p.id,p.total,COALESCE(sum(d.subtotal),0) AS suma
FROM pedido p LEFT JOIN detalle_pedido d ON d.pedido_id=p.id AND NOT d.eliminado
WHERE NOT p.eliminado
GROUP BY p.id,p.total HAVING p.total <> COALESCE(sum(d.subtotal),0);

-- Complemento de completitud para el lote EXACTO de cinco pedidos de U7.
-- En la semilla mínima U8 se esperan cuatro faltantes (IDs 2,3,4,5).
WITH esperados(id) AS (VALUES (1),(2),(3),(4),(5))
SELECT e.id AS pedido_no_exportable FROM esperados e
LEFT JOIN pedido p ON p.id=e.id LEFT JOIN usuario u ON u.id=p.usuario_id
WHERE p.id IS NULL OR p.eliminado OR u.id IS NULL OR u.eliminado;

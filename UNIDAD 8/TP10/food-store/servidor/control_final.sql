-- Solo lectura. Los cambios de preparación de C2, C3 y C4 son intencionales.
-- Contrasta el resultado final con la semilla y los cambios de preparación.
-- ejecutar.py compara las filas completas de producto, pedido y detalle_pedido en cada simulación.
SELECT count(*) AS pedidos, count(*)=1 AS cantidad_pedidos_esperada FROM pedido;
SELECT id,stock,
 stock=CASE id WHEN 1 THEN 50 WHEN 2 THEN 2 WHEN 3 THEN 20 WHEN 4 THEN 15 END AS stock_esperado
FROM producto ORDER BY id;
SELECT id,precio,disponible,eliminado FROM producto ORDER BY id;

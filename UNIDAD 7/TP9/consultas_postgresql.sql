-- Food Store TP7. Ejecutar con psql sobre la copia de desarrollo.
\set ON_ERROR_STOP on
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;

-- b) Pedidos pendientes del lote migrado.
SELECT p.id, p.estado
FROM public.pedido AS p
WHERE NOT p.eliminado AND p.id IN (1, 2, 3, 4, 5)
  AND p.estado = 'PENDIENTE'
ORDER BY p.id;

-- c) Pedidos con Pizza Pepperoni (producto 4), una fila por pedido.
SELECT p.id, p.estado
FROM public.pedido AS p
WHERE NOT p.eliminado AND p.id IN (1, 2, 3, 4, 5)
  AND EXISTS (
    SELECT 1
    FROM public.detalle_pedido AS d
    JOIN public.producto AS pr ON pr.id = d.producto_id AND NOT pr.eliminado
    WHERE d.pedido_id = p.id AND NOT d.eliminado AND d.producto_id = 4
  )
ORDER BY p.id;

-- Control de integridad del lote. Cero filas indica que pasó el control.
WITH control AS (
  SELECT p.id, count(d.id) AS lineas, p.total,
         coalesce(sum(d.subtotal), 0) AS suma,
         count(d.id) FILTER (
           WHERE d.cantidad <= 0 OR d.precio_unitario < 0
             OR d.subtotal <> d.cantidad * d.precio_unitario
             OR pr.id IS NULL
         ) AS lineas_invalidas
  FROM public.pedido AS p
  JOIN public.usuario AS u ON u.id = p.usuario_id AND NOT u.eliminado
  LEFT JOIN public.detalle_pedido AS d ON d.pedido_id = p.id AND NOT d.eliminado
  LEFT JOIN public.producto AS pr ON pr.id = d.producto_id AND NOT pr.eliminado
  WHERE NOT p.eliminado AND p.id IN (1, 2, 3, 4, 5)
  GROUP BY p.id
)
SELECT * FROM control
WHERE lineas = 0 OR total <> suma OR lineas_invalidas > 0;

-- Exportación reproducible de los cinco documentos, sin datos personales.
-- Para guardar solo esta salida desde psql, usar \o antes y después del SELECT.
SELECT jsonb_pretty(jsonb_agg(
  jsonb_build_object(
    '_id', p.id::text,
    'fecha', to_char(p.fecha, 'YYYY-MM-DD'),
    'estado', p.estado,
    'forma_pago', p.forma_pago,
    'total', jsonb_build_object('$numberDecimal', p.total::text),
    'cliente', jsonb_build_object('id', u.id::text),
    'lineas', (
      SELECT jsonb_agg(jsonb_build_object(
        'id', d.id::text, 'producto_id', pr.id::text, 'producto', pr.nombre,
        'cantidad', d.cantidad,
        'precio_unitario', jsonb_build_object('$numberDecimal', d.precio_unitario::text),
        'subtotal', jsonb_build_object('$numberDecimal', d.subtotal::text)
      ) ORDER BY d.id)
      FROM public.detalle_pedido AS d
      JOIN public.producto AS pr ON pr.id = d.producto_id AND NOT pr.eliminado
      WHERE d.pedido_id = p.id AND NOT d.eliminado
    )
  ) ORDER BY p.id
))
FROM public.pedido AS p
JOIN public.usuario AS u ON u.id = p.usuario_id AND NOT u.eliminado
WHERE NOT p.eliminado AND p.id IN (1, 2, 3, 4, 5);

ROLLBACK;

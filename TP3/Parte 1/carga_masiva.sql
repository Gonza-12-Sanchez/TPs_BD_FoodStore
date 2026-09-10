-- TP3 - Carga masiva simple
-- 50.000 productos parejos en categorias existentes (precio 500-5000, stock 0-200)
-- 20.000 usuarios + 200.000 pedidos con 1 detalle c/u (200.000 detalles)
-- Solo toca producto, usuario, pedido, detalle_pedido. No modifica categoria.
-- Requiere schema.sql + data.sql ya ejecutados. Usar en copia_trabajo:
--   BEGIN; \i TP3/carga_masiva.sql; -- verificar; ROLLBACK o COMMIT;

begin;
-- 1) 50.000 productos
INSERT INTO producto (nombre, precio, descripcion, stock, categoria_id)
SELECT
    'Producto ' || lpad(gs::text, 5, '0')  AS nombre,
    (500 + random() * 4500)::numeric(10,2) AS precio,
    'Producto generado ' || gs             AS descripcion,
    floor(random() * 201)::int             AS stock,
    ((gs - 1) % 4 + 1)::bigint            AS categoria_id
FROM generate_series(1, 50000) AS gs;

-- 2) 20.000 usuarios
INSERT INTO usuario (nombre, apellido, mail, celular, contrasena, rol)
SELECT
    'Nombre' || gs                                     AS nombre,
    'Apellido' || gs                                   AS apellido,
    'u' || lpad(gs::text, 6, '0') || '@foodstore.test' AS mail,
    '11' || lpad((floor(random()*90000000)+10000000)::text, 8, '0') AS celular,
    'hash_' || gs                                      AS contrasena,
    (CASE WHEN random() < 0.05 THEN 'ADMIN'::rol ELSE 'USUARIO'::rol END) AS rol
FROM generate_series(1, 20000) AS gs;

-- 3) 200.000 pedidos - usuario_id de ids reales (evita error FK 23503 por huecos de identity)
WITH user_ids AS (SELECT array_agg(id) AS ids FROM usuario)
INSERT INTO pedido (fecha, estado, total, forma_pago, usuario_id)
SELECT
    (CURRENT_DATE - (floor(random()*730))::int) AS fecha,
    (ARRAY['PENDIENTE','CONFIRMADO','TERMINADO','CANCELADO'])[1+floor(random()*4)::int]::estado_pedido,
    0,
    (ARRAY['TARJETA','TRANSFERENCIA','EFECTIVO'])[1+floor(random()*3)::int]::forma_pago,
    ids[1 + floor(random()*array_length(ids,1))::int]
FROM generate_series(1, 200000) AS gs
CROSS JOIN user_ids;


-- 4) 200.000 detalles - 1 por pedido, producto tomado de ids reales
WITH prod_ids AS (SELECT array_agg(id) AS ids FROM producto),
     nuevos AS (SELECT id AS pedido_id FROM pedido ORDER BY id DESC LIMIT 200000)
INSERT INTO detalle_pedido (cantidad, precio_unitario, subtotal, pedido_id, producto_id)
SELECT 
    gen.cantidad,
    p.precio AS precio_unitario,
    (gen.cantidad * p.precio)::numeric(12,2) AS subtotal,
    np.pedido_id,
    p.id
FROM nuevos np
CROSS JOIN prod_ids
CROSS JOIN LATERAL (
    -- Al poner np.pedido_id en el WHERE obligamos al motor a recalcular por cada fila
    SELECT 
        (1 + floor(random()*5))::int AS cantidad,
        prod_ids.ids[1 + floor(random()*array_length(prod_ids.ids,1))::int] AS rand_id
    WHERE np.pedido_id IS NOT NULL 
) gen
JOIN producto p ON p.id = gen.rand_id;

-- 5) Recalcular totales de los 200k pedidos nuevos
UPDATE pedido p SET total = s.suma
FROM (
    SELECT pedido_id, SUM(subtotal)::numeric(12,2) AS suma
    FROM detalle_pedido
    WHERE pedido_id > 5
    GROUP BY pedido_id
) s
WHERE p.id = s.pedido_id;

rollback;

-- Verificacion carga masiva correctamente
SELECT 'producto' AS tabla, count(*) FROM producto
UNION ALL SELECT 'usuario', count(*) FROM usuario
UNION ALL SELECT 'pedido', count(*) FROM pedido
UNION ALL SELECT 'detalle_pedido', count(*) FROM detalle_pedido;

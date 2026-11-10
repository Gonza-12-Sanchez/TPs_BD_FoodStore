# Informe de Mediciones — Parte A (TP5)

Base: `copia_trabajo` con 50k productos / 20k usuarios / 200k pedidos / 200k detalle_pedido

---

## Q1 — Listar pedidos (Épica 4)

**Consulta:**
```sql
SELECT ped.id, u.nombre || ' ' || u.apellido AS usuario, ped.fecha, ped.estado, ped.forma_pago, ped.total
FROM pedido ped JOIN usuario u ON u.id = ped.usuario_id
WHERE ped.eliminado = FALSE AND u.eliminado = FALSE
ORDER BY ped.id;
```

**Plan antes:**
- Nodo: Index Scan using pedido_pkey on pedido ped (con Filter: NOT eliminado) + Memoize + Index Scan usuario_pkey
- Cost: 0.42..21277.62 (pedido) | 0.72..33253.74 (total)
- Tiempo real del nodo: 0.706..1059.127 ms (pedido)
- Tiempo real global: 1466.276 ms

**Cambio aplicado:**
```sql
CREATE INDEX idx_pedido_vig_id ON pedido(id) WHERE eliminado = FALSE;
```

**Plan después:**
- Nodo: Index Scan using idx_pedido_vig_id on pedido ped
- Cost: 0.42..19085.62 (pedido) | 0.72..31061.74 (total)
- Tiempo real del nodo: 0.121..206.334 ms (pedido)
- Tiempo real global: 540.116 ms

**Mejora:** de 1466.2 ms a 540.1 ms (-63.1%). El índice parcial evita el Filter y respeta el ORDER BY.

---

## Q2 — Top 5 productos más vendidos (Analítica A)

**Consulta:**
```sql
SELECT pr.id, pr.nombre, SUM(dp.cantidad) AS unidades
FROM detalle_pedido dp JOIN producto pr ON pr.id = dp.producto_id
WHERE dp.eliminado = FALSE
GROUP BY pr.id, pr.nombre ORDER BY unidades DESC LIMIT 5;
```

**Plan antes:**
- Nodo: Seq Scan on detalle_pedido dp (Filter: NOT eliminado)
- Cost: 0.00..4268.10
- Tiempo real del nodo: 0.540..85.876 ms
- Tiempo real global: 424.952 ms

**Cambio aplicado:**
```sql
CREATE INDEX idx_detalle_producto_vig ON detalle_pedido(producto_id) WHERE eliminado = FALSE;
```

**Plan después:**
- Nodo: Seq Scan on detalle_pedido dp (Filter: NOT eliminado) — mantuvo Seq Scan, no usó el índice
- Cost: 0.00..4282.50
- Tiempo real del nodo: 0.045..52.833 ms
- Tiempo real global: 366.377 ms

**Mejora:** de 424.9 ms a 366.3 ms (-13.8% — mejora marginal, el planificador prefirió Hash Join + Seq Scan porque debe leer casi todas las filas para el GROUP BY).

**Lectura:** El índice `idx_detalle_producto_vig` no fue usado porque la consulta agrupa el 100% de los detalles vigentes; un índice no evita leer toda la tabla. Se mantiene como candidato pero se documenta que no cambia el plan.

---

## Q3 — Facturación por categoría y mes (Analítica B)

**Consulta:**
```sql
SELECT c.nombre AS categoria, date_trunc('month', ped.fecha) AS mes, SUM(dp.subtotal) AS facturado
FROM detalle_pedido dp
JOIN pedido ped ON ped.id = dp.pedido_id AND ped.eliminado = FALSE
JOIN producto pr ON pr.id = dp.producto_id
JOIN categoria c ON c.id = pr.categoria_id
WHERE dp.eliminado = FALSE
GROUP BY c.nombre, date_trunc('month', ped.fecha) ORDER BY mes, facturado DESC;
```

**Plan antes:**
- Nodo: Parallel Seq Scan on detalle_pedido dp + Parallel Seq Scan on pedido ped (ambos Filter: NOT eliminado) + Seq Scan on producto pr
- Cost: 0.00..3444.53 (detalle) | 0.00..4765.35 (pedido) | 34880..52422 (total)
- Tiempo real del nodo: 0.012..22.503 ms (detalle) | 0.018..36.847 ms (pedido)
- Tiempo real global: 556.263 ms
- Extra: Sort Method: external merge Disk: 2856kB

**Cambio aplicado:**
```sql
CREATE INDEX idx_pedido_fecha_vig ON pedido(fecha) WHERE eliminado = FALSE;
```

**Plan después:**
- Nodo: Parallel Seq Scan on detalle_pedido dp + Parallel Seq Scan on pedido ped (ambos Filter: NOT eliminado) — mantuvo Seq Scan
- Cost: 0.00..3457.12 (detalle) | 0.00..4765.35 (pedido) | 34944..52489 (total)
- Tiempo real del nodo: 0.014..21.559 ms (detalle) | 0.013..22.916 ms (pedido)
- Tiempo real global: 508.860 ms

**Mejora:** de 556.2 ms a 508.8 ms (-8.5% — mejora marginal, sigue haciendo Parallel Seq Scan porque el GROUP BY sobre date_trunc(fecha) obliga a escanear todo).

---

## Costo en escritura (500 INSERT en detalle_pedido)

**Script usado (dentro de BEGIN; ... ROLLBACK;, tiempo tomado de Statistics > Execute time en DBeaver):**
```sql
BEGIN;
INSERT INTO detalle_pedido (cantidad, precio_unitario, subtotal, pedido_id, producto_id)
SELECT 1, 100, 100, id, 1 FROM pedido ORDER BY id DESC LIMIT 500;
ROLLBACK;
```

**Antes (sin índices nuevos):** 86 ms (0,086s)
**Después (con índices nuevos):** 22 ms (0,022s)
**Diferencia:** -74% (más rápido por caché caliente; con 500 filas el SELECT previo dejó pedido en shared_buffers).

---

## Índice descartado por sobreindexación

**Propuesta descartada:**
```sql
CREATE INDEX idx_pedido_estado ON pedido(estado);
```

**Motivo:** Índice de baja cardinalidad (solo 4 estados) sin condición parcial, redundante con `idx_pedido_estado_fecha(estado, fecha)` ya existente en `schema.sql`. No cambia el plan de Q1-Q3 y solo aumenta el costo de mantenimiento en cada INSERT/UPDATE. Se descarta por sobreindexación.


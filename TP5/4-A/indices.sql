-- Q1 — Listar pedidos (Épica 4) — Frecuencia muy alta
-- Spec: WHERE ped.eliminado=FALSE ORDER BY ped.id
-- Justificación: B-tree parcial mantiene orden por id solo para vigentes, evita el Filter después del Index Scan sobre la PK
CREATE INDEX idx_pedido_vig_id ON pedido(id) WHERE eliminado = FALSE;

-- Q2 — Top 5 productos más vendidos (Analítica A) — Reporte diario
-- Spec: JOIN por producto_id con filtro eliminado
-- Justificación: B-tree parcial sobre producto_id solo para filas vigentes. Reemplaza el Seq Scan de 200k en detalle_pedido
CREATE INDEX idx_detalle_producto_vig ON detalle_pedido(producto_id) WHERE eliminado = FALSE;

-- Q3 — Facturación por categoría y mes (Analítica B) — Cierre mensual
-- Spec: GROUP BY date_trunc(fecha) con filtro eliminado
-- Justificación: B-tree parcial sobre fecha para el GROUP BY temporal, solo vigentes. Reduce el Parallel Seq Scan de pedido
CREATE INDEX idx_pedido_fecha_vig ON pedido(fecha) WHERE eliminado = FALSE;

-- Índice DESCARTADO por sobreindexación (no crear)
-- Propuesta: CREATE INDEX idx_pedido_estado ON pedido(estado);
-- Motivo: baja cardinalidad (4 estados), sin condición parcial, redundante con idx_pedido_estado_fecha(estado,fecha) ya existente en schema.sql. No cambia ningún plan de Q1-Q3.

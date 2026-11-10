-- Parte 5: Competencia de optimización

-- 1. Consulta original (Lenta)
EXPLAIN ANALYZE
SELECT p.id, p.nombre, p.precio, p.stock
FROM producto p
WHERE p.categoria_id = 2
  AND p.precio BETWEEN 1000 AND 3000
  AND p.eliminado = FALSE
ORDER BY p.precio ASC;

-- 2. Índice ganador propuesto
CREATE INDEX idx_producto_competencia 
ON producto (categoria_id, precio ASC) 
INCLUDE (nombre, stock)
WHERE eliminado = FALSE;

-- 3. Consulta optimizada (Index Only Scan)
EXPLAIN ANALYZE
SELECT p.id, p.nombre, p.precio, p.stock
FROM producto p
WHERE p.categoria_id = 2
  AND p.precio BETWEEN 1000 AND 3000
  AND p.eliminado = FALSE
ORDER BY p.precio ASC;

# spec: vista_productos_vigentes
Objetivo: simplificar el catálogo de productos con su categoría.
Columnas a exponer: p.id, p.nombre, p.precio, p.stock, p.disponible, p.categoria_id, c.nombre AS categoria
Filtro de vigencia: p.eliminado = FALSE AND c.eliminado = FALSE AND p.disponible = TRUE
Columna oculta: ninguna (no hay dato sensible).
Equivalencia: debe devolver lo mismo que SELECT con JOIN producto-categoria y ese filtro.

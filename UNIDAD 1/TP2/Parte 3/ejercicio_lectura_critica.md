# Análisis Conceptual

---

## Script 1: UPDATE sin WHERE

### Código original

```sql
UPDATE funcion
SET activa = FALSE;
```

### El problema

No tiene cláusula `WHERE`.

### Impacto

Actualiza todas las filas de la tabla `funcion` sin distinción. Da de baja tanto las funciones de películas fuera de cartel como las funciones vigentes, futuras y activas.

### Solución

Vincular la tabla `funcion` con `pelicula` (o filtrar por la columna correspondiente, ej. `pelicula_id IN (SELECT id FROM pelicula WHERE en_cartel = FALSE)` o mediante un `JOIN`) para alterar únicamente las funciones asociadas a películas no vigentes.

#### Opción 1: Subconsulta con IN

```sql
UPDATE funcion
SET activa = FALSE
WHERE pelicula_id IN (
    SELECT id
    FROM pelicula
    WHERE en_cartel = FALSE
);
```

#### Opción 2: Usando JOIN / UPDATE directo (PostgreSQL)

```sql
UPDATE funcion f
SET activa = FALSE
FROM pelicula p
WHERE f.pelicula_id = p.id
  AND p.en_cartel = FALSE;
```

---

## Script 2: DELETE con NOT IN y valores NULL

### Código original

```sql
DELETE FROM categoria
WHERE id NOT IN (SELECT categoria_id FROM producto);
```

### El problema

Si en la tabla `producto` existe al menos una fila donde `categoria_id` sea `NULL` (un producto sin categoría asignada), la subconsulta devuelve un conjunto que contiene `NULL` (por ejemplo: `(1, 2, NULL)`).

### Impacto real

La expresión `id NOT IN (1, 2, NULL)` se traduce internamente en:

```
id ≠ 1 AND id ≠ 2 AND id ≠ NULL
```

Como cualquier comparación con `NULL` resulta en `UNKNOWN`, toda la condición lógica evalúa a `UNKNOWN` o `FALSE`. En consecuencia, el motor no borra ninguna fila, fallando silenciosamente sin arrojar error.

### Solución

Usar `NOT EXISTS` o agregar `WHERE categoria_id IS NOT NULL` dentro de la subconsulta.

#### Opción 1: Usando NOT EXISTS (segura frente a valores NULL y más eficiente)

```sql
DELETE FROM categoria c
WHERE NOT EXISTS (
    SELECT 1
    FROM producto p
    WHERE p.categoria_id = c.id
);
```

#### Opción 2: NOT IN con filtro explícito de NULLs

```sql
DELETE FROM categoria
WHERE id NOT IN (
    SELECT categoria_id
    FROM producto
    WHERE categoria_id IS NOT NULL
);
```

---

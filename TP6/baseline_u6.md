# Baseline U6 — foodstore

**Capturado:** 2026-10-28 19:10:25 (-03)
**Motor:** PostgreSQL 17.10 · **Base:** `foodstore` · **Tamaño:** 251 MB
**Objetos:** 5 tablas · 18 índices · 3 vistas

Este archivo es la referencia contra la que se validan los conteos después de restaurar (Parte 4 del TP).

## Conteos de filas

| tabla | filas |
|---|---|
| `categoria` | 4 |
| `producto` | 50.010 |
| `usuario` | 20.005 |
| `pedido` | 200.005 |
| `detalle_pedido` | 200.010 |

## Cómo se construyó

1. `backups/pre_u6.dump` — respaldo previo de `copia_food_store` (paso 3 del protocolo de seguridad).
2. `CREATE DATABASE foodstore` vacía.
3. `schema.sql` **sin** la línea `create database copia_food_store`.
4. `data.sql` — semilla.
5. `TP5/4-A/indices.sql` — 3 índices parciales.
6. `TP5/4-B/views.sql` — 3 vistas.
7. `TP3/Parte 1/carga_masiva.sql` — ensayo con `ROLLBACK` (29,9 s), verificación de conteos, luego `COMMIT` (28,9 s).
8. `ANALYZE` — estadísticas al día.

`copia_food_store` no se modificó en ningún paso.

## Observaciones

- **Tuplas muertas elevadas** al momento de la captura: `pedido` 599.995, `detalle_pedido` 200.005, `producto` 50.000, `usuario` 20.000. Origen: el ensayo con `ROLLBACK` y, en `pedido`, el `UPDATE` de totales. Se dejan sin limpiar a propósito: son la materia prima de la revisión de mantenimiento (Parte 3) y autovacuum debería actuar solo.
- **Baseline y tuplas muertas no se mezclan:** los conteos de arriba son lógicos (`COUNT(*)`) y no se ven afectados por la limpieza posterior.
- El bloque de prueba al final de `TP5/4-A/indices.sql` **falla** sobre la semilla (viola `UNIQUE (pedido_id, producto_id)`), porque asume 200k pedidos. Los 3 índices se crean igual; el bloque está dentro de `BEGIN/ROLLBACK` y no deja efectos.

## Consulta para reproducir el baseline

```sql
SELECT 'categoria' AS tabla, COUNT(*) FROM categoria
UNION ALL SELECT 'producto', COUNT(*) FROM producto
UNION ALL SELECT 'usuario', COUNT(*) FROM usuario
UNION ALL SELECT 'pedido', COUNT(*) FROM pedido
UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido;
```

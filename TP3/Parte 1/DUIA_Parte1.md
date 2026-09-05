# Declaración de Uso de IA (DUIA) - Parte 1

 **Parte 1 — Poblar la base masivamente con datos generados por IA**

---

## Herramienta

OpenCode (Modo Plan y Ejecución) — Muse Spark 1.2

---

## Prompt utilizado

> Generame un script SQL para PostgreSQL que inserte 50.000 filas en producto, distribuidas de forma pareja entre las categorías existentes, con precios entre 500 y 5000 y stock aleatorio entre 0 y 200, 20.000 usuarios y 200.000 pedidos con sus detalles. Usá generate_series y no uses PL/pgSQL si no es necesario. No modifiques ninguna otra tabla.

Prompt exacto enviado a OpenCode incluyó además: respetar `schema.sql` (CHECK, UNIQUE, FK, ENUM), no tocar `categoria`, y generar `TP3/carga_masiva.sql` set-based.

---

## Qué generó la IA

**Iteración 1 (descartada):** `TP3/carga_masiva.sql` de 224 líneas — 1 INSERT de 50.000 productos, 1 INSERT de 20.000 usuarios, 1 INSERT de 200.000 pedidos y 3 INSERTs de `detalle_pedido` (1 obligatorio + 60% 2do + 20% 3ro, ~360k detalles, `ON CONFLICT DO NOTHING`), `precio 50-2050`, `stock 0-500`, `BEGIN`/`COMMIT` incluidos dentro del script y `ANALYZE` al final.

**Iteración 2 (actual):** `TP3/carga_masiva.sql` de 61 líneas — versión simple solicitada: 50.000 productos (`(500+random()*4500)::numeric(10,2)`, `stock 0-200`, `categoria ((gs-1)%4+1)`), 20.000 usuarios, 200.000 pedidos, **200.000 detalles (1 por pedido)** para garantizar `pedido con detalle`, `UPDATE pedido SET total = SUM(subtotal)` y sin PL/pgSQL. Usa `array_agg(id)` para elegir `usuario_id`/`producto_id` reales y evitar `SQL Error 23503 FK`.

Archivo final: `TPs_BD_FoodStore/TP3/carga_masiva.sql:1`

---

## Qué se aceptó

- Estructura set-based con `generate_series` sin loops PL/pgSQL.
- Distribución pareja de productos: `((gs - 1) % 4 + 1)::bigint` sobre las 4 categorías existentes.
- Rangos de la consigna: `precio 500-5000` y `stock 0-200`.
- Patrón robusto a huecos de `GENERATED ALWAYS AS IDENTITY`.
- Lógica de `detalle_pedido`: 1 detalle por pedido.

---

## Qué se modificó/descartó

- **Descartada iteración 1 completa.** Motivos:
  1. No cumplía rangos de la Parte 1 (precio 50-2050 / stock 0-500).
  2. Complejidad innecesaria (3 bloques de detalle, `ON CONFLICT DO NOTHING` ocultaba duplicados y dejaba `detalle_pedido` en 159.842 en vez de 200.000 — verificado con `SELECT count(*)` en `BEGIN; ... ROLLBACK;`).
- **Se eliminó** el archivo complejo y se reescribió como versión simple de 61 líneas.

---

## Verificación realizada

Lectura línea por línea antes de ejecutar y ejecución bajo protocolo de la cátedra (`protocolo_seguridad.md`):

1. **No tocar producción:** Se trabajo sobre una copia de la base de datos food_store.
2. **Ejecución en transacción sobre copia:** `BEGIN; TP3/carga_masiva.sql + verificaciones → `ROLLBACK` de prueba, luego `BEGIN; \i TP3/carga_masiva.sql; COMMIT;`. 
3. **ANALYZE:** `ANALYZE producto; ANALYZE usuario; ANALYZE pedido; ANALYZE detalle_pedido;` ejecutado tras el `COMMIT` para que el optimizador actualice estadísticas antes de medir, como exige el punto 4 de la Parte 1.

---

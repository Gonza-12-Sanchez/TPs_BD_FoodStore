# Revisión de scripts con IA

Fecha: 6/11/2026. Herramienta: OpenCode, agente **Plan**. La salida original está en `evidencias/opencode_revision.md`; el registro de eventos, en `opencode_plan.jsonl`. El adjunto `scripts_para_revision.txt` contiene los scripts disponibles del esquema base, U3, U4, U5, U6, U7 y U8. Se excluyó `data.sql`, porque no es necesario enviar registros de usuarios para revisar código. No se atribuye la revisión a unidades cuyos scripts no estaban disponibles.

OpenCode realizó análisis estático y propuso pruebas; **las ejecuciones posteriores fueron hechas por ChatGPT/Codex con herramientas locales**, no por OpenCode. Los archivos originales de TP3–TP7 no se modificaron. Se aportan complementos en `servidor/revision_integridad.sql`.

| Hallazgo de OpenCode | Unidad | Decisión y fundamento | Comprobación |
|---|---|---|---|
| H1: índice de competencia no incluye `id` | U3 | Aceptado: no se puede afirmar cobertura de todas las columnas. No se promete una mejora sin medir. | Inspección del índice; benchmarking pendiente, fuera de esta entrega. |
| H2: `ILIKE '%dulce%'` y búsqueda por lexemas no son equivalentes | U3 | Aceptado: definir primero la semántica de búsqueda. | Consulta real: `agridulce` da true por subcadena y false por lexema; `dulces` y `dulce` dan true en ambos. |
| H3: carga masiva usa categorías 1–4, últimos pedidos y umbral `id>5` | U3 | Aceptado: restringir a semilla controlada; para generalizar, capturar IDs con RETURNING. No se reescribió la carga masiva anterior. | Inspección estática; no se ejecutaron 200.000 inserciones. |
| H4: reportes usan distintos filtros de estado/baja | U3/U4 | Aceptado: acordar qué significa venta y facturación antes de unificar reportes. | Comparación de los scripts; no se impone una regla contable nueva. |
| H5: índices parciales no garantizan los planes anunciados | U5 | Aceptado: las mejoras deben presentarse como hipótesis hasta medir EXPLAIN ANALYZE. | Revisión estática; medición de carga representativa pendiente. |
| H6: conteos de respaldo no detectan importes incoherentes | U6 | Corregido en complemento: verificar subtotal y suma por pedido. La quietud de escrituras sigue siendo requisito operativo. | Un pedido pasa de total 150 a 151 sin cambiar el conteo 1. El nuevo control detecta 1 incoherencia. ROLLBACK devuelve 150. |
| H7: control de lote omite pedidos inexistentes | U7 | Corregido en complemento: partir de la lista esperada y usar LEFT JOIN. | En la semilla mínima U8, con solo el ID 1, detecta faltantes 2,3,4,5. Es una prueba de ausencia deliberada, no un fallo demostrado del lote original U7. |
| H8: cola permite reabrir o borrar resueltas | U8 | Corregido: se adoptaron los triggers generados por OpenCode. | Reabrir una resuelta falla con `Una solicitud resuelta no se puede modificar`; repetir semáforo conserva filas y motivos. |
| Propuesta tentadora: desactivar FK y borrar toda la caché | U8 | **Descartado**: rompe referencias y pierde el contexto offline. Se mantiene UPSERT con lápidas. | `DELETE FROM producto_cache WHERE id=1` falla por FK con un ítem existente; no se agrega ni elimina ninguna fila. |

## Reproducir las comprobaciones

`ejecutar.py` prueba H8 y el rechazo de borrar una fila referenciada. En una instancia de laboratorio que permanezca activa:

```powershell
psql -X -v ON_ERROR_STOP=1 -d foodstore_tp8_<sufijo> -f servidor/pruebas_revision.sql
```

Agregar host, puerto y usuario según esa instancia. La evidencia ya obtenida está en `evidencias/revision_postgresql.txt`. La prueba de H6 se ejecuta dentro de BEGIN/ROLLBACK. H7 y H2 son solo lectura. No se incluye una restauración completa nueva de U6: se amplía su plan y sus controles, y se mantienen las limitaciones declaradas.

## Límites aceptados

La cola conserva estado y motivo, pero no una copia histórica de todos los ítems anteriores a aceptar un precio. Es suficiente para esta simulación; una auditoría comercial exigiría versionar los ítems o guardar el cuerpo de cada solicitud. La idempotencia local no evita duplicados de ventas entre dispositivos: en producción se implementa en el endpoint del servidor con clave única y transacción atómica.

## Revisión complementaria con OpenCode Plan del 9/11/2026

El segundo pase cubrió los seis SQL de `servidor/`, `ejecutar.py`, `laboratorio.py`, `probar.ps1` y una copia anonimizada del `data.sql` histórico. Los SQL móviles y los scripts de TP3 a TP7 ya figuraban en el primer pase. La salida del agente, su adjunto y sus eventos están en `evidencias/`. OpenCode hizo una revisión estática. Las comprobaciones descritas abajo se ejecutaron en bases aisladas.

| Hallazgo | Decisión y comprobación |
|---|---|
| Correlación incorrecta en el `UPDATE` histórico de `data.sql` | Confirmado en PostgreSQL. Los cinco pedidos recibieron 300. Con alias explícitos se obtuvieron 460, 1700, 400, 1090 y 550, iguales a la suma de los detalles. Se revirtió la prueba con `ROLLBACK`. El TP8 usa su propia semilla. |
| Comparación parcial del servidor en `ejecutar.py` y alcance de `control_final.sql` | Corregido. Cada simulación compara todas las columnas de las filas de `producto`, `pedido` y `detalle_pedido`, con orden por ID. El SQL final contrasta la cantidad de pedidos y el stock esperado del escenario. |
| Comprobaciones que desaparecían con Python optimizado | Corregido. Se reemplazaron los `assert` por comprobaciones explícitas. Se ejecutó el laboratorio con `PYTHONOPTIMIZE=1`; pasaron C1–C7 y los controles adicionales de SQLite. |
| Limpieza del clúster de pruebas y entrada del puerto | Corregido. El lanzador valida el puerto, limita la espera de arranque y cierre, y consulta el estado de su clúster en el bloque de limpieza si llegó a intentar arrancarlo. El clúster de la revalidación se detuvo al finalizar. |
| IDs fijos, controles complementarios y vista del catálogo | Se mantienen las precondiciones del laboratorio con esquema nuevo. La prueba H7 tiene cuatro faltantes esperados en U8 y se interpreta por separado del lote completo de U7. La fecha pertenece a la consulta de exportación y el CSV conserva la instantánea. |
| Restricciones adicionales en el esquema compartido | Se conserva el esquema del curso y se comprueba la coherencia entre pedidos y detalles con los controles complementarios. La transacción de prueba de totales valida el hallazgo sin modificar el esquema compartido. |

Corrección del cálculo histórico, comprobada dentro de una transacción de prueba.

```sql
BEGIN;
UPDATE public.pedido AS p SET total = (SELECT sum(d.subtotal) FROM public.detalle_pedido AS d WHERE d.pedido_id = p.id) WHERE p.id IN (1, 2, 3, 4, 5);
ROLLBACK;
```

Evidencia de los totales en `evidencias/prueba_totales_data_sql.txt`. Resultado de C1–C7 con la versión actual en `../ejecuciones/revalidacion/resultados.txt`.

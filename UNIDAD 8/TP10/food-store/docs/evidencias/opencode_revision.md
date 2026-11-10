## Alcance de la revisión

Revisé estáticamente **todos los scripts incluidos en el adjunto** y los documentos `requirements.md`, `design.md` y `tasks.md`. **No ejecuté comandos ni pruebas, no modifiqué archivos ni consulté contenido externo.** Las pruebas que siguen son propuestas: no representan resultados obtenidos.

La separación principal del diseño es correcta: PostgreSQL conserva la autoridad sobre catálogo, precios, stock y ventas; SQLite permite trabajar offline y emitir un **resultado de simulación**. `SIMULADO_APROBADO` nunca debe interpretarse como una venta confirmada.

## 1. Hallazgos concretos

Las rutas siguientes son las que figuran en el adjunto.

### H1. El índice propuesto no cubre todas las columnas de la consulta

**Archivo:** `TP6/tmp/foodstore_repo/TP3/Parte 5/competencia.sql`  
**Gravedad:** media — afecta la justificación de la optimización.

La consulta devuelve `p.id`, pero el índice contiene como claves `categoria_id, precio` y como columnas incluidas `nombre, stock`. **Falta `id` para cubrir la consulta completa.** El comentario que anuncia un `Index Only Scan` no queda respaldado por esa definición.

**Prueba SQL propuesta:**

```sql
SELECT pg_get_indexdef('idx_producto_competencia'::regclass);

EXPLAIN (ANALYZE, BUFFERS)
SELECT id, nombre, precio, stock
FROM producto
WHERE categoria_id = 2
  AND precio BETWEEN 1000 AND 3000
  AND eliminado = FALSE
ORDER BY precio;
```

**Revisión sugerida:** evaluar `INCLUDE (id, nombre, stock)`. Aun con un índice cubriente, el plan elegido depende de costos y estadísticas; además, un recorrido solo de índice puede necesitar accesos al heap para verificar visibilidad.

---

### H2. La búsqueda de texto completo cambia la semántica del filtro original

**Archivos:**

- `TP6/tmp/foodstore_repo/schema.sql`
- `TP6/tmp/foodstore_repo/TP3/Parte 2/test_consultas.sql`

**Gravedad:** media — posible diferencia funcional presentada como optimización equivalente.

`ILIKE '%dulce%'` busca una subcadena. La expresión con `to_tsvector` y `to_tsquery` busca lexemas normalizados por el diccionario español. Puede aprovechar el índice GIN existente, pero **no garantiza los mismos resultados**.

**Prueba SQL propuesta:**

```sql
WITH muestra(descripcion) AS (
    VALUES ('agridulce'), ('dulces'), ('dulce')
)
SELECT descripcion,
       descripcion ILIKE '%dulce%' AS por_subcadena,
       to_tsvector('spanish', descripcion)
         @@ to_tsquery('spanish', 'dulce') AS por_lexema
FROM muestra;
```

**Revisión sugerida:** definir primero si el requisito pide subcadenas o búsqueda lingüística. Después comparar rendimiento entre implementaciones que respeten esa decisión.

---

### H3. La carga masiva presupone categorías y selecciona pedidos por posición

**Archivo:** `TP6/tmp/foodstore_repo/TP3/Parte 1/carga_masiva.sql`  
**Gravedad:** alta para reproducibilidad e integridad del procedimiento de carga.

Hay tres supuestos independientes:

1. La asignación de categorías presupone que existen los IDs `1, 2, 3, 4`.
2. Los detalles se asignan a los últimos 200.000 pedidos, en lugar de conservar los IDs devueltos por el `INSERT`. Con otra sesión insertando pedidos, ese conjunto puede incluir filas ajenas.
3. El recálculo de totales usa `pedido_id > 5`: puede modificar pedidos históricos que no pertenecen a esta ejecución.

Además, repetir la carga encuentra los mismos correos generados y puede fallar por `UNIQUE(mail)`.

**Pruebas SQL propuestas:**

```sql
SELECT requerido.id AS categoria_faltante
FROM generate_series(1, 4) AS requerido(id)
LEFT JOIN categoria c ON c.id = requerido.id
WHERE c.id IS NULL;

SELECT count(*) AS correos_que_colisionarian
FROM usuario
WHERE mail ~ '^u[0-9]{6}@foodstore[.]test$';

SELECT count(*) AS pedidos_alcanzados_por_el_umbral
FROM pedido
WHERE id > 5;
```

La última consulta muestra el alcance del filtro; **no permite identificar qué ejecución creó cada pedido**, porque el script no registra esa pertenencia.

**Revisión sugerida:** capturar IDs con `RETURNING` y utilizarlos para detalles y recálculo; seleccionar categorías realmente existentes y definir expresamente cómo manejar repeticiones.

---

### H4. Varias consultas analíticas cuentan conjuntos distintos de ventas

**Archivos:**

- `TP6/tmp/foodstore_repo/queries.sql`
- `TP6/tmp/foodstore_repo/TP3/Parte 2/test_consultas.sql`
- `TP6/tmp/foodstore_repo/TP4/Parte 1/consultas_analiticas.sql`

**Gravedad:** alta si esos resultados se presentan como facturación o ventas realizadas.

En `queries.sql`, el ranking de productos suma detalles vigentes sin verificar el estado ni la baja lógica del pedido. La facturación filtra pedidos vigentes, pero incluye estados como `PENDIENTE` y `CANCELADO`.

En TP3, la consulta de recaudación tampoco filtra estados ni bajas lógicas. En cambio, TP4 exige `TERMINADO` y vigencia de pedido, detalle, producto y categoría.

**Prueba SQL propuesta:**

```sql
SELECT ped.estado,
       ped.eliminado AS pedido_eliminado,
       SUM(dp.cantidad) AS unidades,
       SUM(dp.subtotal) AS importe
FROM detalle_pedido dp
JOIN pedido ped ON ped.id = dp.pedido_id
WHERE dp.eliminado = FALSE
GROUP BY ped.estado, ped.eliminado
ORDER BY ped.estado, ped.eliminado;
```

**Revisión sugerida:** acordar una definición común para cada reporte. También definir si la baja posterior de un producto o categoría debe excluir ventas históricas: ese filtro cambia la interpretación contable.

---

### H5. Los índices parciales de TP5 no garantizan las mejoras anunciadas

**Archivo:** `TP6/tmp/foodstore_repo/TP5/4-A/indices.sql`  
**Gravedad:** media — conclusiones de rendimiento sin evidencia suficiente y posible falla de la prueba de escritura.

Un índice por `producto_id` no garantiza reemplazar un recorrido secuencial cuando se agregan casi todos los detalles vigentes. Tampoco un índice por `fecha` resuelve automáticamente la agrupación por `date_trunc('month', fecha)`.

Además, la inserción de prueba agrega el producto `1` a los últimos 500 pedidos. Si alguno ya tiene ese producto, viola `UNIQUE(pedido_id, producto_id)`. El `ROLLBACK` final evita persistencia, pero no evita que falle la sentencia.

**Pruebas SQL propuestas:**

```sql
WITH ultimos AS (
    SELECT id
    FROM pedido
    ORDER BY id DESC
    LIMIT 500
)
SELECT d.pedido_id
FROM detalle_pedido d
JOIN ultimos u ON u.id = d.pedido_id
WHERE d.producto_id = 1;

EXPLAIN (ANALYZE, BUFFERS)
SELECT producto_id, SUM(cantidad)
FROM detalle_pedido
WHERE eliminado = FALSE
GROUP BY producto_id;
```

**Revisión sugerida:** documentar las mejoras como hipótesis hasta medirlas y preparar la prueba de escritura con pares pedido/producto que no existan.

---

### H6. La validación del respaldo no verifica coherencia de importes ni totales

**Archivos:**

- `TP6/output/scripts/validate.sql`
- `TP6/output/scripts/backup_foodstore.ps1`
- `TP6/output/scripts/restore_test.ps1`

**Gravedad:** alta si un resultado `OK` se interpreta como validación funcional completa.

Comparar conteos y verificar algunos valores negativos aporta evidencia útil, pero no detecta:

- `subtotal <> cantidad * precio_unitario`;
- diferencias entre el total del pedido y sus detalles vigentes;
- otras alteraciones que mantengan los mismos conteos.

El propio respaldo exige ausencia de escrituras entre el baseline y el dump, pero esa condición **no está impuesta por el script**. Con escrituras concurrentes puede aparecer una diferencia aunque el dump sea internamente consistente.

**Pruebas SQL propuestas:**

```sql
SELECT id, pedido_id
FROM detalle_pedido
WHERE subtotal <> cantidad * precio_unitario;

SELECT p.id, p.total,
       COALESCE(SUM(d.subtotal), 0) AS suma_detalles
FROM pedido p
LEFT JOIN detalle_pedido d
       ON d.pedido_id = p.id AND NOT d.eliminado
WHERE NOT p.eliminado
GROUP BY p.id, p.total
HAVING p.total <> COALESCE(SUM(d.subtotal), 0);
```

**Revisión sugerida:** sumar controles funcionales y dejar verificable la condición de quietud o usar un mecanismo que alinee las instantáneas del baseline y del respaldo.

---

### H7. El control de integridad de TP7 puede omitir pedidos faltantes

**Archivo:** `tp7/consultas_postgresql.sql`  
**Gravedad:** alta para la completitud del lote migrado.

El control parte de pedidos existentes y hace `JOIN` con usuarios vigentes. Si falta un pedido del lote, está eliminado o su usuario está eliminado, ese pedido desaparece antes del control.

Por lo tanto, **cero filas de errores no demuestra que estén presentes los cinco pedidos esperados**.

**Prueba SQL propuesta:**

```sql
WITH esperados(id) AS (
    VALUES (1), (2), (3), (4), (5)
)
SELECT e.id AS pedido_no_exportable
FROM esperados e
LEFT JOIN pedido p ON p.id = e.id
LEFT JOIN usuario u ON u.id = p.usuario_id
WHERE p.id IS NULL
   OR p.eliminado
   OR u.id IS NULL
   OR u.eliminado;
```

**Revisión sugerida:** verificar primero completitud del lote y luego coherencia de sus líneas e importes.

Las aserciones de IDs en `consultas_mongodb.js` ayudan a detectar diferencias del lote cargado, pero no sustituyen ese control del origen.

---

### H8. La cola SQLite permite alterar solicitudes que deberían conservarse

**Archivos:**

- `tp8/food-store/movil/schema_sqlite.sql`
- `tp8/food-store/movil/semaforo.sql`
- `tp8/food-store/docs/kiro/requirements.md`

**Gravedad:** alta — afecta REQ-03 y REQ-04.

El semáforo respeta correctamente `WHERE estado='PENDIENTE'`, pero el esquema permite:

- insertar directamente una solicitud como `SIMULADO_APROBADO`;
- volver una solicitud resuelta a `PENDIENTE`;
- modificar su motivo o borrarla.

Así, el comportamiento correcto depende exclusivamente del consumidor del esquema.

**Prueba SQL propuesta para el esquema original:**

Sobre una solicitud ya resuelta en una base de prueba:

```sql
SAVEPOINT probar_reapertura;

UPDATE cola_sync
SET estado = 'PENDIENTE', motivo = ''
WHERE solicitud_uuid = '10000000-0000-4000-8000-000000000001'
  AND estado <> 'PENDIENTE';

SELECT changes() AS solicitudes_reabiertas;

ROLLBACK TO probar_reapertura;
RELEASE probar_reapertura;
```

**Revisión sugerida:** exigir ingreso como pendiente e impedir la modificación o eliminación de solicitudes resueltas. La versión revisada de abajo incorpora estas restricciones.

### Cobertura del resto de los scripts

También revisé los siguientes puntos del adjunto:

| Archivo | Evaluación estática |
|---|---|
| `schema.sql` | Las FK y restricciones básicas están presentes. `CREATE DATABASE` no cambia la conexión actual: el resto debe ejecutarse conectado explícitamente a la base destino. No hay restricciones que relacionen subtotal y cantidad/precio. |
| `queries.sql` — CRUD | La creación de producto comprueba categoría vigente. La baja de pedido y detalles está agrupada en una transacción. El ejemplo manual de creación deja total `0` y debe completarse antes de usarse como operación válida. |
| `TP4/Parte 1/consultas_analiticas.sql` | La preagregación conserva los filtros principales del reporte original; su ventaja de rendimiento requiere medición. El índice por fecha tampoco garantiza eliminar todo ordenamiento posterior a los joins. |
| `TP5/4-B/views.sql` | Las vistas aplican los filtros declarados y las comparaciones bidireccionales con `EXCEPT` sirven para comprobar equivalencia de conjuntos. Ocultar columnas en una vista necesita permisos efectivos que no den acceso alternativo a las tablas base. |
| `health_check.sql` | Aporta indicadores operativos; no constituye por sí solo una prueba de salud funcional. |
| `maintenance.sql` | Mantiene `VACUUM` fuera de un bloque transaccional. Usa `\gexec`, por lo que requiere ejecución mediante `psql`. Los umbrales están identificados como locales al laboratorio. |
| `restore_test.ps1` | Comprueba códigos de salida y crea una base nueva. No restaura propietarios ni privilegios, por lo que su resultado no demuestra recuperación de permisos. |
| `consultas_mongodb.js` | Compara documentos existentes antes de insertar faltantes y verifica IDs esperados. Sin una transacción, una interrupción puede dejar una carga parcial recuperable mediante una repetición compatible. |
| `mongoose_demo.js` | Valida el documento leído, pero no impone sus reglas a otras escrituras de MongoDB. No comprueba igualdad subtotal/cantidad/precio ni total/suma de líneas. |
| `cargar_cache.sql` | Conserva filas referenciadas y transforma ausencias en lápidas. Es correcto únicamente con una instantánea completa y reemplazo/carga dentro de la misma transacción, como indica su encabezado. |
| `pruebas_sqlite.sql` | Incluye COMMIT, ROLLBACK y rechazos CHECK/FK pertinentes. Los casos C2–C6 no están implementados en este archivo; el ejecutor mencionado no forma parte del adjunto. |
| `semaforo.sql` original | Prioriza rechazo sobre conflicto, rechaza borradores vacíos y solo procesa pendientes. No reserva ni descuenta stock, lo cual es coherente con la simulación. |

Los casilleros de `tasks.md` siguen siendo tareas pendientes de evidencia. Esta revisión no acredita una sesión en Kiro, una ejecución de pruebas ni mediciones de PostgreSQL.

## 2. Recomendación tentadora que debe descartarse

### «Desactivá las FK y reemplazá toda la caché con DELETE + INSERT»

Es tentador porque simplifica la importación de cada CSV, pero **debe descartarse**:

- los ítems de borradores referencian `producto_cache`;
- borrar productos puede romper referencias o perder el contexto de pedidos offline;
- una ausencia del catálogo debe transformarse en una lápida, conservando la fila;
- desactivar FK oculta errores de integridad que REQ-01 y C7 buscan controlar.

La estrategia adecuada es la del diseño: reemplazar la tabla auxiliar `snapshot_servidor`, actualizar la caché mediante UPSERT y marcar ausentes como no disponibles/eliminados, todo dentro de una transacción.

## 3. Versiones revisadas completas

Son propuestas para una **base SQLite nueva**, no una migración de una base existente. Mantienen las cinco tablas y el orden de columnas utilizados por `cargar_cache.sql` y `pruebas_sqlite.sql`.

Los cambios principales son validaciones de identificadores y textos vacíos, ingreso obligatorio de solicitudes como pendientes y conservación de solicitudes resueltas. El semáforo registra causas más precisas y usa la fecha de la instantánea completa también cuando un producto está ausente.

### `movil/schema_sqlite.sql`

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE producto_cache (
    id INTEGER PRIMARY KEY CHECK (id > 0),
    nombre TEXT NOT NULL CHECK (length(trim(nombre)) > 0),
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock_visto INTEGER NOT NULL CHECK (stock_visto >= 0),
    disponible INTEGER NOT NULL CHECK (disponible IN (0, 1)),
    eliminado INTEGER NOT NULL CHECK (eliminado IN (0, 1)),
    fecha_copia TEXT NOT NULL CHECK (length(trim(fecha_copia)) > 0)
) STRICT;

CREATE TABLE pedido_borrador (
    id_local TEXT PRIMARY KEY CHECK (
        length(id_local) = 36
        AND substr(id_local, 9, 1) = '-'
        AND substr(id_local, 14, 1) = '-'
        AND substr(id_local, 19, 1) = '-'
        AND substr(id_local, 24, 1) = '-'
        AND length(replace(id_local, '-', '')) = 32
        AND replace(id_local, '-', '') NOT GLOB '*[^0-9a-f]*'
    ),
    usuario TEXT NOT NULL CHECK (length(trim(usuario)) > 0),
    forma_pago TEXT NOT NULL CHECK (
        forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')
    ),
    fecha TEXT NOT NULL CHECK (length(trim(fecha)) > 0)
) STRICT;

CREATE TABLE item_borrador (
    id_local TEXT NOT NULL REFERENCES pedido_borrador(id_local),
    producto_id INTEGER NOT NULL REFERENCES producto_cache(id),
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_centavos_visto INTEGER NOT NULL CHECK (
        precio_centavos_visto >= 0
    ),
    PRIMARY KEY (id_local, producto_id)
) STRICT;

CREATE TABLE cola_sync (
    solicitud_uuid TEXT PRIMARY KEY CHECK (
        length(solicitud_uuid) = 36
        AND substr(solicitud_uuid, 9, 1) = '-'
        AND substr(solicitud_uuid, 14, 1) = '-'
        AND substr(solicitud_uuid, 19, 1) = '-'
        AND substr(solicitud_uuid, 24, 1) = '-'
        AND length(replace(solicitud_uuid, '-', '')) = 32
        AND replace(solicitud_uuid, '-', '') NOT GLOB '*[^0-9a-f]*'
    ),
    id_local TEXT NOT NULL REFERENCES pedido_borrador(id_local),
    estado TEXT NOT NULL DEFAULT 'PENDIENTE' CHECK (
        estado IN (
            'PENDIENTE',
            'CONFLICTO',
            'RECHAZADO',
            'SIMULADO_APROBADO'
        )
    ),
    motivo TEXT NOT NULL DEFAULT '',
    CHECK (
        (estado = 'PENDIENTE' AND motivo = '')
        OR
        (estado <> 'PENDIENTE' AND length(trim(motivo)) > 0)
    )
) STRICT;

CREATE UNIQUE INDEX uq_pendiente_borrador
ON cola_sync(id_local)
WHERE estado = 'PENDIENTE';

CREATE INDEX idx_items_producto
ON item_borrador(producto_id);

CREATE TABLE snapshot_servidor (
    id INTEGER PRIMARY KEY CHECK (id > 0),
    nombre TEXT NOT NULL CHECK (length(trim(nombre)) > 0),
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock INTEGER NOT NULL CHECK (stock >= 0),
    disponible TEXT NOT NULL CHECK (disponible IN ('t', 'f')),
    eliminado TEXT NOT NULL CHECK (eliminado IN ('t', 'f')),
    fecha_copia TEXT NOT NULL CHECK (length(trim(fecha_copia)) > 0)
) STRICT;

CREATE TRIGGER trg_cola_ingreso_pendiente
BEFORE INSERT ON cola_sync
WHEN NEW.estado <> 'PENDIENTE' OR NEW.motivo <> ''
BEGIN
    SELECT RAISE(
        ABORT,
        'Una solicitud nueva debe ingresar como PENDIENTE y sin motivo'
    );
END;

CREATE TRIGGER trg_cola_identidad_inmutable
BEFORE UPDATE ON cola_sync
WHEN NEW.solicitud_uuid <> OLD.solicitud_uuid
  OR NEW.id_local <> OLD.id_local
BEGIN
    SELECT RAISE(
        ABORT,
        'La identidad de una solicitud no se puede modificar'
    );
END;

CREATE TRIGGER trg_cola_resuelta_inmutable
BEFORE UPDATE ON cola_sync
WHEN OLD.estado <> 'PENDIENTE'
BEGIN
    SELECT RAISE(
        ABORT,
        'Una solicitud resuelta no se puede modificar'
    );
END;

CREATE TRIGGER trg_cola_resuelta_conservar
BEFORE DELETE ON cola_sync
WHEN OLD.estado <> 'PENDIENTE'
BEGIN
    SELECT RAISE(
        ABORT,
        'Una solicitud resuelta se debe conservar'
    );
END;
```

### `movil/semaforo.sql`

```sql
PRAGMA foreign_keys = ON;

BEGIN IMMEDIATE;

WITH instantanea AS (
    SELECT MAX(fecha_copia) AS fecha_copia
    FROM snapshot_servidor
),
problemas AS (
    SELECT
        q.solicitud_uuid,
        COUNT(i.producto_id) AS lineas,
        SUM(
            CASE
                WHEN i.producto_id IS NOT NULL
                     AND s.id IS NULL
                THEN 1
                ELSE 0
            END
        ) AS ausentes,
        SUM(
            CASE
                WHEN s.id IS NOT NULL
                     AND (
                         s.disponible <> 't'
                         OR s.eliminado <> 'f'
                     )
                THEN 1
                ELSE 0
            END
        ) AS no_habilitados,
        SUM(
            CASE
                WHEN s.id IS NOT NULL
                     AND i.cantidad > s.stock
                THEN 1
                ELSE 0
            END
        ) AS sin_stock,
        SUM(
            CASE
                WHEN s.id IS NOT NULL
                     AND i.precio_centavos_visto <> s.precio_centavos
                THEN 1
                ELSE 0
            END
        ) AS precios_distintos
    FROM cola_sync q
    LEFT JOIN item_borrador i
        ON i.id_local = q.id_local
    LEFT JOIN snapshot_servidor s
        ON s.id = i.producto_id
    WHERE q.estado = 'PENDIENTE'
    GROUP BY q.solicitud_uuid
),
decisiones AS (
    SELECT
        p.solicitud_uuid,
        CASE
            WHEN p.lineas = 0
                 OR p.ausentes > 0
                 OR p.no_habilitados > 0
                 OR p.sin_stock > 0
            THEN 'RECHAZADO'
            WHEN p.precios_distintos > 0
            THEN 'CONFLICTO'
            ELSE 'SIMULADO_APROBADO'
        END AS estado,
        (
            CASE
                WHEN p.lineas = 0
                THEN 'Borrador sin items'
                WHEN p.ausentes > 0
                     OR p.no_habilitados > 0
                     OR p.sin_stock > 0
                THEN
                    'Rechazo: ausentes=' || p.ausentes
                    || '; no disponibles o eliminados=' || p.no_habilitados
                    || '; stock insuficiente=' || p.sin_stock
                WHEN p.precios_distintos > 0
                THEN
                    'Cambio de precio; requiere aceptacion explicita'
                    || '; items=' || p.precios_distintos
                ELSE
                    'Coincide con la instantanea'
            END
        )
        || '; copia=' || COALESCE(
            t.fecha_copia,
            'sin filas en la instantanea'
        )
        || '; simulacion local: NO confirma venta ni reserva stock'
        AS motivo
    FROM problemas p
    CROSS JOIN instantanea t
)
UPDATE cola_sync
SET
    estado = (
        SELECT d.estado
        FROM decisiones d
        WHERE d.solicitud_uuid = cola_sync.solicitud_uuid
    ),
    motivo = (
        SELECT d.motivo
        FROM decisiones d
        WHERE d.solicitud_uuid = cola_sync.solicitud_uuid
    )
WHERE estado = 'PENDIENTE';

COMMIT;
```

### Condiciones de uso y verificación pendientes

- **Instantánea:** debe provenir de una exportación completa y consistente, con fecha común. Estos dos archivos no verifican por sí solos que el CSV cumpla esa condición. Una instantánea vacía tampoco conserva una fecha de exportación en el modelo actual.
- **Aceptación de precio:** ante `CONFLICTO`, una acción explícita del cliente debe actualizar los precios aceptados y crear otra solicitud con UUID nuevo, dentro de una transacción. El semáforo no acepta precios automáticamente.
- **Historial:** se conserva la solicitud resuelta y su motivo, como pide el diseño. No se incorpora una copia histórica de cada ítem evaluado; si se modifica el borrador, el esquema no conserva sus valores anteriores.
- **Integridad por conexión:** `PRAGMA foreign_keys = ON` debe activarse en cada conexión SQLite, antes de abrir transacciones.
- **Pruebas:** quedan por ejecutar C1–C7, incluyendo rechazo de reapertura de solicitudes, repetición del semáforo sin cambios en resueltas y comparación de pedidos/stock de PostgreSQL antes y después.

**Conclusión:** la propuesta refuerza la integridad de la cola y mantiene la prioridad rojo → amarillo → verde. El resultado verde sigue siendo exclusivamente local y simulado: **la tablet nunca confirma ventas ni reserva stock**.
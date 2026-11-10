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

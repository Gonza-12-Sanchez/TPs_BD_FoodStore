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

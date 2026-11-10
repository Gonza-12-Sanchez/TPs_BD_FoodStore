-- =============================================================================
-- objects.sql — Objetos de Base de Datos para Food Store
-- Contiene: Vistas (seguridad y catálogo), Funciones PL/pgSQL,
--           Triggers (reglas de negocio e integridad) y Procedimientos Almacenados.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. VISTAS
-- -----------------------------------------------------------------------------

-- V1: Categorías vigentes
CREATE OR REPLACE VIEW v_categorias_vigentes AS
SELECT id, nombre, descripcion
FROM   categoria
WHERE  eliminado = FALSE;

-- V2: Catálogo de productos vigentes con categoría
CREATE OR REPLACE VIEW v_productos_vigentes AS
SELECT p.id,
       p.nombre,
       p.precio,
       p.stock,
       p.disponible,
       p.categoria_id,
       c.nombre AS categoria_nombre
FROM   producto p
JOIN   categoria c ON c.id = p.categoria_id
WHERE  p.eliminado = FALSE
  AND  c.eliminado = FALSE
  AND  p.disponible = TRUE;

-- V3: Pedidos con usuario (Criterio de seguridad: oculta contraseña y datos sensibles)
CREATE OR REPLACE VIEW v_pedidos_con_usuario AS
SELECT ped.id,
       ped.fecha,
       ped.estado,
       ped.total,
       ped.forma_pago,
       ped.usuario_id,
       u.nombre   AS usuario_nombre,
       u.apellido AS usuario_apellido,
       u.mail     AS usuario_mail,
       u.rol      AS usuario_rol
FROM   pedido ped
JOIN   usuario u ON u.id = ped.usuario_id
WHERE  ped.eliminado = FALSE
  AND  u.eliminado = FALSE;

-- V4: Detalle de pedido con nombre de producto
CREATE OR REPLACE VIEW v_detalle_con_producto AS
SELECT dp.id,
       dp.pedido_id,
       dp.producto_id,
       pr.nombre AS producto_nombre,
       dp.cantidad,
       dp.precio_unitario,
       dp.subtotal
FROM   detalle_pedido dp
JOIN   producto pr ON pr.id = dp.producto_id
WHERE  dp.eliminado = FALSE
  AND  pr.eliminado = FALSE;


-- -----------------------------------------------------------------------------
-- 2. FUNCIONES
-- -----------------------------------------------------------------------------

-- Función para calcular el monto total de un pedido
CREATE OR REPLACE FUNCTION calcular_total_pedido(p_pedido_id BIGINT)
RETURNS NUMERIC(12,2) AS $$
    SELECT COALESCE(SUM(subtotal), 0)
    FROM   detalle_pedido
    WHERE  pedido_id = p_pedido_id AND eliminado = FALSE;
$$ LANGUAGE sql STABLE;


-- -----------------------------------------------------------------------------
-- 3. TRIGGERS (Reglas de negocio y cálculo automatizado)
-- -----------------------------------------------------------------------------

-- Trigger A: Cálculo automático de subtotal en detalle_pedido
CREATE OR REPLACE FUNCTION fn_set_subtotal()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.precio_unitario IS NULL THEN
        SELECT precio INTO NEW.precio_unitario
        FROM producto WHERE id = NEW.producto_id;
    END IF;
    NEW.subtotal := NEW.cantidad * NEW.precio_unitario;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_subtotal ON detalle_pedido;
CREATE TRIGGER trg_subtotal
BEFORE INSERT OR UPDATE ON detalle_pedido
FOR EACH ROW EXECUTE FUNCTION fn_set_subtotal();


-- Trigger B: Recálculo automático del total en pedido tras insertar/actualizar detalles
CREATE OR REPLACE FUNCTION fn_recalcular_total()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE pedido p
    SET total = calcular_total_pedido(p.id)
    WHERE p.id IN (SELECT pedido_id FROM afectados);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_total_ins ON detalle_pedido;
CREATE TRIGGER trg_total_ins
AFTER INSERT ON detalle_pedido
REFERENCING NEW TABLE AS afectados
FOR EACH STATEMENT EXECUTE FUNCTION fn_recalcular_total();

DROP TRIGGER IF EXISTS trg_total_upd ON detalle_pedido;
CREATE TRIGGER trg_total_upd
AFTER UPDATE ON detalle_pedido
REFERENCING NEW TABLE AS afectados
FOR EACH STATEMENT EXECUTE FUNCTION fn_recalcular_total();


-- Trigger C: Inmutabilidad de estados terminales en pedido (TERMINADO / CANCELADO)
CREATE OR REPLACE FUNCTION fn_bloquear_pedido_terminal()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.estado IS DISTINCT FROM NEW.estado THEN
        IF OLD.estado IN ('TERMINADO', 'CANCELADO') THEN
            RAISE EXCEPTION 'Transición prohibida: pedido % no puede salir de estado terminal % -> %',
                OLD.id, OLD.estado, NEW.estado
                USING ERRCODE = 'P0001';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_pedido_bloquear_terminal ON pedido;
CREATE TRIGGER trg_pedido_bloquear_terminal
BEFORE UPDATE OF estado ON pedido
FOR EACH ROW EXECUTE FUNCTION fn_bloquear_pedido_terminal();


-- Trigger D: Validación preventiva de stock con bloqueo pesimista (FOR UPDATE)
CREATE OR REPLACE FUNCTION fn_validar_stock_detalle()
RETURNS TRIGGER AS $$
DECLARE
    v_stock INT;
BEGIN
    SELECT stock INTO v_stock
    FROM producto
    WHERE id = NEW.producto_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Producto % no existe', NEW.producto_id USING ERRCODE = 'P0001';
    END IF;

    IF NEW.cantidad > v_stock THEN
        RAISE EXCEPTION 'Stock insuficiente: producto % (stock=%) no puede abastecer cantidad % solicitada',
            NEW.producto_id, v_stock, NEW.cantidad
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_detalle_validar_stock ON detalle_pedido;
CREATE TRIGGER trg_detalle_validar_stock
BEFORE INSERT OR UPDATE OF cantidad, producto_id ON detalle_pedido
FOR EACH ROW EXECUTE FUNCTION fn_validar_stock_detalle();


-- -----------------------------------------------------------------------------
-- 4. PROCEDIMIENTOS ALMACENADOS (Transaccionalidad y lógica atómica)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_crear_pedido(
    p_usuario_id BIGINT,
    p_forma_pago forma_pago,
    p_items      JSONB   -- Ejemplo: '[{"producto_id":1,"cantidad":2}, {"producto_id":2,"cantidad":1}]'
) AS $$
DECLARE
    v_pedido_id   BIGINT;
    v_item        JSONB;
    v_producto_id BIGINT;
    v_cantidad    INTEGER;
    v_stock       INTEGER;
    v_disponible  BOOLEAN;
BEGIN
    -- Validar que el usuario exista y no esté dado de baja
    IF NOT EXISTS (SELECT 1 FROM usuario WHERE id = p_usuario_id AND eliminado = FALSE) THEN
        RAISE EXCEPTION 'Usuario % inexistente o eliminado', p_usuario_id;
    END IF;

    -- Cabecera del pedido
    INSERT INTO pedido(usuario_id, forma_pago)
    VALUES (p_usuario_id, p_forma_pago)
    RETURNING id INTO v_pedido_id;

    -- Procesar cada ítem del JSON
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_producto_id := (v_item->>'producto_id')::BIGINT;
        v_cantidad    := (v_item->>'cantidad')::INTEGER;

        IF v_cantidad <= 0 THEN
            RAISE EXCEPTION 'Cantidad inválida para producto %: % (debe ser > 0)', v_producto_id, v_cantidad;
        END IF;

        -- Bloqueo pesimista para evitar carreras con ventas concurrentes
        SELECT stock, disponible INTO v_stock, v_disponible
        FROM producto WHERE id = v_producto_id AND eliminado = FALSE
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Producto % inexistente o eliminado', v_producto_id;
        END IF;

        IF NOT v_disponible THEN
            RAISE EXCEPTION 'Producto % no disponible para la venta', v_producto_id;
        END IF;

        IF v_stock < v_cantidad THEN
            RAISE EXCEPTION 'Stock insuficiente (producto %): hay %, se solicitan %',
                            v_producto_id, v_stock, v_cantidad;
        END IF;

        -- Insertar detalle (dispara triggers de subtotal y recálculo de total)
        INSERT INTO detalle_pedido(pedido_id, producto_id, cantidad)
        VALUES (v_pedido_id, v_producto_id, v_cantidad);

        -- Descontar inventario
        UPDATE producto SET stock = stock - v_cantidad WHERE id = v_producto_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

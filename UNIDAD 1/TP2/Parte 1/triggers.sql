-- =============================================================================
-- triggers.sql — Restricciones de concurrencia e integridad para food_store
-- Reglas:
--  1) Inmutabilidad total de estados terminales en pedido (TERMINADO/CANCELADO)
--  2) Validación por fila: detalle_pedido.cantidad <= producto.stock
-- Ejecutar SIEMPRE sobre copia_trabajo, nunca sobre food_store (ver AGENTS.md)
-- Requiere respaldo previo si es DDL: pg_dump -d copia_trabajo -F c -f backup
-- Usa transacción segura: BEGIN; \i triggers.sql; -- verificar --; ROLLBACK/COMMIT;
-- =============================================================================

-- -------------------------------------------------------------------------
-- 1) Bloquear transición desde estados terminales en pedido
--    schema.sql:44-53  pedido.estado estado_pedido DEFAULT PENDIENTE
--    Enum: PENDIENTE, CONFIRMADO, TERMINADO, CANCELADO (schema.sql:6-7)
--    Regla: TERMINADO y CANCELADO son inmutables — cualquier cambio posterior es prohibido
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_bloquear_pedido_terminal()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Solo actúa si el estado realmente cambia
    IF OLD.estado IS DISTINCT FROM NEW.estado THEN
        IF OLD.estado IN ('TERMINADO', 'CANCELADO') THEN
            RAISE EXCEPTION 'Transición prohibida: pedido % no puede salir de estado terminal % -> %', OLD.id, OLD.estado, NEW.estado
                USING ERRCODE = 'P0001';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pedido_bloquear_terminal ON pedido;

CREATE TRIGGER trg_pedido_bloquear_terminal
BEFORE UPDATE OF estado ON pedido
FOR EACH ROW
EXECUTE FUNCTION fn_bloquear_pedido_terminal();

COMMENT ON FUNCTION fn_bloquear_pedido_terminal() IS 'Regla 1: Inmutabilidad total de estados terminales TERMINADO/CANCELADO en pedido. Cualquier UPDATE que intente salir del terminal hace RAISE.';
COMMENT ON TRIGGER trg_pedido_bloquear_terminal ON pedido IS 'BEFORE UPDATE OF estado: bloquea transiciones desde TERMINADO/CANCELADO';


-- -------------------------------------------------------------------------
-- 2) Validar stock por fila en detalle_pedido
--    schema.sql:55-66 detalle_pedido.cantidad CHECK >0
--    schema.sql:19-30 producto.stock  INTEGER CHECK >=0  (data.sql:11-20 stock 10..200)
--    Regla: NEW.cantidad <= producto.stock (validación por fila, FOR UPDATE para concurrencia)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_stock_detalle()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INT;
BEGIN
    -- Lock pesimista sobre la fila de producto para serializar validaciones concurrentes
    -- Evita race condition: dos transacciones concurrentes INSERT con cantidad al límite
    SELECT stock INTO v_stock
    FROM producto
    WHERE id = NEW.producto_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Producto % no existe (detalle_pedido validación)', NEW.producto_id
            USING ERRCODE = 'P0001';
    END IF;

    IF NEW.cantidad > v_stock THEN
        RAISE EXCEPTION 'Stock insuficiente: producto % (stock=%) no puede abastecer cantidad % solicitada', NEW.producto_id, v_stock, NEW.cantidad
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_detalle_validar_stock ON detalle_pedido;

CREATE TRIGGER trg_detalle_validar_stock
BEFORE INSERT OR UPDATE OF cantidad, producto_id ON detalle_pedido
FOR EACH ROW
EXECUTE FUNCTION fn_validar_stock_detalle();

COMMENT ON FUNCTION fn_validar_stock_detalle() IS 'Regla 2: Validación por fila cantidad <= producto.stock con SELECT FOR UPDATE para concurrencia. Solo valida, no descuenta stock.';
COMMENT ON TRIGGER trg_detalle_validar_stock ON detalle_pedido IS 'BEFORE INSERT OR UPDATE OF cantidad,producto_id: valida stock por fila';

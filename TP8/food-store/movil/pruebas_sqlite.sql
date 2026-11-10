-- Ejecutar UNA VEZ después del esquema y la carga inicial del catálogo.
-- C7 contiene errores esperados. En sqlite3 usar .bail off (valor por defecto).
-- ejecutar.py comprueba la clase de error y el conteo tras cada rechazo.
PRAGMA foreign_keys = ON;
BEGIN;
INSERT INTO pedido_borrador VALUES ('00000000-0000-4000-8000-000000000001','operador_demo','EFECTIVO','2026-11-06T12:00:00Z');
INSERT INTO item_borrador SELECT '00000000-0000-4000-8000-000000000001',id,1,precio_centavos FROM producto_cache WHERE id=1;
INSERT INTO cola_sync(solicitud_uuid,id_local) VALUES ('10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001');
COMMIT;

-- Otra operación completa deshecha: no deben quedar sus tres filas.
BEGIN;
INSERT INTO pedido_borrador VALUES ('00000000-0000-4000-8000-000000000099','operador_demo','EFECTIVO','2026-11-06T12:00:00Z');
INSERT INTO item_borrador SELECT '00000000-0000-4000-8000-000000000099',id,1,precio_centavos FROM producto_cache WHERE id=1;
INSERT INTO cola_sync(solicitud_uuid,id_local) VALUES ('10000000-0000-4000-8000-000000000099','00000000-0000-4000-8000-000000000099');
ROLLBACK;
SELECT 'ROLLBACK',count(*) FROM pedido_borrador WHERE id_local='00000000-0000-4000-8000-000000000099';

-- C1: solo lee el archivo SQLite, sin consultas al servidor.
SELECT 'C1',id,nombre,precio_centavos,stock_visto FROM producto_cache WHERE disponible=1 AND eliminado=0 ORDER BY id;

SAVEPOINT c7_cantidad;
-- EXPECT_ERROR CHECK
INSERT INTO item_borrador VALUES ('00000000-0000-4000-8000-000000000001',2,0,16000);
ROLLBACK TO c7_cantidad;
RELEASE c7_cantidad;
SAVEPOINT c7_fk;
-- EXPECT_ERROR FOREIGN KEY
INSERT INTO item_borrador VALUES ('00000000-0000-4000-8000-000000000001',999999,1,100);
ROLLBACK TO c7_fk;
RELEASE c7_fk;
SELECT 'C7_items',count(*) FROM item_borrador;

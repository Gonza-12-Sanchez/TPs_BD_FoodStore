-- Parte B. Conectar como app_web. La lectura se registra con log_statement=all.
BEGIN;
SELECT id,nombre,precio FROM public.v_productos_vigentes ORDER BY id LIMIT 3;
INSERT INTO public.pedido(fecha,forma_pago,usuario_id)
VALUES (CURRENT_DATE,'EFECTIVO',1) RETURNING id;
UPDATE public.pedido SET estado='CONFIRMADO'
WHERE id=currval('public.pedido_id_seq');
SELECT id,estado FROM public.pedido WHERE id=currval('public.pedido_id_seq');
ROLLBACK;
-- El intento fallido de conexión del motor se realiza desde ejecutar_lab.py.

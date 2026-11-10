-- Base nueva exclusivamente. Genera 120 usuarios y pedidos de prueba.
BEGIN;
INSERT INTO public.categoria(nombre,descripcion) VALUES
('Empanadas','Categoría sintética'),('Pizzas','Categoría sintética'),
('Bebidas','Categoría sintética'),('Postres','Categoría sintética');
INSERT INTO public.producto(nombre,precio,stock,categoria_id,descripcion)
SELECT 'Producto '||n, 100+n*10, 500, 1+(n-1)%4, 'Descripción de prueba'
FROM generate_series(1,12) n;
INSERT INTO public.usuario(nombre,apellido,mail,celular,contrasena,rol,eliminado,created_at)
SELECT 'PersonaDemo'||n,'ApellidoDemo'||n,'persona'||n||'@laboratorio.test',
       'TEL_DEMO_'||n, public.crypt('ClaveDePruebaU5!', public.gen_salt('bf',6)),
       CASE WHEN n%20=0 THEN 'ADMIN'::public.rol ELSE 'USUARIO'::public.rol END,
       n%17=0,
       timestamptz '2026-01-01 12:00:00+00' + ((n-1)%6)*interval '1 month'
FROM generate_series(1,120) n;
INSERT INTO public.pedido(fecha,forma_pago,usuario_id)
SELECT date '2026-03-01', 'EFECTIVO',n FROM generate_series(1,20) n;
INSERT INTO public.detalle_pedido(cantidad,precio_unitario,subtotal,pedido_id,producto_id)
SELECT 2,110,220,n,1 FROM generate_series(1,20) n;
UPDATE public.pedido p SET total=(SELECT sum(d.subtotal) FROM public.detalle_pedido d
WHERE d.pedido_id=p.id AND NOT d.eliminado);
COMMIT;

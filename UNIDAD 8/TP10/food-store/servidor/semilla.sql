-- Datos inventados. Requiere el esquema original vacío; no usar sobre producción.
BEGIN;
INSERT INTO categoria(nombre) VALUES ('Empanadas'),('Pizzas'),('Bebidas'),('Postres');
INSERT INTO producto(nombre,precio,stock,categoria_id) VALUES
 ('Empanada de Carne',150.00,50,1),
 ('Empanada de Jamon y Queso',160.00,30,1),
 ('Pizza Margherita',800.00,20,2),
 ('Pizza Pepperoni',900.00,15,2);
-- Identidad ficticia exclusiva del servidor. Nunca se exporta a la tablet.
INSERT INTO usuario(nombre,apellido,mail,contrasena) VALUES
 ('Operador','Prueba','operador@example.invalid','NO_ES_UNA_CREDENCIAL');
INSERT INTO pedido(fecha,estado,total,forma_pago,usuario_id)
 VALUES ('2026-11-06','PENDIENTE',150.00,'EFECTIVO',1);
INSERT INTO detalle_pedido(cantidad,precio_unitario,subtotal,pedido_id,producto_id)
 VALUES (1,150.00,150.00,1,1);
COMMIT;

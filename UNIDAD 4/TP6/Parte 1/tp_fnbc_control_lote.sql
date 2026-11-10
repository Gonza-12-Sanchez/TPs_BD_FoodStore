-- Creamos las tablas maestras necesarias
CREATE TABLE IF NOT EXISTS lote (
 id BIGINT PRIMARY KEY
);
CREATE TABLE IF NOT EXISTS deposito (
 id BIGINT PRIMARY KEY
);

-- Tablas descompuestas: 
-- Tabla responsable_deposito
create table responsable_deposito (
	responsable_control_id bigint not null references usuario(id),
	deposito_id bigint not null references deposito(id),
	primary key (responsable_control_id)
);

--Tabla control_lote
create table control_lote (
	lote_id bigint not null references lote(id),
	responsable_control_id bigint not null references responsable_deposito(responsable_control_id),
	primary key (lote_id, responsable_control_id)
)

-- Vista de compatibilidad 
create view v_control_almacen as 
select c.lote_id, rd.deposito_id, c.responsable_control_id
from control_lote c
join responsable_deposito rd on rd.responsable_control_id = c.responsable_control_id;

-- Realizamos poblado de las diferentes tablas para verificar la correcta funcionalidad de la vista de compatibilidad
INSERT INTO lote (id) VALUES (501), (502), (503);
INSERT INTO deposito (id) VALUES (30), (31);

INSERT INTO responsable_deposito (responsable_control_id, deposito_id) VALUES
(801, 30),
(802, 31);

INSERT INTO control_lote (lote_id, responsable_control_id) VALUES
(501, 801),
(502, 801),
(503, 802);

-- Ejecutamos la vista para la verificacion
SELECT * FROM v_control_almacen ORDER BY lote_id;
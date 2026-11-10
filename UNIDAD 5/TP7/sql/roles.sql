-- Parte A. Aplicar una sola vez en una base y un clúster exclusivos del TP.
-- Conexión inicial: administrador del clúster. Sin contraseñas incrustadas.
BEGIN;
CREATE ROLE rol_app_lectura NOLOGIN;
CREATE ROLE rol_app_escritura NOLOGIN;
CREATE ROLE rol_soporte NOLOGIN;
CREATE ROLE rol_reportes NOLOGIN;
CREATE ROLE rol_auth_owner NOLOGIN;
CREATE ROLE rol_operacion_owner NOLOGIN;
CREATE ROLE admin_datos LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE ROLE app_web LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE CONNECTION LIMIT 10;
CREATE ROLE soporte_demo LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE CONNECTION LIMIT 3;
CREATE ROLE reportes_demo LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE CONNECTION LIMIT 3;

-- El propietario administra los datos; no se le da administración del clúster.
ALTER SCHEMA public OWNER TO admin_datos;
CREATE SCHEMA reportes AUTHORIZATION admin_datos;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA reportes FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO rol_app_lectura,rol_app_escritura,rol_soporte,
rol_reportes,rol_auth_owner,rol_operacion_owner;
GRANT USAGE ON SCHEMA reportes TO rol_reportes;

-- Transferir únicamente los objetos heredados que este proyecto importa.
ALTER TYPE public.rol OWNER TO admin_datos;
ALTER TYPE public.estado_pedido OWNER TO admin_datos;
ALTER TYPE public.forma_pago OWNER TO admin_datos;
ALTER TABLE public.categoria OWNER TO admin_datos;
ALTER TABLE public.producto OWNER TO admin_datos;
ALTER TABLE public.usuario OWNER TO admin_datos;
ALTER TABLE public.pedido OWNER TO admin_datos;
ALTER TABLE public.detalle_pedido OWNER TO admin_datos;
ALTER VIEW public.v_categorias_vigentes OWNER TO admin_datos;
ALTER VIEW public.v_productos_vigentes OWNER TO admin_datos;
ALTER VIEW public.v_pedidos_con_usuario OWNER TO admin_datos;
ALTER VIEW public.v_detalle_con_producto OWNER TO admin_datos;
ALTER FUNCTION public.calcular_total_pedido(bigint) OWNER TO admin_datos;
ALTER FUNCTION public.fn_set_subtotal() OWNER TO admin_datos;
ALTER FUNCTION public.fn_recalcular_total() OWNER TO admin_datos;
ALTER FUNCTION public.fn_bloquear_pedido_terminal() OWNER TO admin_datos;
ALTER FUNCTION public.fn_validar_stock_detalle() OWNER TO admin_datos;
ALTER PROCEDURE public.sp_crear_pedido(bigint,public.forma_pago,jsonb) OWNER TO admin_datos;

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE EXECUTE ON ALL ROUTINES IN SCHEMA public FROM PUBLIC;

-- Las tablas de negocio futuras no se publican a los roles operativos.
ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public
REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public
REVOKE ALL ON SEQUENCES FROM PUBLIC;
-- Debe ser GLOBAL: el EXECUTE implícito de PUBLIC no se elimina por esquema.
ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA reportes
GRANT SELECT ON TABLES TO rol_reportes;

GRANT SELECT ON public.v_productos_vigentes,public.v_categorias_vigentes TO rol_app_lectura;
GRANT SELECT ON public.pedido,public.detalle_pedido TO rol_app_escritura;
GRANT INSERT(fecha,forma_pago,usuario_id),UPDATE(estado) ON public.pedido TO rol_app_escritura;
GRANT USAGE ON SEQUENCE public.pedido_id_seq TO rol_app_escritura;
REVOKE DELETE,TRUNCATE ON public.pedido,public.detalle_pedido FROM rol_app_escritura;
GRANT SELECT(id,nombre,apellido,mail,rol,eliminado) ON public.usuario TO rol_soporte;

GRANT SELECT(id,mail,rol,contrasena,eliminado) ON public.usuario TO rol_auth_owner;
GRANT UPDATE(contrasena) ON public.usuario TO rol_auth_owner;
GRANT SELECT ON public.producto,public.pedido,public.detalle_pedido TO rol_operacion_owner;
GRANT SELECT(id,eliminado) ON public.usuario TO rol_operacion_owner;
GRANT INSERT ON public.pedido,public.detalle_pedido TO rol_operacion_owner;
GRANT UPDATE(stock) ON public.producto TO rol_operacion_owner;
GRANT UPDATE(total) ON public.pedido TO rol_operacion_owner;
GRANT USAGE ON SEQUENCE public.pedido_id_seq,public.detalle_pedido_id_seq TO rol_operacion_owner;
GRANT EXECUTE ON FUNCTION public.calcular_total_pedido(bigint) TO rol_operacion_owner;

-- El procedimiento existente se ejecuta como dueño limitado, no como DBA.
ALTER PROCEDURE public.sp_crear_pedido(bigint,public.forma_pago,jsonb) SECURITY DEFINER;
ALTER PROCEDURE public.sp_crear_pedido(bigint,public.forma_pago,jsonb)
SET search_path TO pg_catalog,public,pg_temp;
ALTER PROCEDURE public.sp_crear_pedido(bigint,public.forma_pago,jsonb) OWNER TO rol_operacion_owner;
GRANT EXECUTE ON PROCEDURE public.sp_crear_pedido(bigint,public.forma_pago,jsonb) TO rol_app_escritura;
GRANT EXECUTE ON FUNCTION public.crypt(text,text),public.gen_salt(text),public.gen_salt(text,integer)
TO rol_auth_owner;

SET ROLE admin_datos;
CREATE VIEW public.v_usuarios_publico AS
SELECT id,nombre,apellido,mail,rol FROM public.usuario WHERE NOT eliminado;
CREATE VIEW public.v_pedidos_resumen AS
SELECT id,fecha,estado,total,usuario_id FROM public.pedido WHERE NOT eliminado;
CREATE VIEW reportes.v_usuarios_por_rol_mes AS
SELECT rol,date_trunc('month',created_at AT TIME ZONE 'UTC')::date AS mes,count(*) AS cantidad
FROM public.usuario WHERE NOT eliminado GROUP BY 1,2;
CREATE VIEW reportes.v_ventas_categoria_mes AS
SELECT c.nombre AS categoria,date_trunc('month',p.fecha)::date AS mes,
sum(d.subtotal) AS facturacion
FROM public.pedido p JOIN public.detalle_pedido d ON d.pedido_id=p.id
JOIN public.producto pr ON pr.id=d.producto_id JOIN public.categoria c ON c.id=pr.categoria_id
WHERE NOT p.eliminado AND NOT d.eliminado AND NOT pr.eliminado AND NOT c.eliminado
AND p.estado='TERMINADO' GROUP BY 1,2;
GRANT SELECT ON public.v_usuarios_publico,public.v_pedidos_resumen TO rol_soporte;
RESET ROLE;

CREATE FUNCTION public.fn_autenticar(p_mail text,p_pass text)
RETURNS TABLE(usuario_id bigint,usuario_rol public.rol)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO pg_catalog,public,pg_temp AS $$
DECLARE v_id bigint; v_rol public.rol;
BEGIN
  -- Parámetros tipados: no hay concatenación de SQL dinámico.
  SELECT u.id,u.rol INTO v_id,v_rol FROM public.usuario u
  WHERE u.mail=p_mail AND NOT u.eliminado
    AND octet_length(p_pass) BETWEEN 12 AND 72
    AND u.contrasena LIKE '$2%'
    AND u.contrasena=public.crypt(p_pass,u.contrasena);
  RAISE LOG 'FS_AUTH resultado=% cuenta=%',
    CASE WHEN v_id IS NULL THEN 'FALLO' ELSE 'EXITO' END,
    replace(replace(coalesce(p_mail,'<NULL>'),chr(10),' '),chr(13),' ');
  IF v_id IS NOT NULL THEN RETURN QUERY SELECT v_id,v_rol; END IF;
END;
$$;
ALTER FUNCTION public.fn_autenticar(text,text) OWNER TO rol_auth_owner;
REVOKE ALL ON FUNCTION public.fn_autenticar(text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_autenticar(text,text) TO app_web,soporte_demo;

CREATE FUNCTION public.fn_resetear_password(p_usuario_id bigint,p_nueva text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO pg_catalog,public,pg_temp AS $$
BEGIN
  IF p_nueva IS NULL OR octet_length(p_nueva) NOT BETWEEN 12 AND 72 THEN
    RAISE EXCEPTION 'La clave debe tener entre 12 y 72 bytes' USING ERRCODE='22023';
  END IF;
  UPDATE public.usuario SET contrasena=public.crypt(p_nueva,public.gen_salt('bf',6))
  WHERE id=p_usuario_id AND NOT eliminado AND rol='USUARIO';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cuenta no habilitada para reseteo por soporte' USING ERRCODE='42501';
  END IF;
END;
$$;
ALTER FUNCTION public.fn_resetear_password(bigint,text) OWNER TO rol_auth_owner;
REVOKE ALL ON FUNCTION public.fn_resetear_password(bigint,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_resetear_password(bigint,text) TO rol_soporte;

GRANT rol_app_lectura,rol_app_escritura TO app_web;
GRANT rol_soporte TO soporte_demo;
GRANT rol_reportes TO reportes_demo;
COMMIT;

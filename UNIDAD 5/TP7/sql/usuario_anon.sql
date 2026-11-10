-- Parte D. Materialización determinista de la técnica de clase.
-- Ejecutar como admin_datos. No exportar IDs/fechas exactas de una base real.
BEGIN;
DROP TABLE IF EXISTS public.usuario_anon;
CREATE TABLE public.usuario_anon AS
SELECT id,'Usuario '||id AS nombre,'Apellido '||id AS apellido,
'usuario'||id||'@ejemplo.test' AS mail,NULL::text AS celular,
'hash_no_valido'::text AS contrasena,rol,eliminado,created_at
FROM public.usuario;
ALTER TABLE public.usuario_anon ADD PRIMARY KEY(id);
REVOKE ALL ON public.usuario_anon FROM PUBLIC;
COMMIT;

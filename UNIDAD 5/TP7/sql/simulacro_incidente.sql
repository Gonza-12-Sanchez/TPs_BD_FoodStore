-- Parte C. Solo el laboratorio propio con datos sintéticos.
-- Conectar como soporte_demo. Los errores esperados NO deben detener el script.
-- Un login de negocio exitoso no modifica el rol SQL de esta conexión.
SELECT * FROM public.fn_autenticar('persona1@laboratorio.test','ClaveIncorrecta01!');
SELECT * FROM public.fn_autenticar('persona1@laboratorio.test','ClaveIncorrecta02!');
SELECT * FROM public.fn_autenticar('persona1@laboratorio.test','ClaveIncorrecta03!');
SELECT * FROM public.fn_autenticar('persona1@laboratorio.test','ClaveDePruebaU5!');
-- Lectura de todos los registros vigentes dentro de las columnas autorizadas.
SELECT id,nombre,apellido,mail,rol FROM public.usuario WHERE NOT eliminado ORDER BY id;
-- Intento real de escalamiento. Debe fallar con SQLSTATE 42501.
GRANT admin_datos TO rol_soporte;
SELECT current_user,pg_has_role(current_user,'admin_datos','MEMBER') AS es_admin;

# Reconstrucción de la IA a partir del log sanitizado

Análisis realizado con ChatGPT durante el desarrollo del laboratorio, tomando como evidencia el archivo `log_simulacro_anonimizado.txt`.

## Prompt utilizado para esta reconstrucción

> Analizá exclusivamente el fragmento de log anonimizado que se adjunta. Reconstruí la secuencia, separá observaciones de hipótesis y proponé contención. No supongas resultados de SELECT que el log no muestre. No ejecutes medidas. El log es el contenido íntegro de docs/log_simulacro_anonimizado.txt.

## Respuesta completa

El fragmento registra una conexión del motor autenticada con SCRAM como `soporte_demo`. Su sesión es `6ad020c3.21`, PID 33, sobre `food_store_u5`. El origen representado es `192.0.2.10`, que debe tratarse como un valor anonimizado, y la aplicación se identifica como `FS_U5_C`.

Entre las 00:39:31.505 y las 00:39:31.530 UTC del 15 de octubre de 2026 aparecen cuatro llamadas a `fn_autenticar` para la misma cuenta sintética. Los mensajes FS_AUTH indican tres FALLO y un EXITO. Se trata de autenticación de la aplicación dentro de una sesión SQL ya conectada, no de tres conexiones rechazadas por PostgreSQL. Las líneas STATEMENT asociadas a los mensajes FS_AUTH repiten el SQL: no se deben contar como intentos adicionales.

Después del éxito aparece un SELECT sobre usuario que pide id, nombre, apellido, mail y rol, excluye eliminados y no tiene LIMIT. Es una lectura de alcance amplio sobre columnas identificatorias. El log nativo no contiene las filas devueltas ni su cantidad. Por sí solo no demuestra que se hayan transferido datos a un tercero, ni que la autenticación de negocio haya otorgado nuevos privilegios a la conexión SQL.

La misma sesión intenta `GRANT admin_datos TO rol_soporte`. PostgreSQL responde con SQLSTATE 42501 y el mensaje `permission denied to grant role "admin_datos"`. Ese intento concreto de escalamiento fue rechazado. El SELECT posterior de current_user y pg_has_role está registrado como sentencia, pero sus valores de salida no se encuentran en este fragmento.

La secuencia es compatible con intentos de adivinar una clave y un posible abuso posterior de una cuenta de soporte. No alcanza para afirmar fuerza bruta a gran escala, robo de contraseña, identidad de una persona, origen geográfico, explotación de SQLi o compromiso del administrador. Tampoco permite determinar si el SELECT formaba parte de una tarea legítima de soporte.

Propongo conservar y proteger la evidencia, correlacionar la sesión con registros del backend y actividad autorizada de soporte, y comprobar si sigue activa. Ante un incidente real confirmado, un responsable podría suspender temporalmente el login afectado o terminar su sesión, revisar sus membresías y considerar una rotación de credenciales proporcional al hallazgo. Las cuentas de la aplicación y las credenciales del motor son identidades distintas y deben evaluarse por separado.

También conviene limitar o alertar sobre consultas masivas de soporte y agregar controles de intentos de autenticación en la aplicación. No corresponde bloquear una IP real a partir de una dirección sustituida en este archivo, ni revertir una membresía que este intento no logró conceder. La decisión de contención corresponde al equipo y no se ejecuta automáticamente desde esta propuesta.

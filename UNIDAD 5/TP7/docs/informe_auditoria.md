# Auditoría de FoodStore (Parte B)

## Configuración aplicada

Se ejecutó PostgreSQL 16.15 en un clúster temporal exclusivo con 120 usuarios ficticios.
Se incorporó `config/auditoria.conf` al servidor y se reinició para activar el colector.
La consulta de pg_settings confirmó los valores y `pending_restart=false`.

| Parámetro | Valor efectivo | Motivo |
|---|---|---|
| logging_collector | on | Escribir el registro en un archivo del servidor. |
| log_destination | stderr | Destino recolectado en el archivo del laboratorio. |
| log_connections / log_disconnections | on / on | Identificar inicio y cierre de sesiones. |
| log_statement | all | Registrar también las lecturas exigidas por B y C. |
| log_min_error_statement | error | Incorporar el SQL asociado a operaciones rechazadas. |
| log_timezone | UTC | Comparar eventos sin ambigüedad de zona. |
| log_file_mode | 0600 | Restringir el archivo al usuario del servicio en Unix. |
| log_parameter_max_length / log_parameter_max_length_on_error | 0 / 0 | Evitar valores Bind en los mensajes que admiten esa configuración. |
| log_line_prefix | fecha, PID, sesión, usuario, base, aplicación, origen, SQLSTATE | Correlacionar quién, qué, cuándo y desde dónde. |

Los valores completos están en `evidencias/configuracion_efectiva.json`. El modo mod alcanza para DML y DDL, pero no para registrar los SELECT de esta práctica. Al cerrar el laboratorio se vuelve a mod. Ninguno de esos parámetros elimina contraseñas escritas como literales dentro del SQL: las llamadas con claves de prueba quedan confinadas al clúster y solo se entrega el log sanitizado.

## Prueba ejecutada

`auditoria_test.sql` se ejecutó como app_web dentro de BEGIN/ROLLBACK:

1. SELECT de tres productos desde la vista autorizada.
2. INSERT de un pedido con usuario ficticio 1.
3. UPDATE del estado de ese mismo pedido a CONFIRMADO.
4. Consulta del estado y ROLLBACK.
5. Nueva conexión real al motor con contraseña incorrecta, rechazada con 28P01.

La evidencia está en `log_auditoria_prueba.txt` y `evidencias/resultado_auditoria.json`.
ROLLBACK revierte las filas, aunque el número consumido por la secuencia no se recupera.
El log de una sentencia de escritura no demuestra por sí solo un COMMIT: hay que considerar el resultado de la transacción.

## Lectura del fragmento

| Pregunta | Evidencia concreta |
|---|---|
| Quién | usuario=app_web y autenticación SCRAM de la sesión 6ad020c3.1d. |
| Qué | SELECT de catálogo, INSERT de pedido, UPDATE de estado, ROLLBACK. |
| Cuándo | 2026-10-15 00:39:31 UTC, equivalente al 14 de octubre a las 21:39:31 en Argentina. |
| Desde dónde | IP sustituida 192.0.2.10 y puerto de conexión, junto con el PID y la sesión. |
| Intento fallido | Otro PID y sesión con FATAL y SQLSTATE 28P01. |

La dirección compartida es sintética. `application_name` es informativo y lo puede elegir el cliente: no autentica a una persona.

## Alcance y granularidad

El log nativo registra sentencias y eventos de conexión, pero no las filas devueltas, una imagen anterior/posterior de cada fila o toda la actividad SQL interna de las funciones. FS_AUTH agrega explícitamente el resultado de la autenticación de negocio sin registrar la clave en su propio mensaje.

pgAudit permite clasificar auditoría por operaciones/objetos y registrar suboperaciones de funciones; puede incluir conteos de filas según su configuración y versión. No equivale a una bitácora automática de valores OLD/NEW por fila. Para ese objetivo se necesita un diseño específico, como triggers de auditoría o un mecanismo de captura de cambios. No se instaló pgAudit porque el TP pide nociones, no su despliegue.

## El log como activo sensible

Sí: un log puede revelar identificadores, consultas, infraestructura y credenciales escritas accidentalmente como literales. Deben leerlo solo el usuario del servicio y el personal autorizado de administración/auditoría, mediante permisos del sistema operativo (0600 en Unix o ACL equivalentes en Windows), sin dar acceso al backend o a soporte. En un caso real se enviaría además a un repositorio protegido externo al servidor para dificultar la alteración de evidencia.

No se entregan los logs originales ni las credenciales generadas.

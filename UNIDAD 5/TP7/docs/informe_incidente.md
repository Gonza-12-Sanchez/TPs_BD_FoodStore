# Simulacro y contraste crítico (Parte C)

## Entorno y secuencia realmente ejecutada

Prueba exclusivamente contra la base propia `food_store_u5`, poblada con personas ficticias.
El script SQL se ejecutó desde Python, con autocommit y comprobación explícita de cada resultado.
No hubo acciones contra sistemas externos.

| Paso | Resultado técnico verificado |
|---|---|
| Tres claves incorrectas en fn_autenticar | Cada llamada devolvió 0 filas y emitió FS_AUTH FALLO. |
| Una clave válida en fn_autenticar | Devolvió el usuario de negocio 1 con rol USUARIO y emitió EXITO. |
| Lectura sin LIMIT sobre usuario, excluyendo eliminados | Devolvió 113 filas con cinco columnas autorizadas. |
| GRANT admin_datos TO rol_soporte | Rechazado con SQLSTATE 42501. |
| Verificación posterior | current_user=soporte_demo y pg_has_role(..., MEMBER)=false. |

Los resultados originales de las filas identificatorias no se exportan. Los conteos y estados figuran en `evidencias/resultado_incidente.json`.

## Qué demuestra el incidente

El login del motor es soporte_demo durante toda la secuencia. El éxito de fn_autenticar corresponde a una identidad de negocio y no convierte automáticamente esa conexión en otro rol SQL. La lectura masiva explota el alcance legítimo de lectura de soporte sobre varias filas: el simulacro representa su uso indebido, sin necesitar conceder lectura de hashes ni permisos nuevos.

El fracaso del escalamiento no significa que toda fuga de información esté impedida. El rol puede leer las columnas autorizadas de todos los usuarios vigentes. El diseño exige control de uso de soporte y monitoreo de exportaciones; no afirma aislamiento por cliente ni una protección RLS inexistente.

## Sanitización

Antes de compartir el fragmento se sustituyeron cuentas por correos `.test`, el origen por una IP de documentación y todas las claves sintéticas por `<CLAVE_OCULTA>`. Se mantuvieron las marcas temporales, la correlación de sesión, las sentencias y sus errores. `scripts/anonimizar_log.py` automatiza el tratamiento de este laboratorio; otros formatos requieren revisión manual adicional.

El archivo entregado conserva el fragmento del servidor con los identificadores sanitizados.

## Contraste con la reconstrucción de ChatGPT

La respuesta completa y su prompt constan en `respuesta_ia_incidente.md`. Se contrastó el análisis con las operaciones ejecutadas y los resultados capturados por el cliente.

| Afirmación de la IA | Contraste con lo ejecutado |
|---|---|
| Hubo tres fallos y un éxito de autenticación de negocio | Correcto: coincide con los cuatro resultados del cliente y los eventos FS_AUTH. |
| Las líneas STATEMENT repetidas no son nuevos intentos | Correcto: el orquestador ejecutó cuatro llamadas. |
| Se consultó usuario sin LIMIT, dentro de columnas concretas | Correcto: el cliente recibió 113 filas. El número no se puede deducir del log solo. |
| El intento de otorgar admin_datos fue rechazado | Correcto: SQLSTATE 42501 y membresía final false. |
| El log no demuestra extracción a un tercero ni robo de clave | Correcto: no se realizaron esas acciones en el simulacro. |
| No se conoce el resultado del SELECT posterior solo con el log | Correcto: se necesita la salida del cliente para confirmar current_user y es_admin. |

La reconstrucción no enumeró los 120 usuarios totales, los 7 eliminados, el resultado de la consulta de membresía o la clave utilizada, porque no estaban disponibles como valores en el fragmento. Esas omisiones son adecuadas. No se detectaron afirmaciones factuales sin respaldo en la respuesta analizada.

## Decisión de contención para el caso analizado

El criterio adoptado es preservar la evidencia y confirmar el abuso antes de modificar accesos. En un incidente real se resguardaría una copia del log y se correlacionarían sesión, cuenta y consulta con los registros del backend y las tareas autorizadas de soporte.

Si se confirma uso indebido, se suspendería temporalmente el login afectado, se cerrarían sus sesiones activas y se rotaría su credencial. Además, se revisaría el alcance de soporte y se incorporarían alertas ante lecturas masivas y límites de intentos de autenticación en el backend.

No se revierte una membresía administrativa porque el escalamiento fue rechazado y la verificación posterior dio false. Tampoco se bloquearía un origen real usando la IP de documentación que aparece en el log sanitizado.

La decisión se fundamenta en los resultados del laboratorio: los permisos impidieron el escalamiento, pero la capacidad de lectura de soporte permite un uso abusivo que exige supervisión adicional. La contención se establece como respuesta para un caso real; durante el simulacro no se aplicaron bloqueos ni rotaciones automáticamente.

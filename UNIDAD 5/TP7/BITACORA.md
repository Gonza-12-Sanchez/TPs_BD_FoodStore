# Bitácora de uso de IA

**Proyecto:** FoodStore, Unidad 5.  
**Herramienta de asistencia:** ChatGPT.  
**Ejecución y trazabilidad:** PostgreSQL 16.15 y Git.

El equipo informó una revisión conjunta del material el 14 de octubre de 2026.
Se registran esa revisión general y las verificaciones técnicas asociadas.
Las fases A a E desglosan el encargo general de resolver el trabajo sobre los
repositorios y la teoría aportados; no representan conversaciones independientes.
Los prompts se resumen conservando su finalidad.

| Prompt enviado a la IA | Respuesta relevante recibida (resumida, no es necesario copiar la respuesta completa) | Validación o corrección humana aplicada |
|---|---|---|
| Encargo inicial: revisar la consigna e identificar qué datos y trabajos anteriores se necesitan. | Identificación de los scripts base, el entorno PostgreSQL y los contenidos de roles, auditoría y protección de datos. | El equipo aportó los dos repositorios de FoodStore y el material de las clases de Unidad 5. |
| Parte A, derivada del encargo general: especificar los roles antes de programarlos y limitar cada permiso a su finalidad. | requirements/design, roles.sql y funciones de autenticación/reseteo reconstruidas. | Revisión general comunicada por el equipo. Evidencia técnica: 4.194 comparaciones de permisos y 27 comprobaciones funcionales aprobadas. |
| Parte B: activar auditoría y ejecutar lectura, inserción, actualización y un intento de conexión fallido. | Configuración del servidor, script de prueba, fragmento sanitizado e informe. | Se contrastaron el log y la salida del cliente: operaciones dentro de BEGIN/ROLLBACK y conexión rechazada con 28P01. Se utilizó all durante la captura para incluir SELECT. |
| Parte C: reproducir el incidente controlado sobre la base propia de prueba. | Tres autenticaciones fallidas, una exitosa, lectura de 113 usuarios vigentes e intento de escalamiento rechazado. | Los resultados del cliente confirmaron SQLSTATE 42501 y ausencia de membresía en admin_datos. La lectura masiva quedó limitada a columnas autorizadas. |
| Reconstrucción: analizar el log sanitizado, separar observaciones de hipótesis y proponer contención sin ejecutar acciones. | Respuesta completa en docs/respuesta_ia_incidente.md y contraste con la ejecución. | Se distinguieron autenticación de negocio y conexión SQL; el conteo de filas se tomó de la salida del cliente. Se estableció el criterio de contención en el informe. |
| Parte D: agrupar usuarios vigentes por rol y mes UTC en usuario_anon y generar la consulta equivalente sobre usuario. | Dos consultas equivalentes y comparación bidireccional mediante EXCEPT. | Se comprobaron nueve grupos idénticos y cero diferencias. Se documentó que conservar IDs y fechas no demuestra anonimización irreversible. |
| Cierre: consolidar bitácora, informes y repositorio para la corrección. | Documentación organizada por partes, guía de ejecución e historial Git. | El equipo comunicó su revisión general y solicitó la preparación de la versión final. Se conservaron los resultados y se consolidó la presentación. |

## Revisión de permisos demasiado amplios

El ejemplo de clase permite SELECT automático para reportes sobre futuras tablas
de public y muestra INSERT/UPDATE de tabla completa en operaciones de compra.
Se revisó ese punto de partida y se descartó trasladarlo sin restricciones:

- Los defaults de lectura se limitaron al esquema reportes; public permanece privado.
- La escritura directa sobre pedido se restringió a las columnas previstas.
- La creación completa de compras y la modificación de stock quedaron encapsuladas
  en un procedimiento con dueño NOLOGIN y permisos puntuales.

El criterio fue evitar exponer futuras tablas personales o permitir cambios
directos de importes calculados. El origen de la alternativa amplia es el material
de clase; la adaptación y las pruebas se realizaron durante la implementación.

## Error detectado durante la preparación asistida

La configuración inicial asumió que el servidor iniciado en segundo plano sería
accesible desde otra ejecución del entorno. El cliente devolvió `connection refused`.
Se corrigió manteniendo servidor y cliente en una misma sesión; las pruebas
posteriores se ejecutaron contra PostgreSQL y produjeron los logs entregados.
La corrección muestra la necesidad de contrastar las suposiciones de la IA con
la salida efectiva del entorno antes de registrar una prueba como exitosa.

## Otras correcciones técnicas

- Se distinguió pgAudit de una auditoría automática de valores OLD/NEW por fila.
- Se documentó que varios cambios DDL de PostgreSQL son transaccionales; CREATE
  DATABASE tiene restricciones diferentes.
- En la carga sintética se calificó la correlación `d.pedido_id=p.id` para evitar
  que un identificador interno se resolviera contra la tabla equivocada.
- Se mantuvo privada la tabla usuario_anon y solo se compartieron esquema,
  agregados y logs sanitizados.

## Historial y cierre

Git conserva el avance de especificación, roles, auditoría, incidente, equivalencia
y consolidación. La versión final añade la revisión de presentación y el criterio
de contención. Los commits mantienen su autoría y fechas originales.

Las decisiones del informe se sustentan en las evidencias técnicas. La contención
se describe como respuesta para un incidente real; en el laboratorio no se
aplicaron automáticamente bloqueos de cuentas, cambios de membresía ni rotaciones.

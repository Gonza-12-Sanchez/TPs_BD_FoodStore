# Bitácora de uso de IA

Fecha de trabajo: 6 de noviembre de 2026 (Argentina). No se atribuyen lecturas, decisiones o ensayos personales a los integrantes.

| Entrada | Herramienta y pedido | Aceptado | Descartado o ajustado | Evidencia |
|---|---|---|---|---|
| 1 | ChatGPT/Codex: leer el TP8, redactar cuatro requisitos EARS antes del código y diseñar la separación de autoridades. | SQLite como caché y borradores; PostgreSQL como autoridad; documentos requirements/design/tasks. | Interpretar el verde como venta o modificar stock desde la tablet, por contradecir la consigna. | `docs/kiro/`; documentos creados antes de la primera implementación. |
| 2 | ChatGPT/Codex: implementar y probar C1–C7 con una base ficticia nueva. | Transacciones, CSV reales, CHECK, FK, UUID único, comparación del servidor antes/después. | Usar resultados esperados como si fueran pruebas: se ejecutaron y conservaron logs reales. | `ejecuciones/validacion01/` y validación final de la versión revisada. |
| 3 | OpenCode, agente Plan: revisar todos los scripts disponibles del adjunto, proponer comprobaciones y generar versiones revisadas del esquema y semáforo a partir de las tareas. | Triggers de conservación de resueltas, motivos específicos y controles adicionales U6/U7. | Desactivar FK y reemplazar toda la caché: pierde referencias y lápidas. | `evidencias/opencode_plan.jsonl`, `opencode_revision.md`, `scripts_para_revision.txt`. |
| 4 | ChatGPT/Codex: evaluar los hallazgos de OpenCode mediante pruebas reales y adoptar solo cambios comprobados. | H6: control de totales; H7: completitud; H8: inmutabilidad; nueva ejecución C1–C7 exitosa. | Presentar índices como mejoras garantizadas: faltan mediciones representativas. | `evidencias/revision_postgresql.txt`, `docs/revision_ia.md` y logs finales. |
| 5 | OpenCode Plan: revisar los scripts de servidor, lanzadores y una copia anonimizada de data.sql. | Comparación de filas completas y comprobaciones activas con Python optimizado. Se verificó la correlación corregida de los totales en una base aislada. | Cambiar el esquema compartido para este TP. Se conservó la compatibilidad y se documentó la corrección histórica con ROLLBACK. | `revision_ia.md`, `evidencias/opencode_revision_complementaria.md`, `../ejecuciones/revalidacion/`. |

## Uso de Kiro

Los tres documentos de especificación se redactaron antes de la primera implementación. El primer intento de abrirlos en Kiro venció durante la autorización. En un intento posterior, el asistente abrió los tres documentos en Kiro y revisó sus vistas previas. La revisión está registrada en `evidencias/revision_kiro.md`. La evidencia disponible acredita esa apertura posterior. La generación del esquema y del semáforo revisados se realizó con OpenCode.

## Incidencias técnicas

El acceso directo `opencode` de npm apuntaba a un archivo de instalación incompleta. Se utilizó el ejecutable Windows ya instalado dentro del paquete; no se cambió la configuración global. Se conservaron los eventos originales del agente Plan. Para el laboratorio se corrigió el manejo de stdout/stderr de PostgreSQL en Windows usando archivos de log, porque los procesos servidor pueden heredar los handles de las tuberías. El lanzador Python final arrancó, ejecutó todas las pruebas y detuvo su servidor correctamente.

## Pendientes personales del equipo

- Leer y poder explicar cada script y cada decisión.
- Validar esta declaración con la plantilla oficial de DUIA si la cátedra exige un formato específico (no fue adjuntada).
- Realizar el ensayo de 10 minutos y la defensa individual; no se presenta como hecho.

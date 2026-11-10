# Declaración de Uso de Inteligencia Artificial (DUIA)

**Trabajo:** TP8, Food Store en la feria · Base de Datos II · UTN · 2026.

**Integrantes:** Gonzalo Sanchez, Roman Avila, Mailen Ortiz, Leo Fachinelli, Maximiliano Mendez y Gabriel D'Anna.

## Herramientas y propósito

Se utilizó ChatGPT/Codex para interpretar la consigna, preparar requisitos EARS, elaborar una implementación inicial, orquestar pruebas, evaluar la revisión, organizar la documentación y redactar el informe. Se utilizó OpenCode en modo Plan para revisar los scripts disponibles de la cursada y generar las versiones revisadas de `schema_sqlite.sql` y `semaforo.sql`. Los archivos de especificación se prepararon para Kiro y se solicitó abrirlos en ese editor; no se atribuye generación de código a su agente de IA.

Las pruebas automatizadas se ejecutaron sobre una instancia PostgreSQL aislada y bases SQLite de prueba. Los CSV provienen de exportaciones reales. Se conservaron el pedido a OpenCode, su respuesta y los resultados locales. La revisión con IA no se aceptó íntegramente: se documentan correcciones y una propuesta descartada con fundamento.

La tablet no contiene contraseñas, correos ni datos personales de usuarios. Su operador es un alias ficticio. Los datos del servidor de prueba también son inventados. No se utilizaron datos productivos ni se modificaron bases anteriores.

## Prompt y especificación utilizados

En la comprobación posterior se abrieron y revisaron los tres documentos de especificación dentro de Kiro. Esta revisión del asistente está documentada en `evidencias/revision_kiro.md`; no se atribuye al agente de IA de Kiro.

La especificación completa está en `kiro/requirements.md`, `kiro/design.md` y `kiro/tasks.md`, con cuatro requisitos EARS vinculados a C1–C7. A OpenCode se le solicitó revisar todos los scripts adjuntos, señalar hallazgos con pruebas SQL propuestas y generar versiones revisadas de `schema_sqlite.sql` y `semaforo.sql` a partir de esos requisitos. Se indicó que no ejecutara comandos, no modificara archivos y no inventara resultados de pruebas. El adjunto y la respuesta original se conservan en `evidencias/`.

## Qué generó la IA

ChatGPT/Codex preparó la especificación, la implementación inicial, el ejecutor de pruebas y la documentación. OpenCode generó las versiones revisadas del esquema y del semáforo y una revisión estática de los scripts disponibles. ChatGPT/Codex incorporó esas versiones y ejecutó nuevamente las pruebas.

## Qué se aceptó

- Tablas STRICT, centavos enteros, claves foráneas activas y transacciones de borrador.
- Semáforo con prioridad del rechazo y evaluación exclusiva de solicitudes pendientes.
- Triggers para conservar las solicitudes resueltas y bloquear su reapertura.
- Controles complementarios de coherencia de totales (U6) y completitud del lote (U7).

## Qué se modificó o descartó y por qué

- Se descartó desactivar las FK y borrar toda la caché: se perderían referencias y contexto de pedidos offline. Se conserva UPSERT y baja lógica.
- Se ajustaron las pruebas para crear un UUID nuevo en cada reintento, respetando la inmutabilidad de solicitudes resueltas.
- Se corrigió el lanzador de PostgreSQL para registrar la salida en archivos y evitar esperas por handles heredados en Windows.
- No se aceptaron afirmaciones de mejoras de índices como resultados medidos: necesitan EXPLAIN ANALYZE y una carga representativa.

## Verificación realizada

Las pruebas C1–C7 pasaron en PostgreSQL 18.6 y SQLite 3.50.4, incluyendo COMMIT/ROLLBACK, errores CHECK/FK, rechazo de UUID repetido y comparación del servidor antes/después de simular. La base final devuelve `integrity_check=ok` y ninguna violación en `foreign_key_check`. Se comprobaron además los hallazgos H2, H6, H7 y H8 y el descarte de borrar un producto referenciado. Los resultados están en `ejecuciones/validacion_final/` y `evidencias/revision_postgresql.txt`.

## Responsabilidad académica y formato

Este texto es una declaración propuesta para que el equipo la lea y ratifique antes de presentar. La generación de estos archivos **no acredita** que cada integrante haya realizado todavía la revisión personal ni el ensayo de defensa. El equipo debe verificar el contenido y poder explicar los scripts y las decisiones.

Se cotejó la organización con las DUIA anteriores del proyecto (`TP3/Parte 1/DUIA_Parte1.md` y `TP5/6/duia.md`): herramienta, prompt/spec, generación, aceptación, modificaciones/descarte y verificación. No se encontró una plantilla oficial independiente; por eso no se presenta el formato anterior del equipo como una certificación de la cátedra. No se incluyen firmas inventadas.

**Fecha de preparación:** 6 de noviembre de 2026.

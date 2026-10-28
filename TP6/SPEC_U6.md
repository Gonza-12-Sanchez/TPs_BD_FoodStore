# SPEC_U6 — Mantenimiento, respaldo y recuperación (Food Store)

**Materia:** Bases de Datos II · **Unidad 6** · **Motor:** PostgreSQL 16+
**Base principal:** `foodstore` · **Base de restauración:** `foodstore_restore_test`
**Plataforma:** Windows 10/11 · PowerShell 7 · `pg_dump`/`pg_restore` del cliente

## 1. Alcance

Se especifican cuatro tareas operativas sobre `foodstore`. Queda fuera de alcance: PITR con archivado de WAL, replicación, respaldos offsite y alta disponibilidad.

## 2. Tareas especificadas

| Tarea (qué se automatiza) | Frecuencia | Evidencia | Condición de éxito verificable |
|---|---|---|---|
| **Respaldo de `foodstore`** en formato custom (`-Fc`) a `backups/foodstore_YYYYMMDD_HHMMSS.dump`, con log en `logs/` | Diaria (00:30) | `.dump` + `logs/backup_YYYYMMDD_HHMMSS.log` | El script sale con código 0, el archivo existe con tamaño > 0, `pg_restore -l` lista su contenido sin error y el log registra hora de inicio, fin y resultado |
| **Chequeo de salud** con `health_check.sql`: tamaño de la base, conexiones, estado de tablas y consultas activas | Diaria (08:00) | Salida de las 4 consultas guardada en `logs/health_YYYYMMDD.log` | Las 4 consultas terminan sin error y la salida contiene valores numéricos para las 4 métricas |
| **Revisión de mantenimiento** con `maintenance.sql`: tuplas muertas, `last_autovacuum`/`last_autoanalyze` y estadísticas por tabla | Semanal (lunes) | Salida en `logs/maintenance_YYYYMMDD.log` + decisión escrita | La revisión se ejecuta y la decisión (no actuar / ejecutar `ANALYZE` o `VACUUM` puntual) queda justificada con los números observados |
| **Restauración de prueba** en `foodstore_restore_test` con el último `.dump` | Semanal (viernes) | Base `foodstore_restore_test` validada + RTO medido | Conteos de filas iguales al baseline (sección 4), controles lógicos en 0 y tiempo total registrado |

## 3. Reglas de seguridad (no negociables)

1. **Sin contraseñas en scripts ni en el repositorio.** Credenciales vía variable de entorno `PGPASSWORD` o `%APPDATA%\postgresql\pgpass.conf`.
2. **`foodstore` no se elimina, no se reemplaza ni se restaura encima** durante el simulacro. Toda restauración va a `foodstore_restore_test`.
3. **Pruebas destructivas solo en entornos descartables** (`foodstore_restore_test`).
4. **Antes de cualquier DDL** sobre la base de trabajo, ejecutar el paso 3 de `protocolo_seguridad.md` (`pg_dump` previo): `ROLLBACK` no protege contra cambios estructurales.
5. **Scripts de escritura (INSERT/UPDATE/DELETE) dentro de `BEGIN; ... ROLLBACK;`** para inspección previa, según `protocolo_seguridad.md`.
6. **Formato custom obligatorio** (`-Fc`) para permitir `pg_restore`.
7. **`VACUUM FULL` prohibido como mantenimiento periódico.** `VACUUM`/`ANALYZE` manual solo si la observación previa de tuplas muertas lo justifica.

## 4. Baseline de validación

Tablas del esquema real (`schema.sql`), a contar antes del respaldo y después de restaurar: `categoria`, `producto`, `usuario`, `pedido`, `detalle_pedido`.
Los conteos post-restauración deben ser **idénticos** al baseline registrado en `baseline_u6.md`. Los controles lógicos (`precio`/`stock` negativos en `producto`, `cantidad <= 0` o `precio_unitario < 0` en `detalle_pedido`) deben devolver **0**. El esquema no tiene tabla `cliente`: la equivalencia se toma sobre `usuario`.

## 5. Objetivos previstos

| Métrica | Valor previsto | Definición operativa |
|---|---|---|
| **RPO** | ≤ 24 h | Antigüedad del último respaldo al momento del simulacro |
| **RTO** | ≤ 10 min | Desde `createdb` de `foodstore_restore_test` hasta el fin de las validaciones exitosas |

Valores a comparar contra lo observado en `informe_u6.pdf`.

## 6. Entorno verificado

- **Servidor:** PostgreSQL **17.10** en `localhost:5432` (única instalación de la máquina). Cliente `pg_dump` 17 → sin desajuste de versiones.
- **Base principal:** `foodstore`, creada el 2026-10-28, **251 MB** (5 tablas, 18 índices, 3 vistas). Conteos en `baseline_u6.md`.
- **Base de restauración:** `foodstore_restore_test`, a crear en el simulacro.
- **Credenciales:** `%APPDATA%\postgresql\pgpass.conf`; los scripts usan `--no-password` y fallan si no encuentran credenciales.
- **Origen de la base:** reconstruida desde el repo (`schema.sql` → `data.sql` → `TP5/4-A/indices.sql` → `TP5/4-B/views.sql` → `TP3/Parte 1/carga_masiva.sql`). `copia_food_store` quedó intacta como respaldo previo en `backups/pre_u6.dump`.

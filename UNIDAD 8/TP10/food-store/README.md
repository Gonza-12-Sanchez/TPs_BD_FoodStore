# Food Store · Trabajo práctico 8

**Base de Datos II · UTN · 2026**

Gonzalo Sanchez · Roman Avila · Mailen Ortiz · Leo Fachinelli · Maximiliano Mendez · Gabriel D'Anna.

## Alcance

Base de la tablet y simulación de sincronización. **SIMULADO_APROBADO no es una venta ni una reserva de stock.** PostgreSQL sigue siendo la autoridad. No se necesita una app móvil ni un servidor MongoDB para ejecutar este TP: la parte documental de U7 se describe en el mapa.

Se reutiliza el esquema Food Store del equipo, ya preparado en U6 (sin la instrucción original CREATE DATABASE), en una base nueva con cuatro productos y un pedido ficticios. No se altera ninguna base anterior. Los nombres de integrantes están únicamente en la documentación; SQLite guarda el alias ficticio `operador_demo`.

## Ejecutar desde cero en Windows

Requisitos: PostgreSQL 16+ instalado (incluye initdb, pg_ctl y psql), Python 3 con SQLite 3.37+. No hace falta instalar paquetes Python.

Descomprimí el ZIP y abrí PowerShell en la carpeta `food-store`, donde está `laboratorio.py`.

```powershell
python -c "import sqlite3; print(sqlite3.sqlite_version)"
python laboratorio.py --pg-bin "C:\ruta\a\PostgreSQL\bin"
```

Reemplazá la ruta de ejemplo por la carpeta `bin` de tu instalación de PostgreSQL, la que contiene `initdb.exe`, `pg_ctl.exe` y `psql.exe`. El puerto 55439 debe estar libre; se puede cambiar con `--port`. Si `python` no está en PATH, usar `& "C:\Python314\python.exe" laboratorio.py --pg-bin "E:\PostgreSQL\bin"`. La instancia de prueba usa autenticación local trust y escucha únicamente en 127.0.0.1; no usar esta configuración en producción. El script detiene la instancia al terminar y conserva su carpeta temporal para inspección. `probar.ps1` es un envoltorio opcional del mismo lanzador.

El orden automatizado es:

1. Crear un clúster local aislado y una base nueva con prefijo `foodstore_tp8_`.
2. Ejecutar `servidor/schema_foodstore.sql`, `semilla.sql` y `snapshot.sql`.
3. Crear SQLite con `movil/schema_sqlite.sql` y activar FK en cada conexión.
4. Exportar la vista con COPY a CSV, reemplazar `snapshot_servidor` y aplicar `cargar_cache.sql` dentro de la misma transacción.
5. Ejecutar `pruebas_sqlite.sql` (incluye dos errores esperados) y los casos C2–C6 en `ejecutar.py`, usando `movil/semaforo.sql`.
6. Ejecutar el control final de PostgreSQL, integridad de SQLite y comparaciones antes/después. Los errores inesperados terminan con código distinto de cero.

Cada ejecución escribe en una carpeta nueva `ejecuciones/<fecha_hora>/`: base SQLite, CSV por caso, resultados y resumen JSON. No reemplaza la base de muestra de `movil/`. Para repetir inmediatamente, esperar un segundo o usar una salida explícita distinta.

### Con una instancia PostgreSQL de pruebas ya iniciada

```powershell
python ejecutar.py --psql "E:\PostgreSQL\bin\psql.exe" --host 127.0.0.1 --port 5432 --user postgres --database foodstore_tp8_otra_prueba --salida ejecuciones/otra_prueba
```

La base y la carpeta de salida deben ser nuevas. El usuario necesita permiso CREATE DATABASE. Se usa `-w`: si hace falta autenticación, configurá `pgpass.conf` privado o el mecanismo habitual; no incluyas credenciales en esta entrega.

## Qué se puede abrir directamente

- `docs/informe.pdf`: resolución de hasta seis páginas.
- `movil/foodstore_movil.db`: resultado real de la validación C1–C7, listo para DB Browser for SQLite.
- `movil/servidor_snapshot.csv`: última instantánea real; conserva producto 3 eliminado.
- `ejecuciones/validacion_final/resultados.txt`: evidencia de la versión final de OpenCode, incluyendo errores esperados y comparaciones del servidor. `validacion01` corresponde a la primera implementación. La revalidación del código actual con `PYTHONOPTIMIZE=1` está en `ejecuciones/revalidacion/resultados.txt`.
- `docs/kiro/`: cuatro requisitos EARS, diseño y tareas.
- `docs/bitacora_ia.md`, `docs/DUIA.md`, `docs/revision_ia.md`: trazabilidad, decisiones y complemento del punto 3.c del informe.

En DB Browser, ejecutar `PRAGMA foreign_keys=ON;` en cada conexión. Consulta sin servidor:

```sql
SELECT id,nombre,precio_centavos,stock_visto
FROM producto_cache WHERE disponible=1 AND eliminado=0;
SELECT estado,count(*) FROM cola_sync GROUP BY estado;
PRAGMA integrity_check;
PRAGMA foreign_key_check;
```

La base incluida tiene todas las solicitudes resueltas. No ejecutar `pruebas_sqlite.sql` otra vez sobre ella: los UUID fijos ya existen. Para regenerar, usar el procedimiento desde cero.

## Ruta manual del CSV

Desde `movil/`, en psql conectado a la copia:

```sql
\copy (SELECT * FROM v_snapshot_movil ORDER BY id) TO 'servidor_snapshot.csv' CSV HEADER
```

En sqlite3 sobre una base creada con el esquema (el archivo de CSV tiene que existir):

```text
.bail on
PRAGMA foreign_keys=ON;
BEGIN;
DELETE FROM snapshot_servidor;
.import --csv --skip 1 servidor_snapshot.csv snapshot_servidor
.read cargar_cache.sql
COMMIT;
.read semaforo.sql
```

Si una importación manual falla, ejecutar ROLLBACK y corregir el CSV antes de continuar. La ruta automatizada lo revierte mediante el administrador de transacciones de Python. `disponible` y `eliminado` llegan como `t/f`; no se usa CAST('t' AS INTEGER).

## Ensayo de defensa (10 minutos)

1. Minutos 0–2: mapa de los tres motores; autoridad de PostgreSQL.
2. Minutos 2–5: correr `python laboratorio.py`; explicar C2 antes y después de aceptar el precio.
3. Minutos 5–7: mostrar C4 (lápida) y C6 (UUID repetido, sin reevaluación).
4. Minutos 7–9: explicar un hallazgo de U6 y su consulta de comprobación.
5. Minuto 9–10: preguntas individuales: por qué centavos, FK por conexión, prioridad del rojo y dónde iría la idempotencia real.

Todos los integrantes deben leer los scripts y practicar; este documento no acredita un ensayo que todavía no se realizó. La plantilla oficial de DUIA y el apunte de las paradas no fueron adjuntados: se incluye una declaración propia y se siguen las reglas explícitas del PDF del TP8.

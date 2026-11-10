# AGENTS.md — BD_FoodStore / TP2_Laboratorio_Concurrencia_IA

## Repo Layout — Gotcha
- Git root is **not** `BD_FoodStore/` — it is `BD_FoodStore/TP2_Laboratorio_Concurrencia_IA/` (contains `.git/`, `schema.sql`, `data.sql`). `BD_FoodStore/` itself is an untracked wrapper folder.
- Only 3 tracked files: `schema.sql`, `data.sql`, `protocolo_seguridad.md` (currently untracked). No app code, no package manager, no CI.

## Stack
- **PostgreSQL** only, on **Windows PowerShell**. No `npm`/`docker`/`make` — all work is `psql` / `createdb` / `dropdb` / `pg_dump` / `pg_restore`.
- DB name: `food_store`. Template DB: `plantilla_food_store`. Working copy: `copia_trabajo`.

## Safety Protocol — Mandatory Order (see `protocolo_seguridad.md`)
Never touch `food_store` directly. Violating this corrupts the source-of-truth.

1. **Copy** — always work on a clone:
   ```powershell
   dropdb copia_trabajo           # if exists
   createdb -T plantilla_food_store copia_trabajo
   psql -d copia_trabajo
   ```
   Init template once: `createdb plantilla_food_store; psql -d plantilla_food_store -f schema.sql; psql -d plantilla_food_store -f data.sql`

2. **Transaction** — every write script uses `BEGIN; ... ROLLBACK;` first to inspect, then re-run with `COMMIT`:
   ```sql
   BEGIN; UPDATE producto SET precio = precio * 1.10 WHERE categoria_id = 2; SELECT * FROM producto WHERE categoria_id = 2; ROLLBACK;
   -- only if correct:
   BEGIN; UPDATE producto SET precio = precio * 1.10 WHERE categoria_id = 2; COMMIT;
   ```

3. **Backup** — before any DDL (`ALTER`/`DROP`/migration):
   ```powershell
   New-Item -ItemType Directory -Path ".\backups" -Force
   $fecha = Get-Date -Format "yyyyMMdd_HHmmss"
   pg_dump -d copia_trabajo -F c -f ".\backups\copia_trabajo_$fecha.backup"
   pg_dump -d copia_trabajo -f ".\backups\copia_trabajo_$fecha.sql"  # readable alt
   # restore if needed: dropdb copia_trabajo; createdb copia_trabajo; pg_restore -d copia_trabajo ".\backups\...\*.backup"
   ```

## Schema Source of Truth — `schema.sql:1`
- Enums: `rol` (`ADMIN`,`USUARIO`), `estado_pedido` (`PENDIENTE`,`CONFIRMADO`,`TERMINADO`,`CANCELADO`), `forma_pago` (`TARJETA`,`TRANSFERENCIA`,`EFECTIVO`).
- Tables: `categoria`, `producto` (FK `categoria_id`, CHECK `precio>=0`/`stock>=0`), `usuario` (UNIQUE `mail`), `pedido` (FK `usuario_id`), `detalle_pedido` (FKs `pedido_id` ON DELETE RESTRICT, `producto_id`, UNIQUE `(pedido_id,producto_id)`, CHECK `cantidad>0`).
- Soft-delete pattern: `eliminado BOOLEAN DEFAULT FALSE` + `created_at TIMESTAMPTZ DEFAULT now()` on every table.
- Indexes: `idx_producto_categoria`, `idx_pedido_usuario`, `idx_detalle_pedido`.
- `data.sql` inserts seed data then `UPDATE pedido SET total = (SELECT SUM(subtotal)...)` — totals are derived, not static.

## Conventions & Gotchas
- `psql`/`createdb` may not be on `PATH` in this environment — find Postgres bin (e.g. `C:\Program Files\PostgreSQL\*\bin`) and use full path or add to PATH before running commands.
- `data.sql`/`schema.sql` contain latin-1 characters (e.g. Martinez, Empanadas). If `psql` import mangles accents, set `client_encoding` to `UTF8`/`LATIN1` as needed and use `psql -d <db> -f file.sql` exactly — do not paste SQL with broken encoding.
- Backups go in `.\backups\` (create it yourself, untracked). Clean old ones: `Get-ChildItem .\backups\*.backup | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-7)} | Remove-Item`.
- Remote: `https://github.com/Gonza-12-Sanchez/TP2_Laboratorio_Concurrencia_IA.git` branch `main`.
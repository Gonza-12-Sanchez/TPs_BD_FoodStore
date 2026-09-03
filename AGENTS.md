# AGENTS.md

## Project
- PostgreSQL coursework — `Food Store` DB. No app code, no `package.json`/`requirements.txt`, no CI/lint/test. Only SQL + docs. Remote `https://github.com/Gonza-12-Sanchez/TPs_BD_FoodStore.git` (`main`, single commit `69308fc`).
- Git root is the **inner** `TPs_BD_FoodStore/TPs_BD_FoodStore/` — outer folder with same name is not tracked. Confirm with `git rev-parse --show-toplevel`.

## Layout
- `schema.sql:1` — DDL. Creates DB `copia_food_store`, 3 enums, 5 tables, 3 indexes. Single executable source for schema.
- `data.sql:1` — seed: 4 categorias, 10 productos, 5 usuarios, 5 pedidos, 9 detalle_pedido rows, then `UPDATE pedido SET total = (SELECT SUM(subtotal) ...)` to materialize totals.
- `protocolo_seguridad.md:1` — **mandatory 3-step safety protocol** for every DB change (cátedra requirement). Read it before any DML/DDL.
- `TP3/` — empty working directory for next assignment. Put TP3 deliverables there.

## Database `schema.sql:4`
- Enums: `rol` (`ADMIN`,`USUARIO`), `estado_pedido` (`PENDIENTE`,`CONFIRMADO`,`TERMINADO`,`CANCELADO`), `forma_pago` (`TARJETA`,`TRANSFERENCIA`,`EFECTIVO`).
- Tables: `categoria` -> `producto.categoria_id` -> `pedido.usuario_id` -> `detalle_pedido(pedido_id,producto_id)` with `UNIQUE(pedido_id,producto_id)` and `ON DELETE RESTRICT` on `pedido` (`schema.sql:60`).
- Conventions on every table: `BIGINT GENERATED ALWAYS AS IDENTITY PK`, `eliminado BOOLEAN NOT NULL DEFAULT FALSE` (soft delete — never hard `DELETE`), `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`, `CHECK` on `precio/stock/cantidad/subtotal/total`.
- Indexes: `idx_producto_categoria`, `idx_pedido_usuario`, `idx_detalle_pedido` (`schema.sql:69`).

## Critical Gotcha: DB Name Mismatch
- `schema.sql:2` uses `copia_food_store`; `protocolo_seguridad.md:14` uses `food_store` / `copia_trabajo`. Do not hardcode — verify target DB name with the user/task before running scripts.

## Mandatory Safety Protocol `protocolo_seguridad.md:7`
Agents must follow this order for **every** change (not optional):
1. **Copia** — Work only on a clone in DBeaver: `CREATE DATABASE copia_trabajo WITH TEMPLATE food_store;`
2. **Transaccion** — Wrap DML in `BEGIN; ... SELECT verification ... ROLLBACK;` first; only after visual verification re-run with `COMMIT;`
3. **Respaldo (DDL only)** — Before `ALTER/DROP/CREATE` run `pg_dump -U postgres -d copia_trabajo -f backup_food_store.sql` in PowerShell — `ROLLBACK` does not protect DDL.

## Tooling
- Execution is DBeaver (SQL editor) + PowerShell (`pg_dump`). `psql`/`pg_dump` are **not** on PATH in this environment (verified) — do not try to run them locally to test; propose scripts and describe DBeaver verification instead.
- No formatter/linter for SQL — keep style consistent with existing files (lowercase `create database`, uppercase `CREATE TABLE/TYPE`, Spanish comments).

## Workflow
- Keep `schema.sql` as canonical DDL — if TP3 requires changes, prefer new migration files in `TP3/` rather than mutating `schema.sql` unless the assignment says to.
- Do not commit `.sql` dumps/backups or credentials. Hashes in `data.sql` are placeholders (`hash1`) — do not use real passwords.

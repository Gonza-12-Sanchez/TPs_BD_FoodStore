# Verificación de equivalencia (Parte D)

Ejecución real sobre 120 usuarios sintéticos, 7 eliminados lógicamente.
Ambas consultas excluyen eliminados y agrupan con el mismo mes en UTC.

| Rol | Mes UTC | Real | Sintética |
|---|---|---:|---:|
| ADMIN | 2026-02-01 | 2 | 2 |
| ADMIN | 2026-04-01 | 2 | 2 |
| ADMIN | 2026-06-01 | 2 | 2 |
| USUARIO | 2026-01-01 | 19 | 19 |
| USUARIO | 2026-02-01 | 17 | 17 |
| USUARIO | 2026-03-01 | 19 | 19 |
| USUARIO | 2026-04-01 | 17 | 17 |
| USUARIO | 2026-05-01 | 18 | 18 |
| USUARIO | 2026-06-01 | 17 | 17 |

La diferencia con EXCEPT en ambos sentidos devolvió **0 filas**. La comparación
de listas ordenadas también fue idéntica. Se conservaron las 120 filas en usuario_anon
y se detectaron **0 coincidencias indebidas** de los campos identificatorios comprobados.

## Alcance de la técnica

La tabla sigue el patrón determinista de clase. Conservar el mismo id, rol y fecha exacta
permite vinculación con otras fuentes: no demuestra anonimización irreversible de una
base real. La tabla queda privada y a la IA se comparten solo agregados y el esquema.
Un grupo pequeño también puede permitir inferencias; esta demostración usa únicamente
personas ficticias. Para datos reales se deben evaluar generalización y supresión.

Nombres, apellidos, correos, teléfonos, contraseñas, hashes, tokens, respaldos y logs
identificables de FoodStore no deben enviarse a una IA sin una preparación adecuada.
Los hashes de contraseñas tampoco se comparten: permiten ataques fuera del servidor.
La copia sintética usa un literal no autenticable en lugar del hash original.

Scripts: sql/usuario_anon.sql y sql/verificar_equivalencia.sql.

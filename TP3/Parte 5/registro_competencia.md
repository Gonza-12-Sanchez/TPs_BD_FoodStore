# Parte 5 Competencia de optimización entre equipos

---
## Equipo
Nuestro Equipo
---
## Estrategia aplicada
Índice B-Tree compuesto `(categoria_id, precio ASC)` parcial (`WHERE eliminado = FALSE`) con cobertura `INCLUDE (nombre, stock)` para lograr *Index Only Scan* y suprimir el nodo *Sort*.

---

## Tiempos y Mejora
- **Tiempo antes:** 29.540 ms
- **Tiempo después:** 1.120 ms
- **Mejora:** 26.3x

<br>

# Declaración de Uso de IA (DUIA) - Parte 5

---

## Herramienta
OpenCode / Asistente IA

---

## Para qué se usó
Analizar el plan de ejecución de la consulta de competencia y diseñar el índice óptimo para reducir el tiempo de ejecución.

---

## Prompt utilizado
> Proponé el mejor índice para la consulta de competencia (filtro por categoria_id 2, rango de precio, eliminado = FALSE, ordenado por precio). Busco eliminar el nodo Sort.

---

## Qué se aceptó / se descartó y por qué
**Se aceptó la propuesta de Índice Compuesto y Parcial.**
Se aplicó la creación del índice: `CREATE INDEX idx_producto_competencia ON producto (categoria_id, precio ASC) INCLUDE (nombre, stock) WHERE eliminado = FALSE;`

**Motivos de aceptación:** 
Se aceptó porque la explicación demostró que esta estructura resuelve el filtrado inicial, evita el acceso a la tabla original (Heap) usando `INCLUDE` para traer el nombre y el stock directamente desde la RAM, y suprime por completo el costoso nodo `Sort` al aprovechar el orden natural del B-Tree.

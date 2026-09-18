# Declaración de Uso de IA (DUIA)

- **Materia:** Base de Datos II
- **Unidad:** 3 — Semana 1
- **Proyecto:** Food Store
- **Trabajo Práctico:** Punto 6 — Declaración de Uso de IA (DUIA) y bitácora
- **Fecha de elaboración:** Semana 1 (este documento se irá completando a medida que avance el proyecto)

Este documento registra el uso de herramientas de IA durante el desarrollo del
Trabajo Práctico: qué herramienta se utilizó y con qué propósito, el prompt o
spec utilizado, qué propuso la IA, qué se aceptó, qué se modificó, qué se
descartó y la justificación técnica de cada decisión.

---

## 1. Uso de Kiro y OpenCode

En el proyecto se utilizan dos herramientas de IA con roles complementarios:

- **Kiro:** se utiliza para **especificar las necesidades** antes de generar SQL.
  A partir de la consigna, se redacta en Kiro la especificación (spec) de lo que
  se necesita, expresando el objetivo, el contexto y las restricciones, sin
  generar aún el script de base de datos.
- **OpenCode:** se utiliza para **generar y revisar las propuestas**. Con la
  especificación de Kiro como punto de partida, OpenCode propone los scripts SQL
  y esos scripts se revisan de forma crítica antes de ser aceptados, verificado
  que sean consistentes con el esquema existente del proyecto.

---

## 2. Parte A — Índices

### 2.1. Especificación en Kiro

Spec registrado en Kiro:

> "Analizar una consulta frecuente sobre la tabla pedido que utiliza
> `usuario_id` como criterio de búsqueda. Proponer una estrategia de
> indexación que permita mejorar la búsqueda de pedidos asociados a un
> usuario. Tener en cuenta los índices existentes en el esquema para evitar
> propuestas redundantes."

Esta especificación cumple el propósito de definir claramente: (a) el criterio
de búsqueda involucrado (`usuario_id`), (b) el objetivo (mejorar la búsqueda de
pedidos por usuario) y (c) la restricción (evitar propuestas redundantes
verificando los índices que ya existen en el esquema).

### 2.2. Propuesta de OpenCode

A partir de la especificación, OpenCode propuso crear un nuevo índice sobre la
columna `usuario_id` de la tabla `pedido`:

```sql
CREATE INDEX idx_pedido_usuario_nuevo
ON pedido(usuario_id);
```

**Qué propuso la IA:** la creación de un índice nuevo, denominado
`idx_pedido_usuario_nuevo`, sobre la columna `usuario_id` de la tabla `pedido`.

### 2.3. Revisión de la propuesta y descarte por sobreindexación

Durante la revisión de la propuesta se comprobó que el esquema del proyecto ya
posee el índice:

```sql
idx_pedido_usuario
```

sobre la columna `usuario_id` de la tabla `pedido`.

**Qué se descartó:** la propuesta `idx_pedido_usuario_nuevo`. La propuesta se
considera **redundante** y se descarta por **sobreindexación**, ya que es
funcionalmente equivalente al índice existente `idx_pedido_usuario`.

**Justificación técnica:** un segundo índice con la misma clave (la columna
`usuario_id`) y el mismo propósito que uno ya existente no aporta un beneficio
adicional para este caso de búsqueda, porque el motor de base de datos ya puede
resolver consultas por `usuario_id` mediante `idx_pedido_usuario`. En cambio,
mantener un índice duplicado produciría costos adicionales de:
- **almacenamiento** (el índice ocupa espacio en disco), y
- **mantenimiento**, ya que debería actualizarse en cada operación de
  **INSERT**, **UPDATE** y **DELETE** sobre la tabla `pedido`, degradando el
  rendimiento de escritura sin mejorar la lectura.

**Nota:** en esta instancia no se realizaron mediciones de rendimiento sobre
este índice; el descarte se basa en la redundancia estructural frente al esquema
existente. Si en una etapa posterior se requiere evaluar el comportamiento real,
deberán realizarse y documentarse las mediciones correspondientes.

### 2.4. Decisión final — qué se aceptó, qué se modificó y qué se descartó

| Elemento | Decisión | Justificación |
| --- | --- | --- |
| Spec de Kiro (incluir en la estrategia la verificación de índices existentes) | **Aceptado** | Incorporar la restricción de evitar redundancias hizo posible detectar la duplicidad en la revisión. |
| Crear `idx_pedido_usuario_nuevo` sobre `usuario_id` | **Descartado** | Existe `idx_pedido_usuario` con la misma columna; sería sobreindexación. |
| Uso del índice existente `idx_pedido_usuario` | **Aceptado (se mantiene)** | Ya cubre el criterio de búsqueda por `usuario_id` sin costos adicionales. |
| Modificaciones sobre el script propuesto | Sin modificaciones | La propuesta no se ajustó ni se ejecutó; se descartó en su totalidad. |

---

## 3. Parte B — Vistas (pendiente de completar)

> **Estado:** la Parte B aún no fue realizada. Esta sección queda preparada para
> ser completada posteriormente. **No se afirma ni se da por comprobado
> ningún resultado de la Parte B.**

### 3.1. Verificación de equivalencia de resultados de al menos una vista

Requisito mínimo del punto: documentar la verificación de equivalencia de
resultados de al menos una vista de la Parte B.

Pendiente de registrar al realizar la Parte B:

- **Vista seleccionada:** *(completar: nombre de la vista)*
- **Consulta/expresión con la que se comparó su resultado:** *(completar)*
- **Método de verificación de equivalencia:** *(completar p. ej.: comparación de
  resultados devueltos por la vista contra la consulta base, cantidad de filas,
  valores por columna, orden, nulos, etc.)*
- **Resultado de la verificación:** *(completar: ¿resultados equivalentes?
  definir criterio de comparación utilizado)*
- **Conclusiones y decisiones tomadas a partir de la verificación:**
  *(completar)*

---

## 4. Bitácora

Registro cronológico de las decisiones tomadas durante el desarrollo del
Trabajo Práctico.

### Semana 1

- **Parte A — Índices:**
  - Se especificó en Kiro la necesidad de mejorar la búsqueda de pedidos por
    `usuario_id`.
  - OpenCode propuso `idx_pedido_usuario_nuevo` sobre `usuario_id`.
  - En la revisión se detectó que ya existe `idx_pedido_usuario`; la propuesta se
    **descartó por sobreindexación**. No se realizaron mediciones de rendimiento.
- **Parte B — Vistas:**
  - Pendiente. La verificación de equivalencia de resultados de al menos una
    vista quedará registrada en este documento al realizar la Parte B.
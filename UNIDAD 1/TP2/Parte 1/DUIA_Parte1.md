# Declaración de Uso de IA (DUIA) - Parte 1

---

## Herramienta

OpenCode (Modo Plan y Ejecución)

---

## Prompt utilizado

Necesito restricciones o triggers para la base de datos food_store que garanticen dos reglas:

1) Prohibir transiciones de estado inválidas en la tabla pedido (de TERMINADO/CANCELADO a PENDIENTE/CONFIRMADO)
2) Validar que la cantidad en detalle_pedido no supere el stock disponible en la tabla producto.

---

## Qué generó la IA

Scripts SQL para crear funciones y disparadores `BEFORE` (`triggers.sql`), junto con un archivo de pruebas transaccionales usando `SAVEPOINT` e instrucciones de consola (`tests_triggers.sql`).

---

## Qué se aceptó

La lógica central de los triggers, incluyendo:

- El uso de `IS DISTINCT FROM` para optimizar las actualizaciones de pedidos
- El bloqueo pesimista `SELECT ... FOR UPDATE` para evitar condiciones de carrera en el stock

---

## Qué se modificó/descartó

Se descartó el script de pruebas automatizadas de OpenCode (`tests_triggers.sql`) porque contenía comandos exclusivos de consola (`\echo`, `DO $$`) que generaban errores de sintaxis en el entorno gráfico de DBeaver. 

**Solución adoptada:** Validación manual.

---

## Verificación realizada

Se ejecutaron sentencias DML manuales en DBeaver, comprobando exitosamente que:

1. El motor **bloquea** la alteración de pedidos en estado `TERMINADO` (estado 4)
2. El motor **rechaza** inserciones de cantidades que superan el stock actual

---

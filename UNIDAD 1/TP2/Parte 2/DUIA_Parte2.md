# Declaración de Uso de IA (DUIA) - Parte 2

---

## Herramienta

Gemini

---

## Prompt utilizado

Explicame qué pasó en estos escenarios de concurrencia donde una sesión lee datos distintos o se queda bloqueada, y qué nivel de aislamiento lo solucionaría.

---

## Qué generó la IA

Explicaciones teóricas de las anomalías (Lectura no repetible, Lectura fantasma, Espera por bloqueo), sugerencias de niveles de aislamiento (`REPEATABLE READ`) y comandos SQL para los flujos de prueba.

---

## Qué se aceptó

Las explicaciones conceptuales de los fenómenos que se incluyeron en el informe y los scripts de configuración de aislamiento (`BEGIN TRANSACTION ISOLATION LEVEL`).

---

## Qué se modificó/descartó

Se modificó la sentencia `INSERT` del Escenario 2 (Lectura fantasma). Se descartó la versión de la IA porque intentaba forzar un `id` autogenerado y omitía las columnas `NOT NULL` de la tabla real, reemplazándola por:

```sql
INSERT INTO pedido (forma_pago, usuario_id) VALUES ('EFECTIVO', 1);
```

---

## Verificación realizada

Se reprodujeron los flujos cruzados en dos sesiones simultáneas en DBeaver sobre el esquema `copia_trabajo`. Se verificaron en el motor real:

- Los cambios de resultado
- Los bloqueos de sesión
- El error de límite de stock al ejecutar el `COMMIT` final

---

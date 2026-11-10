# Informe de Concurrencia

---

## Escenario 1: Lectura no repetible

### Cómo se reprodujo

**Sesión A:**
```sql
BEGIN;
SELECT total FROM pedido WHERE id = 1;
```

**Sesión B:**
```sql
BEGIN;
UPDATE pedido SET total = 9999 WHERE id = 1;
COMMIT;
```

**Sesión A:**
```sql
SELECT total FROM pedido WHERE id = 1;
```

### Qué se observó

En la Sesión A, la primera consulta devolvió un valor y la segunda consulta (dentro de la misma transacción) devolvió 9999, cambiando el resultado original.

### Explicación de la IA

"El motor permitió una 'Lectura no repetible' porque el nivel por defecto es READ COMMITTED. Para evitar que los datos cambien, se debe usar REPEATABLE READ, que garantiza que todas las consultas operen sobre un snapshot congelado al inicio de la transacción."

### Verificación en el motor

Se repitió el experimento iniciando la Sesión A con:

```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
```

### Conclusión

La explicación se confirmó. Al usar REPEATABLE READ, la Sesión A mantuvo el valor original en su segunda lectura, ignorando el COMMIT concurrente de la Sesión B.

---

## Escenario 2: Lectura fantasma

### Cómo se reprodujo

**Sesión A:**
```sql
BEGIN;
SELECT COUNT(*) FROM pedido WHERE estado = 'PENDIENTE';
```

**Sesión B:**
```sql
BEGIN;
INSERT INTO pedido (forma_pago, usuario_id) VALUES ('EFECTIVO', 1);
COMMIT;
```

**Sesión A:**
```sql
SELECT COUNT(*) FROM pedido WHERE estado = 'PENDIENTE';
```

### Qué se observó

El segundo `COUNT(*)` en la Sesión A devolvió un número mayor al primero, leyendo la nueva fila insertada por la Sesión B.

### Explicación de la IA

"El fenómeno es una 'Lectura Fantasma'. Ocurre porque la Sesión B insertó un nuevo registro que cumple la condición del WHERE. En la arquitectura MVCC de PostgreSQL, el nivel REPEATABLE READ es suficiente para prevenir esto porque congela el snapshot al inicio de la transacción."

### Verificación en el motor

Se repitió el experimento iniciando la Sesión A con:

```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
```

### Conclusión

La explicación se confirmó. El nivel REPEATABLE READ previno que la Sesión A contabilizara la nueva fila insertada por la Sesión B.

---

## Escenario 3: Espera por bloqueo

### Cómo se reprodujo

**Sesión A:**
```sql
BEGIN;
INSERT INTO detalle_pedido (cantidad, precio_unitario, subtotal, pedido_id, producto_id)
VALUES (30, 150.00, 4500.00, 6, 1);
```

**Sesión B:**
```sql
BEGIN;
INSERT INTO detalle_pedido (cantidad, precio_unitario, subtotal, pedido_id, producto_id)
VALUES (25, 150.00, 3750.00, 7, 1);
```

### Qué se observó

La Sesión B quedó bloqueada indefinidamente sin dar error ni avanzar. Al ejecutar `COMMIT` en la Sesión A, la Sesión B se destrabó automáticamente y el motor rechazó la inserción por falta de stock.

### Explicación de la IA

"El motor aplica un bloqueo sobre la fila del producto debido a la instrucción SELECT FOR UPDATE en el trigger. La segunda transacción debe esperar en la cola hasta que la primera libere el recurso con COMMIT o ROLLBACK."

### Verificación en el motor

Se verificó visualmente el estado de espera en DBeaver y la liberación inmediata tras el cierre de la transacción concurrente, comprobando el correcto disparo de la validación.

### Conclusión

La explicación es correcta. El bloqueo pesimista con `FOR UPDATE` serializa efectivamente las transacciones, evitando inconsistencias en el inventario.

---

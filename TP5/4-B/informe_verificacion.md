# Informe — Parte B — Verificación de equivalencia (TP5)

---

## Método de verificación

Para cada vista se ejecutó:
```sql
(SELECT * FROM vista EXCEPT SELECT ... consulta manual ...) 
UNION ALL 
(SELECT ... consulta manual ... EXCEPT SELECT * FROM vista)
```
Resultado esperado: 0 filas en ambas direcciones = equivalentes.

---

## V1 — v_productos_vigentes

**Vista:** productos vigentes con categoría
```sql
SELECT * FROM v_productos_vigentes;
```

**Consulta manual equivalente:**
```sql
SELECT p.id, p.nombre, p.precio, p.stock, p.disponible, p.categoria_id, c.nombre
FROM producto p JOIN categoria c ON c.id = p.categoria_id
WHERE p.eliminado = FALSE AND c.eliminado = FALSE AND p.disponible = TRUE;
```

**Resultado verificación:**
- VISTA EXCEPT MANUAL: 0 filas
- MANUAL EXCEPT VISTA: 0 filas
- **Conclusión: EQUIVALENTE OK — vista validada.**

---

## V2 — v_pedidos_con_usuario (vista con seguridad)

**Vista:** pedidos con datos del usuario sin exponer contraseña
```sql
SELECT * FROM v_pedidos_con_usuario;
-- Columnas: id, fecha, estado, total, forma_pago, usuario_id, usuario_nombre, usuario_apellido, usuario_mail, usuario_rol
-- NO expone: contrasena
```

**Consulta manual equivalente:**
```sql
SELECT ped.id, ped.fecha, ped.estado, ped.total, ped.forma_pago, ped.usuario_id, u.nombre, u.apellido, u.mail, u.rol
FROM pedido ped JOIN usuario u ON u.id = ped.usuario_id
WHERE ped.eliminado = FALSE AND u.eliminado = FALSE;
```

**Resultado verificación:**
- VISTA EXCEPT MANUAL: 0 filas
- MANUAL EXCEPT VISTA: 0 filas
- **Conclusión: EQUIVALENTE OK — vista validada.**

---

## V3 — v_detalle_con_producto

**Vista:** detalle de pedido con nombre del producto
```sql
SELECT * FROM v_detalle_con_producto;
```

**Consulta manual equivalente:**
```sql
SELECT dp.id, dp.pedido_id, dp.producto_id, pr.nombre, dp.cantidad, dp.precio_unitario, dp.subtotal
FROM detalle_pedido dp JOIN producto pr ON pr.id = dp.producto_id
WHERE dp.eliminado = FALSE AND pr.eliminado = FALSE;
```

**Resultado verificación:**
- VISTA EXCEPT MANUAL: 0 filas
- MANUAL EXCEPT VISTA: 0 filas
- **Conclusión: EQUIVALENTE OK — vista validada.**

---

## Resumen

Las 3 vistas fueron validadas por equivalencia exacta contra consulta manual antes de darlas por válidas. La V2 cumple el criterio de seguridad solicitado.

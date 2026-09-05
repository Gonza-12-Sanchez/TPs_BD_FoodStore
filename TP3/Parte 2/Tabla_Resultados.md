# Tabla de Resultados

## Optimización de Consultas - Análisis de Performance

---

### Consulta 1

**Descripción:** Top 50 usuarios con mayor gasto en pedidos terminados (basado en los ultimos 30 dias)

**Plan antes:**
- Nodo: Parallel Seq Scan on pedido
- Cost: 0.00..5598.71
- Tiempo real del nodo: 6.666 ms
- Tiempo real global: 47.202 ms

**Cambio aplicado:**
```sql
CREATE INDEX idx_pedido_estado_fecha ON pedido(estado, fecha);
```

**Plan después:**
- Nodo: Bitmap Heap Scan on pedido (vía Bitmap Index Scan)
- Cost: 30.44..3515.00
- Tiempo real del nodo: 0.183 ms
- Tiempo real global: 6.768 ms

**Mejora:** de 47.2 ms a 6.7 ms

---

### Consulta 2

**Descripción:** Busqueda de productos disponibles por palabra clave en la descripcion

**Plan antes:**
- Nodo: Seq Scan on producto p
- Cost: 0.00..1395.12
- Tiempo real del nodo: 0.015..38.510
- Tiempo real global: 38.587 ms

**Cambio aplicado:**
Reescritura con "to_tsvector" e indice GIN:
```sql
CREATE INDEX idx_producto_desc ON producto USING GIN (to_tsvector('spanish', descripcion));
...
```

**Plan después:**
- Nodo: Bitmap Heap Scan on producto
- Cost: 14.15..600.56
- Tiempo real del nodo: 0.018..0.018
- Tiempo real global: 0.077 ms

**Mejora:** de 38.587 ms a 0.077 ms

---

### Consulta 3

**Descripción:** Historial de unidades vendidas y recaudación total por producto

**Plan antes:**
- Nodo: Parallel Seq Scan + Sort (external merge Disk)
- Cost: 0.00..3449.53
- Tiempo real del nodo: 0.006..6.333
- Tiempo real global: 139.668 ms

**Cambio aplicado:**
```sql
CREATE INDEX idx_detalle_producto ON detalle_pedido(producto_id);
...
```

**Plan después:**
- Nodo: Index Scan using idx_detalle_producto on detalle_pedido dp
- Cost: 0.29..5960.45
- Tiempo real del nodo: 0.026..32.713
- Tiempo real global: 90.670 ms

**Mejora:** de 139.6 ms a 90.6 ms

---

### Notas

- Los tiempos están medidos en milisegundos (ms)
- El factor de mejora se calcula como: tiempo_antes / tiempo_después
- Los costos son estimaciones del planificador de PostgreSQL

-- Ejecutar dentro de la misma transacción que reemplaza snapshot_servidor.
INSERT INTO producto_cache
SELECT id,nombre,precio_centavos,stock,
       CASE disponible WHEN 't' THEN 1 ELSE 0 END,
       CASE eliminado WHEN 't' THEN 1 ELSE 0 END,fecha_copia
FROM snapshot_servidor WHERE 1
ON CONFLICT(id) DO UPDATE SET
 nombre=excluded.nombre, precio_centavos=excluded.precio_centavos,
 stock_visto=excluded.stock_visto, disponible=excluded.disponible,
 eliminado=excluded.eliminado, fecha_copia=excluded.fecha_copia;

-- Solo es correcto porque esta es una instantánea COMPLETA, no un delta.
UPDATE producto_cache SET disponible=0, eliminado=1,
 fecha_copia=COALESCE((SELECT MAX(fecha_copia) FROM snapshot_servidor),strftime('%Y-%m-%dT%H:%M:%fZ','now'))
WHERE NOT EXISTS (SELECT 1 FROM snapshot_servidor s WHERE s.id=producto_cache.id);

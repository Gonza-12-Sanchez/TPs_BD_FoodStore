-- Compatible con public.producto del Food Store del equipo. Ejecutar en copia.
CREATE OR REPLACE VIEW public.v_snapshot_movil AS
SELECT id,nombre,(precio*100)::bigint AS precio_centavos,stock,
 disponible,eliminado,
 to_char(statement_timestamp() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') AS fecha_copia
FROM public.producto;
-- No filtrar eliminado: las lápidas tienen que viajar.
-- En psql, desde movil/: 
-- \copy (SELECT * FROM v_snapshot_movil ORDER BY id) TO 'servidor_snapshot.csv' CSV HEADER

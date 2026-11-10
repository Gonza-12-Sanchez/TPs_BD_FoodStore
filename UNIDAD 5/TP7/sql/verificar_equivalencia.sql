-- Ambas consultas usan UTC y excluyen las mismas filas eliminadas.
SELECT rol,date_trunc('month',created_at AT TIME ZONE 'UTC')::date AS mes,count(*) AS cantidad
FROM public.usuario WHERE NOT eliminado GROUP BY 1,2 ORDER BY 1,2;
SELECT rol,date_trunc('month',created_at AT TIME ZONE 'UTC')::date AS mes,count(*) AS cantidad
FROM public.usuario_anon WHERE NOT eliminado GROUP BY 1,2 ORDER BY 1,2;
WITH real AS (
 SELECT rol,date_trunc('month',created_at AT TIME ZONE 'UTC')::date mes,count(*) cantidad
 FROM public.usuario WHERE NOT eliminado GROUP BY 1,2
), anon AS (
 SELECT rol,date_trunc('month',created_at AT TIME ZONE 'UTC')::date mes,count(*) cantidad
 FROM public.usuario_anon WHERE NOT eliminado GROUP BY 1,2
)
(SELECT * FROM real EXCEPT SELECT * FROM anon)
UNION ALL
(SELECT * FROM anon EXCEPT SELECT * FROM real);

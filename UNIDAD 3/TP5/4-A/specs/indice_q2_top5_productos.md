# spec: indice_q2_top5_productos
Objetivo: acelerar el reporte "top 5 productos más vendidos".
Consulta afectada: SELECT pr.id, pr.nombre, SUM(dp.cantidad) FROM detalle_pedido dp
  JOIN producto pr ON pr.id = dp.producto_id
  WHERE dp.eliminado = FALSE
  GROUP BY pr.id, pr.nombre
  ORDER BY SUM(dp.cantidad) DESC LIMIT 5;
Frecuencia: alta, reporte diario del dashboard.
Columnas candidatas: producto_id (alta selectividad), eliminado (baja selectividad).
Criterio de aceptación: el plan pasa de Seq Scan a Index/Bitmap Scan en detalle_pedido y el tiempo baja al menos un orden de magnitud.

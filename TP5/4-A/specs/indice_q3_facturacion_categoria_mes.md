# spec: indice_q3_facturacion_categoria_mes
Objetivo: acelerar el reporte "facturación por categoría y mes".
Consulta afectada: SELECT c.nombre, date_trunc('month', ped.fecha), SUM(dp.subtotal) FROM detalle_pedido dp
  JOIN pedido ped ON ped.id = dp.pedido_id AND ped.eliminado = FALSE
  JOIN producto pr ON pr.id = dp.producto_id
  JOIN categoria c ON c.id = pr.categoria_id
  WHERE dp.eliminado = FALSE
  GROUP BY c.nombre, date_trunc('month', ped.fecha);
Frecuencia: media, cierre mensual contable.
Columnas candidatas: fecha (alta selectividad), eliminado (baja selectividad).
Criterio de aceptación: el plan pasa de Seq Scan a Index/Bitmap Scan en pedido/detalle_pedido y el tiempo mejora notablemente.

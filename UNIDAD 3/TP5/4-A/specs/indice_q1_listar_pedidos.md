# spec: indice_q1_listar_pedidos
Objetivo: acelerar el listado principal de pedidos.
Consulta afectada: SELECT ped.id, u.nombre || ' ' || u.apellido FROM pedido ped
  JOIN usuario u ON u.id = ped.usuario_id
  WHERE ped.eliminado = FALSE AND u.eliminado = FALSE
  ORDER BY ped.id;
Frecuencia: muy alta, cada vez que se abre la pantalla de pedidos.
Columnas candidatas: eliminado (baja selectividad), usuario_id (JOIN).
Criterio de aceptación: el plan pasa de Seq Scan a Index/Bitmap Scan y el tiempo baja al menos 50%.

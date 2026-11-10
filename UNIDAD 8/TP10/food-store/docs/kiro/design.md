# Diseño

PostgreSQL es autoridad de catálogo, precio, stock y ventas. Se usa una base de laboratorio nueva con productos ficticios compatibles con Food Store. Una vista incluye bajas lógicas (lápidas) y una fecha común de copia. CSV transporta booleanos t/f.

SQLite usa cuatro tablas STRICT, FK activas por conexión, centavos enteros, UUID de texto y PK compuesta en ítems. snapshot_servidor es una tabla auxiliar. La importación reemplaza la instantánea dentro de una transacción y actualiza la caché conservando lápidas. Un producto ausente se marca no disponible y eliminado en la caché, sin borrar filas referenciadas.

La consulta de semáforo agrupa por solicitud: rojo tiene prioridad sobre amarillo y verde. Una solicitud sin ítems se rechaza. Solo se actualiza PENDIENTE. Se conserva la solicitud resuelta y su motivo; la aceptación de un precio crea una nueva solicitud.

Python estándar orquesta psql y sqlite3 para automatizar exportaciones y pruebas. No es una aplicación móvil ni procesa ventas. En producción, un endpoint autenticado validaría y registraría la idempotencia y la venta en una única transacción del servidor.

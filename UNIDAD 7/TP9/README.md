# Food Store · Trabajo práctico de la Unidad 7

## Reproducir las consultas

1. En una copia de desarrollo de PostgreSQL con los cinco pedidos del respaldo del TP6, ejecutar `psql -X -d <base_de_desarrollo> -f consultas_postgresql.sql`. Se puede indicar host, puerto y usuario con `-h`, `-p` y `-U`. La salida incluye las dos consultas equivalentes, el control de integridad y la exportación.
2. Con MongoDB Community Server y `mongosh` instalados, abrir una terminal en esta carpeta y ejecutar `mongosh "mongodb://127.0.0.1:27017" --quiet --file consultas_mongodb.js`. La base de laboratorio es `food_store_tp7` y el archivo `pedidos_foodstore.ejson` se generó desde el respaldo. Si se repite el script, comprueba los documentos que ya existen e inserta los que falten.
3. Con Node.js instalado, ejecutar `npm install` y `npm start` en esta carpeta. La demostración se conecta con Mongoose, lee el pedido 2 y aplica las validaciones del modelo. Si la instancia usa otra conexión, configurar `MONGODB_URI` como variable de entorno antes de ejecutar el programa.

Los filtros de MongoDB se restringen a los mismos cinco IDs de la consulta SQL. La exportación contiene solo el ID del cliente. Los importes usan BSON Decimal128. La fecha de PostgreSQL es de tipo DATE y se conserva como texto ISO sin zona horaria.

## Estado de la verificación

PostgreSQL 18.6 se ejecutó sobre una restauración aislada del respaldo de prueba `foodstore_20261028_203928_224.dump`. MongoDB cargó los cinco pedidos y ejecutó las cuatro consultas con verificación automática de IDs exitosa. Los filtros por estado y producto coinciden con PostgreSQL. La repetición de la carga insertó cero documentos adicionales. La demostración de Mongoose conectó con la base local, recuperó el pedido 2 y completó la validación del modelo sin errores. El PDF TP7_FoodStore.pdf contiene los resultados comprobados.

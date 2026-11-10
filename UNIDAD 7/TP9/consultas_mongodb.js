// Ejecutar desde tp7: mongosh --quiet --file consultas_mongodb.js
// Base exclusiva del laboratorio. Una repetición verifica los datos existentes.
const fs = require("node:fs");
const assert = require("node:assert/strict");
const pedidos = db.getSiblingDB("food_store_tp7").getCollection("pedidos");
const muestra = EJSON.parse(fs.readFileSync("pedidos_foodstore.ejson", "utf8"));
const ids = muestra.map(pedido => pedido._id);
assert.equal(new Set(ids).size, 5, "El lote debe contener cinco pedidos distintos");

const previos = pedidos.find({ _id: { $in: ids } }).toArray();
const esperados = new Map(muestra.map(pedido => [pedido._id, pedido]));
for (const pedido of previos) {
  assert.deepEqual(
    JSON.parse(EJSON.stringify(pedido)),
    JSON.parse(EJSON.stringify(esperados.get(pedido._id))),
    "El documento existente difiere del respaldo: " + pedido._id
  );
}
const existentes = new Set(previos.map(pedido => pedido._id));
const nuevos = muestra.filter(pedido => !existentes.has(pedido._id));
if (nuevos.length > 0) pedidos.insertMany(nuevos);

const lote = { _id: { $in: ids } };
const proyeccion = { _id: 1, estado: 1 };
const todos = pedidos.find(lote, proyeccion).sort({ _id: 1 }).toArray();
const porEstado = pedidos.find({ ...lote, estado: "PENDIENTE" }, proyeccion)
  .sort({ _id: 1 }).toArray();
const porProducto = pedidos.find({ ...lote, "lineas.producto_id": "4" }, proyeccion)
  .sort({ _id: 1 }).toArray();
const porTotal = pedidos.find(
  { ...lote, total: { $gt: NumberDecimal("1000.00") } },
  { _id: 1, estado: 1, total: 1 }
).sort({ _id: 1 }).toArray();

print(EJSON.stringify({
  nuevos: nuevos.length,
  documento_ejemplo: pedidos.findOne({ _id: "2" }),
  a: todos,
  b: porEstado,
  c: porProducto,
  d: porTotal,
}, null, 2));

const idsDe = filas => JSON.parse(JSON.stringify(filas.map(fila => fila._id)));
assert.deepEqual(idsDe(todos), ["1", "2", "3", "4", "5"]);
assert.deepEqual(idsDe(porEstado), ["1", "2"]); // Salida PostgreSQL del respaldo TP6.
assert.deepEqual(idsDe(porProducto), ["2"]); // Salida PostgreSQL del respaldo TP6.
assert.deepEqual(idsDe(porTotal), ["2", "4"]);
print("Verificación de IDs completada.");

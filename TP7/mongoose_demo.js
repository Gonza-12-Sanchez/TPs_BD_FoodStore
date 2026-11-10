// Ejecutar con Node.js desde tp7 luego de cargar consultas_mongodb.js.
const mongoose = require("mongoose");
const { Schema } = mongoose;

const identificador = { type: String, required: true, match: /^[1-9][0-9]*$/ };
const importe = {
  type: Schema.Types.Decimal128,
  required: true,
  validate: valor => /^[0-9]+\.[0-9]{2}$/.test(valor.toString()),
};

const clienteSchema = new Schema({ id: identificador }, { _id: false });
const lineaSchema = new Schema({
  id: identificador,
  producto_id: identificador,
  producto: { type: String, required: true },
  cantidad: {
    type: Number, required: true, min: 1, max: 2147483647, validate: Number.isInteger,
  },
  precio_unitario: importe,
  subtotal: importe,
}, { _id: false });

const pedidoSchema = new Schema({
  _id: identificador,
  fecha: { type: String, required: true, match: /^\d{4}-\d{2}-\d{2}$/ },
  estado: {
    type: String, required: true, enum: ["PENDIENTE", "CONFIRMADO", "TERMINADO", "CANCELADO"],
  },
  forma_pago: { type: String, required: true, enum: ["TARJETA", "TRANSFERENCIA", "EFECTIVO"] },
  total: importe,
  cliente: { type: clienteSchema, required: true },
  lineas: {
    type: [lineaSchema], required: true,
    validate: lineas => lineas.length > 0,
  },
}, { collection: "pedidos", versionKey: false, autoCreate: false, autoIndex: false });

const Pedido = mongoose.model("Pedido", pedidoSchema);

async function main() {
  try {
    await mongoose.connect(process.env.MONGODB_URI ?? "mongodb://127.0.0.1:27017", {
      dbName: "food_store_tp7",
      serverSelectionTimeoutMS: 5000,
    });
    const pedido = await Pedido.findById("2").orFail();
    await pedido.validate();
    console.log(JSON.stringify(pedido.toObject(), null, 2));
  } finally {
    await mongoose.disconnect();
  }
}

main().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});

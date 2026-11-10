"""TP8 reproducible: Python estándar, psql y una base NUEVA de PostgreSQL.
Nunca borra bases. Solo escribe en una base con prefijo foodstore_tp8_.
"""
import argparse
import csv
import io
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
from datetime import datetime, timezone
from uuid import uuid4

ROOT = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--psql', default='psql')
parser.add_argument('--host', default='127.0.0.1')
parser.add_argument('--port', default='5432')
parser.add_argument('--user', default='postgres')
parser.add_argument('--database', default='foodstore_tp8_' + datetime.now().strftime('%Y%m%d_%H%M%S'))
parser.add_argument('--salida', default='ejecuciones/' + datetime.now().strftime('%Y%m%d_%H%M%S'))
args = parser.parse_args()
if not re.fullmatch(r'foodstore_tp8_[a-zA-Z0-9_]+', args.database):
    parser.error('La base debe ser NUEVA y llamarse foodstore_tp8_<sufijo>.')
out = (ROOT / args.salida).resolve()
if out.exists():
    parser.error('La carpeta de salida ya existe. Elegí otra: no se sobrescribe evidencia.')
out.mkdir(parents=True)
log = []
def record(text):
    print(text, flush=True)
    log.append(text)
    (out/'resultados.txt').write_text('\n'.join(log)+'\n', encoding='utf-8')

def pg(sql=None, file=None, db=None):
    cmd = [args.psql, '-X', '-w', '-h', args.host, '-p', args.port, '-U', args.user,
           '-v','ON_ERROR_STOP=1','-A','-t','-d',db or args.database]
    cmd += ['-f',str(file)] if file else ['-c',sql]
    env = dict(os.environ, PGCLIENTENCODING='UTF8', PGCONNECT_TIMEOUT='5')
    p = subprocess.run(cmd, capture_output=True, encoding='utf-8', errors='replace', env=env, timeout=60)
    if p.returncode:
        raise RuntimeError(p.stderr)
    return p.stdout.strip()

def source(relative):
    return (ROOT/relative).read_text(encoding='utf-8-sig')

def statements(text):
    buf = ''
    for line in text.splitlines(True):
        buf += line
        if sqlite3.complete_statement(buf):
            yield buf
            buf = ''
    if buf.strip() and not all(x.strip().startswith('--') or not x.strip() for x in buf.splitlines()):
        raise ValueError('SQL incompleto')

def run_sql(text):
    # execute por sentencia permite conservar una transacción abierta en importación.
    for stmt in statements(text):
        con.execute(stmt)

def export_import(label):
    csv_text = pg('COPY (SELECT * FROM v_snapshot_movil ORDER BY id) TO STDOUT WITH CSV HEADER;') + '\n'
    file = out/('snapshot_'+label+'.csv')
    file.write_text(csv_text, encoding='utf-8', newline='')
    rows = list(csv.DictReader(io.StringIO(csv_text)))
    if not rows:
        raise ValueError('El laboratorio requiere una instantánea no vacía.')
    if len({r['fecha_copia'] for r in rows}) != 1:
        raise ValueError('El CSV debe corresponder a una única instantánea.')
    with con:
        con.execute('DELETE FROM snapshot_servidor')
        con.executemany('INSERT INTO snapshot_servidor VALUES (?,?,?,?,?,?,?)',
            [(int(r['id']),r['nombre'],int(r['precio_centavos']),int(r['stock']),r['disponible'],r['eliminado'],r['fecha_copia']) for r in rows])
        run_sql(source('movil/cargar_cache.sql'))
    record(f'{label}: exportación real PostgreSQL -> CSV -> SQLite; fecha={rows[0]["fecha_copia"]}; filas={len(rows)}')
    return file

def estado(uid):
    return con.execute('SELECT estado FROM cola_sync WHERE solicitud_uuid=?',(uid,)).fetchone()[0]

def draft(product_id, quantity=1, price=None):
    local, uid = str(uuid4()), str(uuid4())
    if price is None:
        price = con.execute('SELECT precio_centavos FROM producto_cache WHERE id=?',(product_id,)).fetchone()[0]
    with con:
        con.execute('INSERT INTO pedido_borrador VALUES (?,?,?,?)',
            (local,'operador_demo','EFECTIVO',datetime.now(timezone.utc).isoformat()))
        con.execute('INSERT INTO item_borrador VALUES (?,?,?,?)',(local,product_id,quantity,price))
        con.execute('INSERT INTO cola_sync(solicitud_uuid,id_local) VALUES (?,?)',(uid,local))
    return local,uid

control_sql = """SELECT json_build_object(
 'productos',(SELECT json_agg(row_to_json(p) ORDER BY p.id) FROM public.producto p),
 'pedidos',(SELECT json_agg(row_to_json(p) ORDER BY p.id) FROM public.pedido p),
 'detalles',(SELECT json_agg(row_to_json(d) ORDER BY d.id) FROM public.detalle_pedido d)
);"""
def check(condition, message):
    if not condition:
        raise AssertionError(message)

def baseline():
    return pg(control_sql)

def simulate(label, uid, expected):
    before = baseline()
    con.executescript(source('movil/semaforo.sql'))
    after = baseline()
    check(before == after, "La simulación modificó productos, pedidos o detalles de PostgreSQL.")
    check(estado(uid) == expected, f'{label}: estado {estado(uid)}, esperado {expected}')
    record(f'{label}: {expected}; filas de producto, pedido y detalle_pedido idénticas antes/después de simular')

def expect_error(sql, parameters, fragment):
    n = con.total_changes
    try:
        with con:
            con.execute(sql, parameters)
    except sqlite3.IntegrityError as e:
        check(fragment in str(e), str(e))
        check(con.total_changes == n, "El error de integridad dejó cambios en SQLite.")
        record(f'Error esperado: {e}; filas nuevas=0')
    else:
        raise AssertionError('Se esperaba un error de integridad')

try:
    record('Food Store TP8 / ' + datetime.now(timezone.utc).isoformat())
    record('Base aislada: '+args.database)
    record(pg('SELECT version();',db='postgres'))
    # CREATE DATABASE falla si ya existe; nunca se conecta a una base ajena.
    pg('CREATE DATABASE "'+args.database+'" TEMPLATE template0;',db='postgres')
    pg(file=ROOT/'servidor/schema_foodstore.sql')
    pg(file=ROOT/'servidor/semilla.sql')
    pg(file=ROOT/'servidor/snapshot.sql')
    con = sqlite3.connect(out/'foodstore_movil.db')
    con.execute('PRAGMA foreign_keys=ON')
    check(sqlite3.sqlite_version_info >= (3,37,0), "Se requiere SQLite 3.37 o posterior.")
    record('SQLite '+sqlite3.sqlite_version)
    con.executescript(source('movil/schema_sqlite.sql'))
    export_import('inicial')

    # Ejecuta el SQL entregado, incluidos los dos fallos controlados de C7.
    errors = 0
    for stmt in statements(source('movil/pruebas_sqlite.sql')):
        expected = re.search(r'-- EXPECT_ERROR (.+)',stmt)
        before_count = con.execute('SELECT count(*) FROM item_borrador').fetchone()[0]
        try:
            cur=con.execute(stmt)
            if expected:
                raise AssertionError('No falló: '+stmt)
            if cur.description:
                record('SQL local: '+repr(cur.fetchall()))
        except sqlite3.IntegrityError as e:
            if not expected or expected.group(1).strip() not in str(e):
                raise
            errors += 1
            check(con.execute('SELECT count(*) FROM item_borrador').fetchone()[0] == before_count, "C7: el intento inválido dejó ítems nuevos.")
            record(f'C7: {e}; filas nuevas=0')
    check(errors == 2, "C7: se esperaban dos errores de integridad.")
    check(con.execute('SELECT count(*) FROM pedido_borrador').fetchone()[0] == 1, "C1: debe quedar exactamente un borrador.")
    check(con.execute('SELECT count(*) FROM item_borrador').fetchone()[0] == 1, "C1: debe quedar exactamente un ítem.")
    check(con.execute('SELECT count(*) FROM cola_sync').fetchone()[0] == 1, "C1: debe quedar exactamente una solicitud.")
    record('C1: consulta local; COMMIT=1 borrador+1 item+1 solicitud; ROLLBACK=0 filas persistidas.')
    simulate('C1 borrador', '10000000-0000-4000-8000-000000000001','SIMULADO_APROBADO')

    local,u2 = draft(1)
    pg('UPDATE producto SET precio=precio+10 WHERE id=1;')
    export_import('C2')
    simulate('C2 precio modificado',u2,'CONFLICTO')
    # Acción explícita del cliente: aceptación simulada del precio actual.
    u2b = str(uuid4())
    with con:
        con.execute('UPDATE item_borrador SET precio_centavos_visto=(SELECT precio_centavos FROM snapshot_servidor WHERE id=1) WHERE id_local=?',(local,))
        con.execute('INSERT INTO cola_sync(solicitud_uuid,id_local) VALUES (?,?)',(u2b,local))
    simulate('C2 aceptación y UUID nuevo',u2b,'SIMULADO_APROBADO')
    check(estado(u2)=='CONFLICTO', "C2: la solicitud original debe conservar el conflicto.")

    _,u3=draft(2,5)
    pg('UPDATE producto SET stock=2 WHERE id=2;')
    export_import('C3')
    simulate('C3 pide 5 y quedan 2',u3,'RECHAZADO')

    _,u4=draft(3)
    pg('UPDATE producto SET eliminado=true WHERE id=3;')
    export_import('C4')
    simulate('C4 baja lógica',u4,'RECHAZADO')
    check(con.execute('SELECT eliminado FROM producto_cache WHERE id=3').fetchone()==(1,), "C4: debe conservarse la lápida del producto 3.")
    check(con.execute('SELECT count(*) FROM producto_cache WHERE id=3 AND eliminado=0 AND disponible=1').fetchone()==(0,), "C4: el producto 3 no debe quedar visible.")
    record('C4: fila 3 conservada (lápida), catálogo visible sin producto 3.')

    local5,u5=draft(4)
    final_csv=export_import('C5')
    simulate('C5 sin cambios',u5,'SIMULADO_APROBADO')
    before_rows = con.execute('SELECT * FROM cola_sync ORDER BY solicitud_uuid').fetchall()
    expect_error('INSERT INTO cola_sync(solicitud_uuid,id_local) VALUES (?,?)',(u5,local5),'UNIQUE')
    simulate('C6 segunda simulación',u5,'SIMULADO_APROBADO')
    check(con.execute('SELECT * FROM cola_sync ORDER BY solicitud_uuid').fetchall()==before_rows, "C6: el reintento modificó la cola de solicitudes.")
    record('C6: mismo UUID rechazado; segunda simulación cambia 0 estados y 0 motivos.')
    expect_error("UPDATE cola_sync SET estado='PENDIENTE',motivo='' WHERE solicitud_uuid=?",(u5,),'resuelta')
    expect_error('DELETE FROM producto_cache WHERE id=?',(1,),'FOREIGN KEY')

    # Pruebas adicionales aisladas: no cambian el archivo entregado.
    test=sqlite3.connect(':memory:')
    con.backup(test)
    test.execute('PRAGMA foreign_keys=ON')
    loc, uid = str(uuid4()),str(uuid4())
    with test:
        test.execute('INSERT INTO pedido_borrador VALUES (?,?,?,?)',(loc,'operador_demo','EFECTIVO','2026-11-06'))
        test.execute('INSERT INTO item_borrador VALUES (?,?,?,?)',(loc,2,5,1))
        test.execute('INSERT INTO cola_sync(solicitud_uuid,id_local) VALUES (?,?)',(uid,loc))
    test.executescript(source('movil/semaforo.sql'))
    check(test.execute('SELECT estado FROM cola_sync WHERE solicitud_uuid=?',(uid,)).fetchone()==('RECHAZADO',), "La falta de stock debe prevalecer sobre el cambio de precio.")
    record('Extra: rojo + cambio de precio => RECHAZADO (prioridad correcta).')
    uid=str(uuid4())
    with test:
        test.execute('INSERT INTO cola_sync(solicitud_uuid,id_local) VALUES (?,?)',(uid,loc))
        test.execute('DELETE FROM snapshot_servidor WHERE id=2')
    test.executescript(source('movil/semaforo.sql'))
    check(test.execute('SELECT estado FROM cola_sync WHERE solicitud_uuid=?',(uid,)).fetchone()==('RECHAZADO',), "Un producto ausente debe rechazarse.")
    record('Extra: producto ausente de la instantánea => RECHAZADO.')
    uid=str(uuid4())
    with test:
        test.execute('DELETE FROM item_borrador WHERE id_local=?',(loc,))
        test.execute('INSERT INTO cola_sync(solicitud_uuid,id_local) VALUES (?,?)',(uid,loc))
    test.executescript(source('movil/semaforo.sql'))
    check(test.execute('SELECT estado FROM cola_sync WHERE solicitud_uuid=?',(uid,)).fetchone()==('RECHAZADO',), "Un borrador vacío debe rechazarse.")
    record('Extra: borrador vacío => RECHAZADO.')
    test.close()
    check(con.execute('PRAGMA integrity_check').fetchone()==('ok',), "Falló PRAGMA integrity_check.")
    check(con.execute('PRAGMA foreign_key_check').fetchall()==[], "SQLite contiene violaciones de claves foráneas.")
    record('Integridad SQLite: ok; violaciones FK: 0.')

    # Control SQL final: tras preparar C3, el stock esperado es [50,2,20,15].
    control = pg(file=ROOT/'servidor/control_final.sql')
    record('Control final PostgreSQL:\n'+control)
    check(pg('SELECT count(*) FROM pedido;') == '1', "PostgreSQL debe conservar el pedido de la semilla.")
    check(pg('SELECT string_agg(stock::text,\',\' ORDER BY id) FROM producto;')=='50,2,20,15', "El stock final debe coincidir con la preparación del laboratorio.")
    record('TODAS LAS PRUEBAS C1-C7 PASARON. SIMULADO_APROBADO NO ES UNA VENTA.')
    (out/'servidor_snapshot.csv').write_bytes(final_csv.read_bytes())
    result = dict(database=args.database,sqlite=sqlite3.sqlite_version,casos='C1-C7 OK',
                  solicitudes=con.execute('SELECT estado,count(*) FROM cola_sync GROUP BY estado').fetchall())
    (out/'resumen.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    con.close()
except Exception as e:
    record('ERROR: '+repr(e))
    raise

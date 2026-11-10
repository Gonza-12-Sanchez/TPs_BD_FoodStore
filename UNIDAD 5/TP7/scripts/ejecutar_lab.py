"""Instala y verifica FoodStore U5 en un clúster exclusivo de desarrollo."""
import argparse
import json
import os
from pathlib import Path
import secrets
import time
import psycopg2
from psycopg2 import sql
from anonimizar_log import anonimizar

ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs'
PRIV=ROOT/'privado'
DB=os.environ.get('FS_DB','food_store_u5')
SECRETOS=PRIV/'credenciales.json'

def conectar(usuario='postgres',password=None,db=DB,app='FS_U5_CONTROL'):
    args=dict(host=os.environ.get('PGHOST','127.0.0.1'),port=os.environ.get('PGPORT','5432'),
              dbname=db,user=usuario,application_name=app,connect_timeout=5)
    if password is not None: args['password']=password
    elif os.environ.get('PGPASSWORD'): args['password']=os.environ['PGPASSWORD']
    c=psycopg2.connect(**args);c.autocommit=True;return c

def archivo(c,ruta):
    with c.cursor() as q:q.execute((ROOT/ruta).read_text(encoding='utf-8'))

def credenciales():return json.loads(SECRETOS.read_text())

def instalar():
    PRIV.mkdir(exist_ok=True,mode=0o700)
    c=conectar(db=os.environ.get('PGDATABASE','postgres'))
    with c.cursor() as q:
        q.execute('SHOW server_version_num')
        if int(q.fetchone()[0])<160000:raise RuntimeError('Se requiere PostgreSQL 16 o superior')
        q.execute('SELECT 1 FROM pg_database WHERE datname=%s',(DB,))
        if q.fetchone():raise RuntimeError('La base ya existe. No se sobrescribe ni borra.')
        q.execute("SELECT rolname FROM pg_roles WHERE rolname IN ('app_web','admin_datos','rol_soporte')")
        if q.fetchall():raise RuntimeError('Ya existen roles del TP. Utilizar otro clúster aislado.')
        q.execute(sql.SQL('CREATE DATABASE {}').format(sql.Identifier(DB)))
    c.close();c=conectar()
    with c.cursor() as q:q.execute('CREATE EXTENSION pgcrypto')
    for nombre in ('sql/base/01_esquema.sql','sql/base/02_datos_sinteticos.sql',
                   'sql/base/03_objetos.sql','sql/roles.sql'):
        archivo(c,nombre)
    claves={r:secrets.token_urlsafe(24) for r in ('app_web','admin_datos','soporte_demo','reportes_demo')}
    with c.cursor() as q:
        for rol,clave in claves.items():
            q.execute(sql.SQL('ALTER ROLE {} PASSWORD %s').format(sql.Identifier(rol)),(clave,))
        q.execute(sql.SQL('REVOKE ALL ON DATABASE {} FROM PUBLIC').format(sql.Identifier(DB)))
        q.execute(sql.SQL('GRANT CONNECT ON DATABASE {} TO app_web,admin_datos,soporte_demo,reportes_demo').format(sql.Identifier(DB)))
    SECRETOS.write_text(json.dumps(claves,indent=2));SECRETOS.chmod(0o600)
    c.close();print('Instalación terminada. Credenciales locales en privado/credenciales.json (no entregar).')

def abrir(rol,app):return conectar(rol,credenciales()[rol],app=app)

def log_actual(c):
    with c.cursor() as q:
        q.execute("SELECT current_setting('data_directory'),pg_current_logfile('stderr')")
        carpeta,archivo=q.fetchone()
    if not archivo:raise RuntimeError('Activar logging_collector y reiniciar antes de B/C')
    p=Path(carpeta)/archivo
    if not p.exists():raise RuntimeError('Ejecutar junto al servidor para leer su log, o copiar el log manualmente')
    return p

def capturar(p,inicio,destino):
    time.sleep(0.3)
    contenido=p.read_bytes()[inicio:].decode('utf-8')
    PRIV.mkdir(exist_ok=True,mode=0o700)
    raw=PRIV/(destino+'.original.txt');raw.write_text(contenido);raw.chmod(0o600)
    secretos=list(credenciales().values())+['ClaveDePruebaU5!','ClaveNuevaLaboratorio!']
    limpio=anonimizar(contenido,secretos)
    (DOC/destino).write_text(limpio,encoding='utf-8')
    return limpio

def sentencias(nombre):
    # Los scripts B/C no contienen cuerpos de funciones ni ';' en literales.
    texto='\n'.join(l for l in (ROOT/nombre).read_text().splitlines() if not l.lstrip().startswith('--'))
    return [s.strip() for s in texto.split(';') if s.strip()]

def auditoria():
    admin=conectar();p=log_actual(admin);inicio=p.stat().st_size
    c=abrir('app_web','FS_U5_B');salida=[]
    with c.cursor() as q:
        for s in sentencias('sql/auditoria_test.sql'):
            q.execute(s);salida.append({'operacion':s,'estado':q.statusmessage,
                                       'filas':q.fetchall() if q.description else []})
    c.close()
    try:
        fallida=conectar('app_web','CLAVE_MOTOR_INCORRECTA',app='FS_U5_B_FALLO');fallida.close()
        raise AssertionError('La conexión con clave incorrecta fue aceptada: revisar pg_hba.conf')
    except psycopg2.OperationalError as e:
        if 'password authentication failed' not in str(e):raise
        salida.append({'conexion_fallida':'rechazada por contraseña incorrecta'})
    capturar(p,inicio,'log_auditoria_prueba.txt')
    (DOC/'evidencias'/'resultado_auditoria.json').write_text(json.dumps(salida,indent=2,default=str))
    with admin.cursor() as q:
        q.execute("SELECT name,setting,context,pending_restart FROM pg_settings WHERE name IN "
                  "('logging_collector','log_connections','log_disconnections','log_statement',"
                  "'log_line_prefix','log_file_mode','log_timezone','log_parameter_max_length',"
                  "'log_parameter_max_length_on_error','log_min_error_statement') ORDER BY name")
        parametros=q.fetchall()
    (DOC/'evidencias'/'configuracion_efectiva.json').write_text(json.dumps(parametros,indent=2))
    admin.close();print('B: lectura, INSERT, UPDATE, ROLLBACK y conexión fallida capturados.')

def incidente():
    admin=conectar();p=log_actual(admin);inicio=p.stat().st_size
    c=abrir('soporte_demo','FS_U5_C');resultado=[]
    with c.cursor() as q:
        for n,s in enumerate(sentencias('sql/simulacro_incidente.sql'),1):
            try:
                q.execute(s);filas=q.fetchall() if q.description else []
                if n<=3:assert not filas,'Una clave incorrecta fue aceptada'
                if n==4:assert len(filas)==1,'Falló la autenticación válida'
                if n==6:raise AssertionError('El escalamiento fue aceptado. Detener y corregir permisos')
                if n==7:assert filas[0][1] is False,'La sesión se convirtió en admin_datos'
                resultado.append({'paso':n,'estado':q.statusmessage,'filas':len(filas),
                                  'datos':filas if n in (4,7) else 'No se exportan valores de filas'})
            except psycopg2.Error as e:
                if n!=6 or e.pgcode!='42501':raise
                resultado.append({'paso':n,'sqlstate':e.pgcode,'error':e.diag.message_primary})
    c.close()
    limpio=capturar(p,inicio,'log_simulacro_anonimizado.txt')
    assert limpio.count('FS_AUTH resultado=FALLO')==3
    assert limpio.count('FS_AUTH resultado=EXITO')==1
    (DOC/'evidencias'/'resultado_incidente.json').write_text(json.dumps(resultado,indent=2,default=str))
    admin.close();print('C: 3 fallos, 1 éxito, lectura masiva y escalamiento denegado (42501).')

def equivalencia():
    c=abrir('admin_datos','FS_U5_D');archivo(c,'sql/usuario_anon.sql')
    resultados=[]
    with c.cursor() as q:
        for s in sentencias('sql/verificar_equivalencia.sql'):
            q.execute(s);resultados.append(q.fetchall())
        assert resultados[0]==resultados[1] and resultados[2]==[]
        q.execute("SELECT count(*) FROM public.usuario u JOIN public.usuario_anon a USING(id) "
                  "WHERE u.nombre=a.nombre OR u.apellido=a.apellido OR u.mail=a.mail "
                  "OR a.celular IS NOT NULL OR a.contrasena<>'hash_no_valido'")
        filtraciones=q.fetchone()[0];assert filtraciones==0
        q.execute('SELECT count(*) FROM public.usuario');total=q.fetchone()[0]
        q.execute('SELECT count(*) FROM public.usuario_anon');assert q.fetchone()[0]==total
        q.execute('SELECT count(*) FROM public.usuario WHERE eliminado');eliminados=q.fetchone()[0]
    cabecera='| Rol | Mes UTC | Real | Sintética |\n|---|---|---:|---:|\n'
    tabla='\n'.join(f'| {a[0]} | {a[1]} | {a[2]} | {b[2]} |' for a,b in zip(*resultados[:2]))
    texto=f'''# Verificación de equivalencia (Parte D)

Ejecución real sobre {total} usuarios sintéticos, {eliminados} eliminados lógicamente.
Ambas consultas excluyen eliminados y agrupan con el mismo mes en UTC.

{cabecera}{tabla}

La diferencia con EXCEPT en ambos sentidos devolvió **0 filas**. La comparación
de listas ordenadas también fue idéntica. Se conservaron las {total} filas en usuario_anon
y se detectaron **{filtraciones} coincidencias indebidas** de los campos identificatorios comprobados.

## Alcance de la técnica

La tabla sigue el patrón determinista de clase. Conservar el mismo id, rol y fecha exacta
permite vinculación con otras fuentes: no demuestra anonimización irreversible de una
base real. La tabla queda privada y a la IA se comparten solo agregados y el esquema.
Un grupo pequeño también puede permitir inferencias; esta demostración usa únicamente
personas ficticias. Para datos reales se deben evaluar generalización y supresión.

Nombres, apellidos, correos, teléfonos, contraseñas, hashes, tokens, respaldos y logs
identificables de FoodStore no deben enviarse a una IA sin una preparación adecuada.
Los hashes de contraseñas tampoco se comparten: permiten ataques fuera del servidor.
La copia sintética usa un literal no autenticable en lugar del hash original.

Scripts: sql/usuario_anon.sql y sql/verificar_equivalencia.sql.
'''
    (DOC/'verificacion_equivalencia.md').write_text(texto,encoding='utf-8')
    (DOC/'evidencias'/'equivalencia.json').write_text(json.dumps(resultados,indent=2,default=str))
    c.close();print(f'D: {len(resultados[0])} grupos equivalentes; diferencia bidireccional vacía.')

def main():
    a=argparse.ArgumentParser();a.add_argument('fase',choices=['instalar','permisos','auditoria','incidente','equivalencia'])
    op=a.parse_args().fase
    if op=='permisos':
        from verificar_seguridad import verificar
        verificar()
    else:globals()[op]()

if __name__=='__main__':main()

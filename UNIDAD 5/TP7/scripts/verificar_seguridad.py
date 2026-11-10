"""Comprueba la matriz completa de permisos y operaciones con logins reales."""
import json
from pathlib import Path
import psycopg2
from ejecutar_lab import conectar,abrir,DOC

def verificar():
    c=conectar();pruebas=[];comparaciones=0
    roles=['rol_app_lectura','rol_app_escritura','rol_soporte','rol_reportes',
           'rol_auth_owner','rol_operacion_owner','app_web','soporte_demo','reportes_demo']
    grupos={'app_web':['rol_app_lectura','rol_app_escritura'],
            'soporte_demo':['rol_soporte'],'reportes_demo':['rol_reportes']}
    # Esta matriz se compara con todas las columnas de todos los objetos del TP.
    tablas={
      'rol_app_lectura':{'public.v_productos_vigentes':{'SELECT'},'public.v_categorias_vigentes':{'SELECT'}},
      'rol_app_escritura':{'public.pedido':{'SELECT'},'public.detalle_pedido':{'SELECT'}},
      'rol_soporte':{'public.v_usuarios_publico':{'SELECT'},'public.v_pedidos_resumen':{'SELECT'}},
      'rol_reportes':{'reportes.v_usuarios_por_rol_mes':{'SELECT'},'reportes.v_ventas_categoria_mes':{'SELECT'}},
      'rol_operacion_owner':{'public.producto':{'SELECT'},'public.pedido':{'SELECT','INSERT'},
                             'public.detalle_pedido':{'SELECT','INSERT'}},
    }
    columnas={
      ('rol_app_escritura','public.pedido','INSERT'):{'fecha','forma_pago','usuario_id'},
      ('rol_app_escritura','public.pedido','UPDATE'):{'estado'},
      ('rol_soporte','public.usuario','SELECT'):{'id','nombre','apellido','mail','rol','eliminado'},
      ('rol_auth_owner','public.usuario','SELECT'):{'id','mail','rol','contrasena','eliminado'},
      ('rol_auth_owner','public.usuario','UPDATE'):{'contrasena'},
      ('rol_operacion_owner','public.usuario','SELECT'):{'id','eliminado'},
      ('rol_operacion_owner','public.producto','UPDATE'):{'stock'},
      ('rol_operacion_owner','public.pedido','UPDATE'):{'total'},
    }
    with c.cursor() as q:
        q.execute("SELECT table_schema||'.'||table_name,column_name FROM information_schema.columns "
                  "WHERE table_schema IN ('public','reportes') ORDER BY 1,ordinal_position")
        objetos={}
        for tabla,col in q.fetchall():objetos.setdefault(tabla,[]).append(col)
        for rol in roles:
            sujetos=[rol]+grupos.get(rol,[])
            for tabla,cols in objetos.items():
                for permiso in ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'):
                    esperado=any(permiso in tablas.get(s,{}).get(tabla,set()) for s in sujetos)
                    q.execute('SELECT has_table_privilege(%s,%s,%s)',(rol,tabla,permiso))
                    real=q.fetchone()[0];comparaciones+=1
                    assert real==esperado,(rol,tabla,permiso,real,esperado)
                    if permiso in ('SELECT','INSERT','UPDATE','REFERENCES'):
                        for col in cols:
                            esperado_col=esperado or any(col in columnas.get((s,tabla,permiso),set()) for s in sujetos)
                            q.execute('SELECT has_column_privilege(%s,%s,%s,%s)',(rol,tabla,col,permiso))
                            real_col=q.fetchone()[0];comparaciones+=1
                            assert real_col==esperado_col,(rol,tabla,col,permiso,real_col,esperado_col)
        pruebas.append(f'Matriz de tablas y columnas: {comparaciones} comparaciones exactas, sin diferencias')
        q.execute("SELECT rolname,rolsuper,rolcreatedb,rolcreaterole,rolbypassrls FROM pg_roles "
                  "WHERE rolname=ANY(%s)",(roles+['admin_datos'],))
        assert all(not any(f[1:]) for f in q.fetchall())
        q.execute("SELECT m.rolname,g.rolname,a.admin_option FROM pg_auth_members a "
                  "JOIN pg_roles m ON m.oid=a.member JOIN pg_roles g ON g.oid=a.roleid "
                  "WHERE m.rolname=ANY(%s)",(roles+['admin_datos'],))
        membresias=q.fetchall()
        assert set(membresias)=={('app_web','rol_app_lectura',False),('app_web','rol_app_escritura',False),
                                ('soporte_demo','rol_soporte',False),('reportes_demo','rol_reportes',False)}
        pruebas.append('Atributos administrativos y membresías: coincidencia exacta con el diseño')
        rutinas={
            'public.fn_autenticar(text,text)':{'app_web','soporte_demo','rol_auth_owner'},
            'public.fn_resetear_password(bigint,text)':{'rol_soporte','soporte_demo','rol_auth_owner'},
            'public.sp_crear_pedido(bigint,public.forma_pago,jsonb)':{'rol_app_escritura','app_web','rol_operacion_owner'},
            'public.calcular_total_pedido(bigint)':{'rol_operacion_owner'},
            'public.crypt(text,text)':{'rol_auth_owner'},
        }
        for rutina,permitidos in rutinas.items():
            for rol in roles:
                q.execute('SELECT has_function_privilege(%s,%s,\'EXECUTE\')',(rol,rutina))
                assert q.fetchone()[0]==(rol in permitidos),(rol,rutina)
        q.execute("SELECT sequencename FROM pg_sequences WHERE schemaname='public'")
        for (seq,) in q.fetchall():
            for rol in roles:
                for priv in ('USAGE','SELECT','UPDATE'):
                    esperado=priv=='USAGE' and (
                        (rol in ('rol_app_escritura','app_web') and seq=='pedido_id_seq') or
                        (rol=='rol_operacion_owner' and seq in ('pedido_id_seq','detalle_pedido_id_seq')))
                    q.execute('SELECT has_sequence_privilege(%s,%s,%s)',(rol,'public.'+seq,priv))
                    assert q.fetchone()[0]==esperado,(rol,seq,priv)
        pruebas.append('Rutinas y secuencias: permisos efectivos exactos para los nueve roles comprobados')
        q.execute('BEGIN');q.execute('SET LOCAL ROLE admin_datos')
        q.execute('CREATE TABLE public._prueba_futura_privada(id integer)')
        q.execute('CREATE TABLE reportes._prueba_futura_agregada(cantidad integer)')
        q.execute('CREATE FUNCTION public._prueba_futura_funcion() RETURNS int LANGUAGE sql AS $$ SELECT 1 $$')
        for rol in roles:
            q.execute("SELECT has_table_privilege(%s,'public._prueba_futura_privada','SELECT'),"
                      "has_table_privilege(%s,'reportes._prueba_futura_agregada','SELECT'),"
                      "has_function_privilege(%s,'public._prueba_futura_funcion()','EXECUTE')",(rol,rol,rol))
            assert q.fetchone()==(False,rol in ('rol_reportes','reportes_demo'),False),rol
        q.execute('ROLLBACK');pruebas.append('Privilegios futuros: public privado, reportes legible y función privada; prueba revertida')
    c.close()

    def exito(rol,nombre,consulta,validar=lambda filas:True,param=None):
        conn=abrir(rol,'FS_U5_VERIFICACION')
        try:
            with conn.cursor() as q:
                q.execute('BEGIN');q.execute(consulta,param)
                filas=q.fetchall() if q.description else []
                assert validar(filas),(nombre,filas)
                q.execute('ROLLBACK')
            pruebas.append(nombre+': OK')
        finally:conn.close()

    def denegado(rol,nombre,consulta,codigo='42501',param=None):
        conn=abrir(rol,'FS_U5_VERIFICACION')
        try:
            with conn.cursor() as q:
                q.execute('BEGIN')
                try:q.execute(consulta,param)
                except psycopg2.Error as e:
                    assert e.pgcode==codigo,(nombre,e.pgcode,e.diag.message_primary)
                else:raise AssertionError(nombre+': se aceptó una operación prohibida')
                q.execute('ROLLBACK')
            pruebas.append(nombre+': rechazado con '+codigo)
        finally:conn.close()

    exito('app_web','Catálogo accesible','SELECT id FROM public.v_productos_vigentes',lambda f:len(f)==12)
    exito('app_web','Autenticación válida',"SELECT * FROM public.fn_autenticar(%s,%s)",
          lambda f:len(f)==1,('persona1@laboratorio.test','ClaveDePruebaU5!'))
    exito('app_web','SQLi tratado como dato',"SELECT * FROM public.fn_autenticar(%s,%s)",
          lambda f:len(f)==0,("' OR '1'='1' --",'ClaveDePruebaU5!'))
    exito('app_web','Cuenta eliminada no autentica',"SELECT * FROM public.fn_autenticar(%s,%s)",
          lambda f:len(f)==0,('persona17@laboratorio.test','ClaveDePruebaU5!'))
    denegado('app_web','Hash privado','SELECT contrasena FROM public.usuario')
    denegado('soporte_demo','SELECT estrella de usuario privado','SELECT * FROM public.usuario')
    denegado('soporte_demo','Celular privado','SELECT celular FROM public.usuario')
    exito('soporte_demo','Columnas de soporte accesibles','SELECT id,nombre,mail FROM public.usuario WHERE NOT eliminado',lambda f:len(f)==113)
    denegado('soporte_demo','Reseteo de ADMIN impedido',"SELECT public.fn_resetear_password(20,%s)",param=('ClaveNuevaLaboratorio!',))
    denegado('soporte_demo','Clave vacía impedida',"SELECT public.fn_resetear_password(1,'')",'22023')
    denegado('soporte_demo','Reseteo de eliminado impedido',"SELECT public.fn_resetear_password(17,%s)",param=('ClaveNuevaLaboratorio!',))
    # Dos llamadas dentro de la misma transacción para verificar efecto y luego revertirlo.
    conn=abrir('soporte_demo','FS_U5_VERIFICACION')
    with conn.cursor() as q:
        q.execute('BEGIN');q.execute('SELECT public.fn_resetear_password(1,%s)',('ClaveNuevaLaboratorio!',))
        q.execute('SELECT * FROM public.fn_autenticar(%s,%s)',('persona1@laboratorio.test','ClaveNuevaLaboratorio!'))
        assert len(q.fetchall())==1
        q.execute('ROLLBACK')
    conn.close();pruebas.append('Reseteo de USUARIO válido comprobado y revertido')
    denegado('app_web','Edición directa de total impedida','UPDATE public.pedido SET total=1 WHERE id=1')
    denegado('app_web','Cambio de dueño del pedido impedido','UPDATE public.pedido SET usuario_id=2 WHERE id=1')
    denegado('app_web','Edición directa de stock impedida','UPDATE public.producto SET stock=0 WHERE id=1')
    denegado('app_web','DELETE impedido','DELETE FROM public.pedido WHERE id=-1')
    denegado('app_web','TRUNCATE impedido','TRUNCATE public.detalle_pedido')
    denegado('app_web','DDL impedido','CREATE TABLE public.intrusa(id integer)')
    denegado('soporte_demo','Escalamiento impedido','GRANT admin_datos TO rol_soporte')
    denegado('soporte_demo','SET ROLE admin impedido','SET ROLE admin_datos')
    denegado('reportes_demo','Usuarios inaccesibles para reportes','SELECT id FROM public.usuario')
    exito('reportes_demo','Reporte agregado accesible','SELECT * FROM reportes.v_usuarios_por_rol_mes',lambda f:len(f)==9)
    # Verifica que el endurecimiento de permisos no rompa el flujo heredado de compra.
    conn=abrir('app_web','FS_U5_VERIFICACION')
    with conn.cursor() as q:
        q.execute('BEGIN')
        q.execute("CALL public.sp_crear_pedido(1,'EFECTIVO','[{\"producto_id\":1,\"cantidad\":2}]'::jsonb)")
        q.execute("SELECT total FROM public.pedido WHERE id=currval('public.pedido_id_seq')")
        assert q.fetchone()[0]==220
        q.execute('ROLLBACK')
    conn.close();pruebas.append('Compra completa con total calculado de 220, sin privilegios directos de inventario; revertida')
    (DOC/'evidencias'/'verificacion_seguridad.json').write_text(json.dumps({
        'comparaciones_matriz':comparaciones,'comprobaciones':pruebas},indent=2,ensure_ascii=False))
    (DOC/'verificacion_permisos.md').write_text('# Verificación técnica de permisos\n\n'+
        '\n'.join('- '+p for p in pruebas)+'\n\nCatálogo completo: evidencias/permisos_catalogo.txt.\n'+
        'Las pruebas automatizadas y sus resultados se conservan en evidencias/verificacion_seguridad.json.\n',encoding='utf-8')
    print(f'A: {comparaciones} comparaciones de matriz y {len(pruebas)} comprobaciones aprobadas.')

if __name__=='__main__':verificar()

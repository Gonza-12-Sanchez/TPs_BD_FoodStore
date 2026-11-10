"""Arranca una instancia descartable en localhost, prueba y la detiene."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile

sys.stdout.reconfigure(encoding='utf-8',errors='replace')
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--pg-bin',default=r'E:\PostgreSQL\bin')
p.add_argument('--port',type=int,default=55439)
a=p.parse_args()
if not 1 <= a.port <= 65535:
    p.error('El puerto debe estar entre 1 y 65535.')
root=Path(__file__).resolve().parent
bin=Path(a.pg_bin)
if not (bin/'initdb.exe').is_file():
    p.error('Indicá --pg-bin con la carpeta bin de PostgreSQL.')
lab=Path(tempfile.mkdtemp(prefix='foodstore_tp8_'))
data=lab/'pg'
env=dict(os.environ,PYTHONIOENCODING='utf-8')
def run(cmd,name,utf8=False):
    # Archivos, no PIPE: el servidor puede heredar handles en Windows.
    stdout=lab/(name+'.stdout.log')
    stderr=lab/(name+'.stderr.log')
    with stdout.open('wb') as so, stderr.open('wb') as se:
        result=subprocess.run([str(x) for x in cmd],stdout=so,stderr=se,env=env)
    encoding='utf-8' if utf8 else 'cp1252'
    print(stdout.read_bytes().decode(encoding,errors='replace'),flush=True)
    if result.returncode:
        raise RuntimeError(name+': '+stderr.read_bytes().decode(encoding,errors='replace'))
start_attempted=False
try:
    run([bin/'initdb.exe','-D',data,'-U','postgres','-A','trust','--encoding=UTF8','--no-locale'],'initdb')
    start_attempted=True
    run([bin/'pg_ctl.exe','-D',data,'-l',lab/'server.log','-o',f'-p {a.port} -h 127.0.0.1','-t','20','-w','start'],'inicio')
    run([sys.executable,root/'ejecutar.py','--psql',bin/'psql.exe','--port',a.port],'pruebas',True)
finally:
    if start_attempted:
        status = subprocess.run([str(bin/'pg_ctl.exe'),'-D',str(data),'status'],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
        if status.returncode == 0:
            run([bin/'pg_ctl.exe','-D',data,'-m','fast','-t','20','-w','stop'],'cierre')
    print('Laboratorio conservado en '+str(lab))

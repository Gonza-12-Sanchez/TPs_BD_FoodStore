# Reproducción del laboratorio en Windows

Ejecutar los comandos desde la raíz del proyecto.


Se necesita PostgreSQL 16 o superior y Python. DBeaver puede servir para inspeccionar la base, pero la configuración y los logs pertenecen al servidor PostgreSQL.

El siguiente procedimiento crea **otro clúster**, sin tocar FoodStore ni los roles de una instancia existente. Los nombres de rol tienen alcance de clúster, por eso una base adicional en un servidor compartido no basta para aislar este TP.

Abrir PowerShell en esta carpeta. Ajustar la ruta de PostgreSQL a la instalación disponible:

```powershell
$env:Path = "C:\Program Files\PostgreSQL\16\bin;" + $env:Path
$clusterU5 = Join-Path $env:LOCALAPPDATA "foodstore-u5-lab"
initdb -D $clusterU5 -U postgres --auth=scram-sha-256 --pwprompt --encoding=UTF8
pg_ctl -D $clusterU5 -l "$clusterU5\inicio.log" -o "-p 55435 -h 127.0.0.1" -w start
$env:PGHOST = "127.0.0.1"
$env:PGPORT = "55435"
$env:PGPASSWORD = Read-Host "Clave local de postgres definida en initdb"
py -m pip install -r requirements.txt
py scripts/ejecutar_lab.py instalar
```

No ejecutar initdb sobre una carpeta ya utilizada. El instalador se detiene si la base o los roles principales ya existen y no los sobrescribe. El clúster debe ser exclusivo y accesible solo en el equipo local.

El instalador crea esquema, 120 usuarios ficticios, 20 pedidos, lógica heredada y nuevos roles/funciones. Genera claves aleatorias en `privado/credenciales.json`, que queda fuera de Git y de la entrega. La contraseña de negocio de los ejemplos SQL es ficticia y se usa exclusivamente para la práctica.

Luego activar auditoría en el clúster nuevo:

```powershell
Copy-Item config/auditoria.conf "$clusterU5\auditoria.conf"
Add-Content "$clusterU5\postgresql.conf" "`ninclude = 'auditoria.conf'"
pg_ctl -D $clusterU5 -m fast -w restart
py scripts/ejecutar_lab.py permisos
py scripts/ejecutar_lab.py auditoria
py scripts/ejecutar_lab.py incidente
py scripts/ejecutar_lab.py equivalencia
psql -X -U postgres -d food_store_u5 -f sql/verificar_permisos.sql -o docs/evidencias/permisos_catalogo.txt
```

La configuración de auditoría se activa **después** de crear las claves para no capturarlas como literales en la instalación. El archivo de log debe poder leerse desde el mismo equipo que ejecuta Python. Si el servidor está en otro equipo, copiar los fragmentos de forma controlada y aplicar la sanitización antes de compartirlos.

Los programas regeneran evidencias con fechas, sesiones y conteos de la nueva ejecución. Los documentos narrativos que mencionan sesiones concretas corresponden a la corrida original y deben actualizarse si se reemplazan los logs.

Al terminar:

```powershell
psql -X -U postgres -d food_store_u5 -c "ALTER SYSTEM SET log_statement = 'mod'"
psql -X -U postgres -d food_store_u5 -c "SELECT pg_reload_conf()"
pg_ctl -D $clusterU5 -m fast -w stop
Remove-Item Env:PGPASSWORD
```

En Linux se puede usar el mismo procedimiento con las rutas y variables de shell correspondientes, ejecutando initdb y el servidor con un usuario sin privilegios de sistema.


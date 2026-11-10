param([string]$PgBin='E:\PostgreSQL\bin', [int]$Port=55439, [string]$PythonExe='python')
$ErrorActionPreference='Stop'
& $PythonExe (Join-Path $PSScriptRoot 'laboratorio.py') --pg-bin $PgBin --port $Port
exit $LASTEXITCODE

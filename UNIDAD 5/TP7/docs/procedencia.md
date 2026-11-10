# Procedencia y alcance de la entrega

## Código reutilizado

- TPI-BD: https://github.com/Gonza-12-Sanchez/TPI-BD, commit `6bd14a73b88f67bed54835d0feab26cd7c051eba`.
- `sql/base/01_esquema.sql` reproduce `04_schema_ddl_e_indices.sql`.
- `sql/base/03_objetos.sql` reproduce `06_07_objetos_vistas_triggers_sp.sql`.
- Repositorio complementario revisado: https://github.com/Gonza-12-Sanchez/TPs_BD_FoodStore, commit `689107d048e6fe591724911003fbe9c12d8182e2`.

Los datos de usuario de ejemplo se sustituyen por valores ficticios del dominio `.test`. No se importa una base real. Los archivos de base se mantienen como referencia y la adaptación de permisos va en scripts posteriores.

## Material de cátedra consultado

- Trabajo Practico Unidad 5.pdf, siete páginas.
- BD2_U5_Clase1_DBA_Roles_Permisos_Auditoria.pdf.
- U5-Clase1.Complemento.pdf.
- U5-Clase2_Complemento.pdf. La copia terminada en (1) es idéntica.
- Gestión de Identidades, Permisos Granulares y Jerarquías de Roles en PostgreSQL.pdf y PPTX homónimo.
- Acceso_en_PostgreSQL.pptx fue inspeccionado como archivo, pero sus láminas no aportaban texto extraíble al análisis.

El enlace de NotebookLM no fue accesible con la herramienta de consulta. No se atribuye información a su contenido.

## Herramientas

ChatGPT para asistencia en la implementación, revisión y documentación; PostgreSQL 16.15 para ejecución de pruebas; Git para el historial progresivo. La bitácora registra esta modalidad de trabajo y las verificaciones realizadas.

# Food Store: Trabajo Práctico Unidad 5

**Base de Datos II · UTN Mendoza · 2026**  
**Entrega: Román Ávila y equipo**

Administración y seguridad de FoodStore mediante roles de mínimo privilegio,
auditoría de operaciones, simulación de incidentes y protección de datos.
El laboratorio se ejecutó en PostgreSQL 16.15 con datos completamente ficticios.

## Organización de la entrega

| Parte | Implementación | Informe y evidencia |
|---|---|---|
| A. Roles y permisos | sql/roles.sql | docs/kiro_roles_spec/, docs/verificacion_permisos.md y docs/evidencias/permisos_catalogo.txt |
| B. Auditoría | config/auditoria.conf y sql/auditoria_test.sql | docs/informe_auditoria.md y docs/log_auditoria_prueba.txt |
| C. Incidente | sql/simulacro_incidente.sql | docs/informe_incidente.md, docs/respuesta_ia_incidente.md y docs/log_simulacro_anonimizado.txt |
| D. Datos personales | sql/usuario_anon.sql y sql/verificar_equivalencia.sql | docs/verificacion_equivalencia.md y docs/evidencias/equivalencia.json |
| E. Uso de IA | BITACORA.md | Historial Git y docs/procedencia.md |

## Resultados


| Prueba | Resultado |
|---|---|
| Matriz de acceso sobre tablas y columnas | 4.194 comparaciones, sin diferencias. |
| Comprobaciones resumidas de seguridad y funcionamiento | 27 aprobadas. |
| Conexión del motor con clave incorrecta | Rechazada, 28P01. |
| Intentos de fn_autenticar en el simulacro | Tres fallos y un éxito. |
| Lectura amplia autorizada para soporte | 113 usuarios vigentes, sin hashes ni celulares. |
| Intento de otorgar admin_datos a rol_soporte | Rechazado, 42501. |
| Comparación de agregados reales/sintéticos del laboratorio | Nueve grupos iguales y EXCEPT bidireccional vacío. |
| Compra mediante procedimiento | Total 220 calculado correctamente; transacción de prueba revertida. |

Aquí «real» en la comparación identifica la tabla fuente `usuario`; todas sus personas son ficticias.

## Ejecución y verificación

La guía completa está en **docs/ejecucion_windows.md**. Se requiere PostgreSQL 16+
y Python con las dependencias de requirements.txt. La instalación se realiza en
un clúster de laboratorio separado para aislar los roles y los datos.

Los programas de scripts/ permiten instalar la base, verificar permisos, ejecutar
el simulacro, capturar logs y comparar agregados. Las pruebas DML se revierten;
la instalación y la copia sintética persisten como parte del laboratorio.

El repositorio incluye las evidencias obtenidas. Una nueva ejecución genera
fechas y sesiones diferentes, por lo que también deben actualizarse sus referencias
en los informes.

## Criterios de seguridad

- La aplicación consulta el catálogo y opera pedidos con permisos acotados.
- Soporte accede a columnas autorizadas y no puede resetear cuentas ADMIN.
- Las contraseñas, los celulares y la escritura directa de inventario quedan restringidos.
- Los objetos futuros de public permanecen privados; solo reportes recibe lectura automática.
- El log compartido está sanitizado y el archivo original queda fuera de la entrega.
- usuario_anon mantiene id y fecha para demostrar equivalencia; no acredita anonimización irreversible de personas reales.
- El alcance no incluye RLS ni un sistema completo de autenticación de producción.

## Trazabilidad

BITACORA.md documenta la asistencia de IA y la revisión general comunicada por el
equipo. Los scripts base y las fuentes se identifican en docs/procedencia.md y
docs/fuentes.md. El historial conserva el avance por partes:

```bash
git log --oneline --reverse
```

El archivo comprimido incluye el historial Git. Las credenciales generadas, los
logs originales y el directorio del servidor quedan excluidos.

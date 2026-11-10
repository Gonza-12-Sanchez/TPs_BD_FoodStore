# Food Store móvil — requisitos EARS

Redactados antes de implementar esta solución. Datos ficticios; solo simulación.

- REQ-01: WHEN el catálogo ya está copiado y no existe conectividad, THE SYSTEM SHALL permitir consultar los productos disponibles y guardar un borrador con sus ítems y solicitud en una sola transacción. Prueba: C1 y COMMIT/ROLLBACK de consigna 1.c.
- REQ-02: WHEN una solicitud pendiente contiene un producto ausente, eliminado, no disponible o con stock insuficiente, THE SYSTEM SHALL marcarla RECHAZADO, con prioridad sobre cualquier cambio de precio. Pruebas: C3 y C4.
- REQ-03: WHEN no hay causas de rechazo y cambia algún precio, THE SYSTEM SHALL marcar CONFLICTO; WHEN el cliente acepta explícitamente el nuevo precio, THE SYSTEM SHALL crear una solicitud nueva y conservar la anterior. Prueba: C2.
- REQ-04: WHEN todos los ítems coinciden, THE SYSTEM SHALL marcar SIMULADO_APROBADO sin confirmar ventas ni modificar PostgreSQL, impedir UUID duplicados y no reevaluar solicitudes resueltas. Pruebas: C5 y C6; C7 verifica integridad de entrada.

La aceptación del cliente debe ser explícita; en la prueba C2 se simula como una acción separada.

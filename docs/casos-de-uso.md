# Casos de uso del grupo → qué implementa esta app

> Fuente: especificaciones del Drive grupal (Entrega 1). Alcance de la Entrega 2:
> **todo el lado usuario**, sin panel de administración.

| CU | Nombre | Autor/a | ¿En la app? | Pantallas (Figma) | API |
|---|---|---|---|---|---|
| 01 | Iniciar sesión | Noemí Acosta | ✅ | Login (MD/MN) + errores de campos vacíos | Firebase |
| 02 | Cerrar sesión | Néstor Arakaki | ✅ | Avatar → modal, Mi perfil | Firebase + `DELETE /usuarios/me/dispositivos/{token}` |
| 03 | Registrarse | Gonzalo Gil | ✅ | Registro + errores | `POST /usuarios` |
| 04 | Cambiar contraseña | Álvaro Arizu | ✅ (sin spec en el Drive) | Fila "Seguridad" del perfil | Firebase |
| 05 | Consultar perfil | Lucas Berazategui | ✅ | Mi perfil (MD/MN), tarjeta del avatar | `GET /usuarios/me` |
| 06 | Editar perfil | Nicolás Colli | ✅ | Mi perfil – editar | `PUT /usuarios/me` |
| 07 | Dar cuenta de baja | Helena Cusworth | ✅ (falta la spec en la descarga) | Info eliminar cuenta, Procesando, calificación, Gracias | `DELETE /usuarios/me` |
| 08 | Historial de reservas | Ramiro D'Agnone | ✅ | Mis reservas – Próximas / Historial / vacías | `GET /reservas?vista=` |
| 09 | Reservar cancha | Martín Gaser | ✅ | Confirmar reserva, Reserva confirmada | `POST /reservas` |
| 10 | Cancelar reserva | Jerónimo Zarlenga | ✅ | ¿Querés cancelar?, confirmación, errores | `DELETE /reservas/{id}` |
| 11 | Modificar reserva | Sofía Granero | ❌ (el TP no lo pide: se cancela y se reserva de nuevo) | — | — |
| **12** | **Consultar horarios disponibles** | **Martiniano Hereñu** | ✅ | Horarios (cancha, fecha, duración), estado vacío, errores | `GET /espacios/{id}/disponibilidad` |
| 13 | Consultar canchas | Matías La Giglia | ✅ (vía sedes + filtro) | — | `GET /espacios` |
| 14 | Historial global (admin) | Francisco Luciano | ❌ admin | — | — |
| 15 | Anular reserva (admin) | Sebastián Amaray | ❌ admin | — | — |
| 16 | Consultar sedes | Gonzalo Mazzeo | ✅ | Todas las sedes, Sede X | `GET /sedes`, `GET /espacios?sede_id=` |
| 17–19 | Alta / edición / baja de sede | Medrano, Navarro, Menapace | ❌ admin (seed) | — | — |
| 20 | Filtrar espacios deportivos | Nahuel Mosse | ✅ (falta la spec en la descarga) | Chips de deporte y tipo en Sede / Home | `GET /espacios?deporte=&tipo=` |
| 21–23 | Alta / edición / baja de espacio | Quiñones, Silva, Spagnoli | ❌ admin (seed) | — | — |
| 24 | Recibir notificación | Nahuel Mlakar | ✅ recordatorio 24 h / 1 h + aviso de cancelación | Push, tarjeta "Reservas próximas" en Home, detalle | `POST /usuarios/me/dispositivos`, cron |

## Decisiones que se apartan de alguna spec (para explicar en la defensa)

- **Login sin endpoint propio** (CU-01 menciona `POST /auth/login`): se usa Firebase
  Authentication como enseña el módulo 9; la contraseña nunca pasa por nuestra API.
- **Precio informativo:** se muestra el precio y el total, pero no hay pagos.
- **CU-24.2 (cancelación forzosa por la sede)** no aplica: sin panel de admin no hay
  quien anule reservas.

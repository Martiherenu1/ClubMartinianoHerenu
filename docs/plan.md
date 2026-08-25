# Plan de desarrollo — ClubMartinianoHerenu

Plan por **hitos** (sin fechas todavía). Cuando confirmes las fechas de Entrega 1
y Entrega 2, lo convertimos en cronograma.

## Hito 0 — Setup (base)
- [ ] Crear repo GitHub `ClubMartinianoHerenu` y primer commit con esta estructura.
- [ ] Crear proyecto en Firebase (Authentication con email/password).
- [ ] Confirmar acceso a Render.

## Hito 1 — ENTREGA 1: Diseño (Figma)
- [ ] Definir el flujo de navegación (mapa de pantallas).
- [ ] Pantallas mínimas:
  - Splash / login / registro / recuperar contraseña
  - Home
  - Listado de sedes → detalle de sede
  - Listado / filtro de espacios por tipo
  - Disponibilidad y crear reserva
  - Mis reservas (activas) e historial
  - Perfil (ver/editar, cerrar sesión)
- [ ] Prototipo navegable (links entre pantallas).
- [ ] Documentación para Blackboard.

## Hito 2 — Backend (FastAPI) local
- [ ] Esqueleto FastAPI + estructura de carpetas.
- [ ] Modelos SQLAlchemy (usuario, sede, espacio, reserva) + migraciones Alembic.
- [ ] PostgreSQL local corriendo.
- [ ] Verificación de token de Firebase (dependencia `get_current_user`).
- [ ] Endpoints: perfil, sedes, espacios, disponibilidad, reservas (crear/listar/cancelar).
- [ ] Validaciones de negocio (horas completas, futuro, dentro de horario, solapamiento).
- [ ] Script de seed (sedes + espacios).
- [ ] Swagger revisado.

## Hito 3 — App Flutter
- [ ] Proyecto Flutter + estructura + gestión de estado.
- [ ] Integrar Firebase Auth (login/registro/reset).
- [ ] Cliente HTTP hacia la API (con Bearer token).
- [ ] Pantallas según diseño de Figma.
- [ ] Manejo de errores (sin conexión, server caído, login, duplicado, horario ocupado).
- [ ] Ícono de la app.

## Hito 4 — Deploy (nube)
- [ ] PostgreSQL en Render.
- [ ] API FastAPI en Render (variables de entorno + credenciales Firebase).
- [ ] App apuntando a la URL de producción.
- [ ] README de backend y de app.

## Hito 5 — ENTREGA 2: Cierre
- [ ] Demo en emulador funcionando end-to-end.
- [ ] Modelo de datos documentado (ya en `modelo-datos.md`).
- [ ] ZIP backend + ZIP app a Blackboard.
- [ ] Repaso para defensa individual.

## (Reposo) — Notificaciones push
- [ ] FCM en Firebase + integración app + trigger de "reserva próxima" en backend.
  Se retoma cuando lo definamos.

---

### Sugerencia de orden
Entrega 1 (Figma) primero porque es la que define la app visualmente y se defiende
grupal. En paralelo se puede ir armando el **Hito 2 (backend)** y el **modelo de
datos**, que no dependen del diseño visual. Así llegás a la Entrega 2 con el backend
ya andando.

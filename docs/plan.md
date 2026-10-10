# Plan de desarrollo — Entrega 2

> Versión 2 (2026-10-10). Entrega: **antes del 03/11/2026** (ZIPs a Blackboard
> antes de la exposición). Quedan ~3 semanas, así que el plan deja colchón al final.

## Forma de trabajo con Git (módulo 8)

- **GitHub Flow:** `main` siempre funciona. Cada funcionalidad se hace en una rama
  corta (`feat/...`, `fix/...`, `docs/...`), se abre un **Pull Request** hacia
  `main`, se revisa y se mergea.
- **Commits chicos y descriptivos**, en español, varios por PR. El historial se evalúa.
- **Versiones con tags SemVer** al cerrar cada fase (`v0.1.0` … `v1.0.0`), con su Release
  en GitHub.

## Cronograma

| Fase | Fechas | Qué se hace | Cierre |
|---|---|---|---|
| 0. Preparación | 10–12/10 | Docs del plan (este PR). Instalar Flutter SDK, Android Studio y emulador. Instalar `gh` (GitHub CLI). Revisar el proyecto de Firebase. | `v0.1.0` |
| 1. Backend | 12–17/10 | Modelos + migraciones, seed, auth con Firebase, catálogo, disponibilidad (CU-12), reservas, usuarios, errores, tests. | `v0.2.0` |
| 2. Deploy temprano | 18–19/10 | PostgreSQL + API en Render, secretos, seed en producción. Swagger online. | `v0.3.0` |
| 3. App Flutter | 18–28/10 | Proyecto, tema y componentes del Figma, auth, home, sedes, horarios, reservar, mis reservas, perfil, errores, ícono. | `v0.4.0`–`v0.6.0` |
| 4. Notificaciones | 27–30/10 | FCM en la app, registro de token, recordatorios con cron, aviso de cancelación, tocar → detalle. | `v0.7.0` |
| 5. Cierre | 31/10–02/11 | README de backend y app, revisión de Swagger, prueba completa en emulador, ZIPs, guía de defensa. | `v1.0.0` |

> Se despliega **antes** de terminar la app para que, cuando la app esté lista, ya
> apunte a la nube y no haya sorpresas al final.
>
> ⚠️ La base gratuita de Render vence a los 30 días de creada: se crea el 18/10 para
> que dure hasta la defensa.

## Fase 1 — Backend (PRs previstos)

1. `feat/modelos`: modelos SQLAlchemy + primera migración Alembic.
2. `feat/seed`: catálogo del Figma (4 sedes, canchas y precios).
3. `feat/auth-firebase`: verificación del token + `get_usuario_actual` + formato de errores.
4. `feat/usuarios`: registro, ver, editar y dar de baja el perfil.
5. `feat/catalogo`: sedes y espacios con filtros.
6. `feat/disponibilidad`: CU-12.
7. `feat/reservas`: crear, listar, detalle y cancelar con todas las validaciones.
8. `test/backend`: tests de las reglas (superposición, horario, pasado, cancelación).

## Fase 3 — App (PRs previstos)

1. `feat/app-base`: proyecto Flutter, Firebase, tema claro/oscuro, cliente HTTP, manejo de errores.
2. `feat/auth`: AuthGate, login, registro, recuperar contraseña.
3. `feat/home-sedes`: home, todas las sedes, sede con canchas, filtro por deporte y tipo.
4. `feat/horarios`: CU-12 (grilla, fecha, cancha, duración, estado vacío) + confirmar reserva.
5. `feat/mis-reservas`: próximas, historial, detalle y cancelar.
6. `feat/perfil`: ver, editar, cambiar contraseña, cerrar sesión, eliminar cuenta.
7. `feat/icono`: ícono de la app y nombre `ClubMartinianoHerenu`.

## Riesgos

| Riesgo | Plan |
|---|---|
| Primera vez con Flutter | Instalar el entorno el primer día y probar un "hola mundo" en el emulador antes de seguir. |
| Render gratis se "duerme" (primera respuesta tarda ~50 s) | Timeouts generosos y pantalla de carga en la app. Abrir la API un rato antes de la demo. |
| Notificaciones en el emulador | Usar un emulador con Google Play Services. Probar temprano un push manual desde la consola de Firebase. |
| Poco tiempo | Fases con colchón; las notificaciones van después de lo obligatorio. |

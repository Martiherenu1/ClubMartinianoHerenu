# CONTEXTO DEL PROYECTO — ClubMartinianoHerenu

> Archivo central de contexto. Se actualiza en cada sesión de trabajo.
> Última actualización: 2026-10-12

## 1. Qué es

Aplicación móvil para **gestión de reservas de espacios deportivos** (canchas)
en distintas sedes. Trabajo Práctico de la materia Electiva General —
Universidad de Morón (Docente: Marcelo Camicha).

- **Alumno:** Martiniano Hereñu
- **Nombre app y repo (obligatorio que coincidan):** `ClubMartinianoHerenu`
- **Repo GitHub:** https://github.com/Martiherenu1/ClubMartinianoHerenu (usuario: `Martiherenu1`)
- **Clon local:** `C:\dev\ClubMartinianoHerenu` (fuera de OneDrive y con ruta corta:
  OneDrive bloquea los archivos de compilación y Windows limita las rutas a 260 caracteres).
- **Caso de uso asignado (Entrega 1):** CU-12 "Consultar horarios disponibles".

## 2. Stack técnico (decidido)

| Capa            | Tecnología                          | Estado        |
|-----------------|-------------------------------------|---------------|
| App móvil       | Flutter 3.47 (SDK en `C:\dev\flutter`) | Base creada (tema, API, errores) |
| Diseño UX/UI    | Figma grupal                        | **Terminado** (Entrega 1) |
| Backend / API   | FastAPI (Python) + SQLAlchemy + Alembic | Modelos y migración inicial |
| Base de datos   | PostgreSQL                          | Local en Docker |
| Auth            | Firebase Authentication (email/password + reset) | Proyecto creado |
| Push            | Firebase Cloud Messaging (FCM)      | **Dentro del alcance** |
| Deploy API+DB   | Render                              | Por empezar   |
| Docs API        | Swagger / OpenAPI (auto por FastAPI)| Automático    |

## 3. Decisiones tomadas

### Vigentes (2026-10-10, fase Entrega 2)
- **Alcance de la app = todo el lado usuario:** auth (login, registro, recuperar
  contraseña), home, sedes, espacios con filtro por tipo, consulta de horarios
  (CU-12), reservar, mis reservas, historial, cancelar, perfil (ver/editar/cerrar
  sesión). **Sin panel de administración**: sedes y espacios se cargan por seed.
- **Notificaciones push incluidas en el plan** (FCM, recordatorio de reservas próximas).
- **El diseño a implementar es el Figma grupal** y las especificaciones de CU del
  grupo (Drive). Las decisiones de agosto que chocan con el Figma se revisan (ver abajo).
- **Monorepo** `ClubMartinianoHerenu/` con `backend/` y `mobile/` separados
  (se pueden zipear por separado para Blackboard).
- **FastAPI** en vez de Flask/Django (más liviano, Swagger automático).

- **Precio informativo** (confirmado 2026-10-10): precio por hora en cada cancha y
  total en la reserva, sin pagos.
- **Un solo rol** (usuario). El panel de admin del Figma queda fuera de alcance.
- **Git: GitHub Flow con PRs** (exigido): rama por funcionalidad → Pull Request →
  merge a `main`. Tags SemVer por fase. Claude crea ramas, commits y PRs con `gh`;
  **Martiniano revisa y mergea cada PR**.
- **Sin "Modificar reserva" (CU-11)**: se cancela y se reserva de nuevo.
- **Con "Cambiar contraseña" (CU-04)** desde la fila "Seguridad" del perfil (Firebase).
- **Registro vía API** (valida email y DNI duplicados, crea el usuario en Firebase
  con Admin SDK). Login, recuperar y cambiar contraseña: directo con Firebase.
- **Recordatorios push con cron de GitHub Actions** (Render gratis se duerme).
- **Cancelación:** solo reservas propias, confirmadas y que no hayan empezado (CU-10).

Detalle completo en `modelo-datos.md`, `arquitectura.md`, `plan.md` y `casos-de-uso.md`.

## 4. Perfil del alumno (para calibrar el acompañamiento)

- **Flutter:** primera vez, y **todavía no está instalado** (SDK, Android Studio y
  emulador). Explicar paso a paso.
- **Python:** experiencia con ayuda de IA. → Ritmo intermedio.
- **SQL:** experiencia con ayuda de IA. → Ritmo intermedio.
- Tiene cuenta de **GitHub**, **Render** y proyecto **Firebase** creado.

## 5. Entregas

1. **Entrega 1 — Diseño:** ✅ hecha (Figma grupal + especificación CU-12 + defensa).
2. **Entrega 2 — Desarrollo (INDIVIDUAL, defensa individual):** backend en la nube
   + app Flutter conectada, modelo de datos, ícono, auth completa, gestión de
   reservas, manejo de errores, demo en emulador. Se sube backend (ZIP) y app (ZIP)
   a Blackboard antes de la exposición.

> **Fecha límite Entrega 2: antes del 03/11/2026.** Cronograma en `plan.md`.

## 6. Estado actual

- [x] Requerimientos analizados (ver `requerimientos.md`)
- [x] Stack definido
- [x] Estructura de carpetas creada
- [x] Repo GitHub creado y primer push (rama `main`)
- [x] Proyecto Firebase creado + Auth Email/Password habilitado → **Hito 0 COMPLETO**
- [x] Diseño en Figma (grupal) → Entrega 1 terminada
- [x] Planificación de la Entrega 2 → PR #1, tag `v0.1.0`
- [x] Entorno Flutter: SDK 3.47 + Android Studio + emulador `Medium_Phone_API_37.0`
      (Google Play), probado con una app de ejemplo
- [ ] **Backend FastAPI (Fase 1, EN CURSO)**
- [ ] App Flutter
- [ ] Notificaciones push
- [ ] Deploy

## 7. Estado del backend

- [x] **Etapa 1 — Fundación:** estructura FastAPI, config por `.env`, conexión a
  PostgreSQL (Docker, puerto **5433**), endpoints `/` y `/health`, Swagger OK.
  - Entorno: venv Python 3.13 en `backend/.venv`. Deps fijadas en `requirements.txt`.
  - Base local: `docker compose up -d` → PostgreSQL 16 en `localhost:5433`
    (usuario `club` / clave `clubpass` / base `clubdb`).
  - ⚠️ Nota: esta máquina tiene un PostgreSQL nativo en el 5432; por eso el
    contenedor usa el 5433.
- [x] **Modelos + migración inicial** (`feat/modelos`): 6 tablas (usuario, sede,
  espacio_deportivo, reserva, dispositivo, notificacion) con restricciones en la
  base (horas completas, fin > inicio, estados válidos, DNI y cancha únicos,
  notificación no duplicada). Migración `0024733bc0bd`.
- [x] **Seed del catálogo** (`feat/seed`): 4 sedes y 22 canchas del Figma,
  idempotente (`python -m app.seed`). Algunos precios son estimados.
- [x] **Auth con Firebase + formato de errores + base de tests** (`feat/auth-firebase`).
  Clave del Admin SDK en `backend/` (excluida por `.gitignore`), probada contra
  Firebase real. Tests con `pytest` sobre la base `clubdb_test`.
- [x] **Usuarios** (`feat/usuarios`): registro vía API (crea la cuenta en Firebase y
  la borra si falla el perfil), ver, editar y dar de baja (anonimiza), dispositivos
  para push. Probado también contra Firebase real. Zona horaria de Argentina en
  `core/tiempo.py`.
- [x] **Catálogo** (`feat/catalogo`): `/sedes`, `/sedes/{id}`, `/espacios` con
  filtros, `/espacios/{id}` y `/deportes`. Solo muestra sedes y canchas activas;
  tipos en orden natural (F5, F7, F11).
- [x] **Disponibilidad — CU-12 de Martiniano** (`feat/disponibilidad`):
  `GET /espacios/{id}/disponibilidad?fecha=&duracion=`. Algoritmo explicado en
  `docs/cu-12-disponibilidad.md` (para la defensa).
- [x] **Reservas** (`feat/reservas`): crear (CU-09) con bloqueo de la cancha
  (`SELECT ... FOR UPDATE`) para que dos reservas simultáneas no tomen el mismo
  turno, listar próximas/historial (CU-08) con estado derivado (`en_curso`,
  `completada`), detalle y cancelar (CU-10). 107 tests.
- **Fase 1 (backend) COMPLETA** → tag `v0.2.0` al mergear.
- [x] **Base de la app** (`feat/app-base`, Fase 3): proyecto Flutter en `mobile/`
  (id `com.martinianoherenu.club_martinianoherenu`), tema claro/oscuro del Figma,
  cliente de la API con errores traducidos (`SinConexion`, `ErrorServidor`,
  `NoAutenticado`, `ErrorNegocio`), 12 tests. Probada en el emulador contra la API local.
- [x] **Login, registro y recuperar contraseña** (`feat/auth`): Firebase en la app
  (`google-services.json` fuera del repo), AuthGate, pantallas del Figma, 37 tests.
  Probado de punta a punta en el emulador con una cuenta real. Se corrigió un error
  del backend: con la PC 13 s atrasada rechazaba tokens válidos (margen de reloj de
  10 s → 60 s). Contraseña mínima de 8 como pide el Figma.
- [x] **Home, Todas las sedes y detalle de sede** (`feat/home-sedes`): barra inferior
  con 4 pestañas (cada una con su Navigator), Home con próxima reserva y filtro por
  deporte, lista de sedes y canchas con filtros por deporte y tipo (CU-20). Fotos del
  Figma incluidas en la app. 59 tests. Probado en el emulador con la API local y el seed.
- [x] **Horarios (CU-12) y reserva (CU-09)** (`feat/horarios`): pantalla única con
  cancha, fecha (14 días), duración, grilla de franjas (ocupadas deshabilitadas),
  resumen y "Confirmar reserva"; pantalla "¡Reserva confirmada!" que redirige a
  Reservas; la Home se recarga. 71 tests. Probado en el emulador con la API real.
- [x] **Mis reservas** (`feat/mis-reservas`): próximas e historial, detalle y cancelación
  (CU-08 y CU-10). El detalle no muestra todavía "Recordatorios": llega con las
  notificaciones. 83 tests. Probado en el emulador con la API real.
- [x] **Perfil** (`feat/perfil`): ver y editar datos (CU-05/06), modo claro/oscuro,
  cambiar contraseña (CU-04, Firebase), cerrar sesión y baja de la cuenta con la
  encuesta de salida (CU-07). 103 tests. Probado en el emulador con Firebase y API reales.
- [x] **Ícono y nombre** (`feat/icono`): monograma "CH" en lima sobre el fondo oscuro
  del club, ícono adaptativo de Android, pantalla de arranque oscura. El nombre visible
  es `ClubMartinianoHerenu`. El Figma no trae ícono: es un diseño propio, fácil de cambiar.
- [ ] Deploy en Render.

## 8. Próximos pasos inmediatos

1. Martiniano mergea el PR `feat/icono`.
2. Deploy en Render, notificaciones push y cierre (ver `docs/plan.md`).

### Decisiones abiertas

- **Encuesta de salida (baja de cuenta):** el Figma la pide, pero ni el backend ni las
  especificaciones de los compañeros (CU-07) definen dónde se guardan las respuestas.
  Hoy la app muestra la encuesta y **no guarda** las respuestas; "Omitir" y "Enviar y
  eliminar" hacen lo mismo. Si el grupo quiere guardarlas hace falta un endpoint y una
  tabla en el backend.

## 9. Cómo colaboramos

- Este archivo (`CONTEXTO.md`) es la fuente de verdad del estado del proyecto.
- Documentos de apoyo en `docs/`: `requerimientos.md`, `arquitectura.md`, `modelo-datos.md`, `plan.md`.
- Cuando traigas info nueva (capturas, código, dudas), la incorporamos y actualizamos este archivo.

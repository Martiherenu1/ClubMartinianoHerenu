# CONTEXTO DEL PROYECTO — ClubMartinianoHerenu

> Archivo central de contexto. Se actualiza en cada sesión de trabajo.
> Última actualización: 2026-08-25

## 1. Qué es

Aplicación móvil para **gestión de reservas de espacios deportivos** (canchas)
en distintas sedes. Trabajo Práctico de la materia Electiva General —
Universidad de Morón (Docente: Marcelo Camicha).

- **Alumno:** Martiniano Hereñu
- **Nombre app y repo (obligatorio que coincidan):** `ClubMartinianoHerenu`
- **Repo GitHub:** https://github.com/Martiherenu1/ClubMartinianoHerenu (usuario: `Martiherenu1`)

## 2. Stack técnico (decidido)

| Capa            | Tecnología                          | Estado        |
|-----------------|-------------------------------------|---------------|
| App móvil       | Flutter                             | Por empezar   |
| Diseño UX/UI    | Figma                               | Por empezar   |
| Backend / API   | FastAPI (Python) + SQLAlchemy + Alembic | Por empezar |
| Base de datos   | PostgreSQL                          | Por empezar   |
| Auth            | Firebase Authentication (email/password + reset) | Por empezar |
| Push            | Firebase Cloud Messaging (FCM)      | **EN REPOSO** |
| Deploy API+DB   | Render                              | Por empezar   |
| Docs API        | Swagger / OpenAPI (auto por FastAPI)| Automático    |

## 3. Decisiones tomadas

- **Un solo rol de usuario.** El enunciado no pide admin ni administrador de
  sede. Sedes y espacios se cargan como datos semilla (seed), no hay ABM en la app.
- **Sin pagos ni precios.** El enunciado no menciona dinero. Las reservas son gratuitas.
- **Cancelación libre**, sin restricción horaria (el enunciado no la pide).
- **Monorepo** `ClubMartinianoHerenu/` con `backend/` y `mobile/` separados
  (se pueden zipear por separado para Blackboard).
- **FastAPI** en vez de Django REST (más liviano, Swagger automático).
- **Notificaciones push pospuestas**: se dejan previstas en la arquitectura
  pero no se desarrollan hasta definirlo.

## 4. Perfil del alumno (para calibrar el acompañamiento)

- **Flutter:** primera vez. → Explicar en detalle, paso a paso.
- **Python:** experiencia con ayuda de IA. → Ritmo intermedio.
- **SQL:** experiencia con ayuda de IA. → Ritmo intermedio.
- Tiene cuenta de **GitHub** y **Render**. **No** tiene Firebase (armar de cero).

## 5. Entregas (sin fechas confirmadas aún)

> **Entrega 1 (Figma) es GRUPAL** — la hace Martiniano con sus compañeros, más
> adelante. El **backend y el desarrollo son INDIVIDUALES** y es el foco actual.

1. **Entrega 1 — Diseño:** mockup + prototipo navegable en Figma. Defensa grupal. (diferido)
2. **Entrega 2 — Desarrollo:** backend en la nube + app Flutter conectada,
   modelo de datos, ícono, auth completa, gestión de reservas, manejo de errores,
   demo en emulador. Se sube backend (ZIP) y app (ZIP) a Blackboard. Defensa individual.

> ⚠️ PENDIENTE: confirmar fechas de Entrega 1 y Entrega 2 → convertir el plan por
> hitos en un cronograma con fechas.

## 6. Estado actual

- [x] Requerimientos analizados (ver `requerimientos.md`)
- [x] Stack definido
- [x] Estructura de carpetas creada
- [x] Arquitectura documentada (ver `arquitectura.md`)
- [x] Modelo de datos documentado (ver `modelo-datos.md`)
- [x] Repo GitHub creado y primer push (rama `main`)
- [x] Proyecto Firebase creado + Auth Email/Password habilitado → **Hito 0 COMPLETO**
- [ ] Backend FastAPI (EN CURSO — foco actual)
- [ ] Diseño en Figma (GRUPAL, diferido)
- [ ] Backend FastAPI
- [ ] App Flutter
- [ ] Deploy

## 7. Estado del backend (Hito 2 en curso)

- [x] **Etapa 1 — Fundación:** estructura FastAPI, config por `.env`, conexión a
  PostgreSQL (Docker, puerto **5433**), endpoints `/` y `/health`, Swagger OK.
  Verificado: el servidor arranca y responde.
  - Entorno: venv Python 3.13 en `backend/.venv`. Deps fijadas en `requirements.txt`.
  - Base local: `docker compose up -d` → PostgreSQL 16 en `localhost:5433`
    (usuario `club` / clave `clubpass` / base `clubdb`).
  - ⚠️ Nota: esta máquina tiene un PostgreSQL nativo en el 5432; por eso el
    contenedor usa el 5433.
- [ ] **Etapa 2 — Modelos + migraciones** (Alembic): usuario, sede, espacio, reserva.
- [ ] **Etapa 3 — Auth** (verificación de token Firebase) + endpoints.
- [ ] **Etapa 4 — Lógica de reservas** (validaciones + solapamiento) + seed.
- [ ] **Etapa 5 — Pruebas + deploy en Render.**

## 8. Próximos pasos inmediatos

1. Etapa 2: definir los modelos SQLAlchemy y la primera migración con Alembic.
2. (Pendiente) Confirmar fechas de entrega para armar cronograma.

## 9. Cómo colaboramos

- Este archivo (`CONTEXTO.md`) es la fuente de verdad del estado del proyecto.
- Documentos de apoyo en `docs/`: `requerimientos.md`, `arquitectura.md`, `modelo-datos.md`, `plan.md`.
- Cuando traigas info nueva (capturas, código, dudas), la incorporamos y actualizamos este archivo.

# CONTEXTO DEL PROYECTO — ClubMartinianoHerenu

> Archivo central de contexto. Se actualiza en cada sesión de trabajo.
> Última actualización: 2026-08-25

## 1. Qué es

Aplicación móvil para **gestión de reservas de espacios deportivos** (canchas)
en distintas sedes. Trabajo Práctico de la materia Electiva General —
Universidad de Morón (Docente: Marcelo Camicha).

- **Alumno:** Martiniano Hereñu
- **Nombre app y repo (obligatorio que coincidan):** `ClubMartinianoHerenu`

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

1. **Entrega 1 — Diseño:** mockup + prototipo navegable en Figma. Defensa grupal.
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
- [ ] Diseño en Figma
- [ ] Backend FastAPI
- [ ] App Flutter
- [ ] Deploy

## 7. Próximos pasos inmediatos

1. Confirmar fechas de entrega.
2. Empezar Entrega 1: diseño de pantallas en Figma (flujo de navegación).
3. En paralelo se puede ir armando el esqueleto del backend FastAPI + modelo de datos.

## 8. Cómo colaboramos

- Este archivo (`CONTEXTO.md`) es la fuente de verdad del estado del proyecto.
- Documentos de apoyo en `docs/`: `requerimientos.md`, `arquitectura.md`, `modelo-datos.md`, `plan.md`.
- Cuando traigas info nueva (capturas, código, dudas), la incorporamos y actualizamos este archivo.

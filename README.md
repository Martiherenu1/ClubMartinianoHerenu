# ClubMartinianoHerenu

Aplicación móvil para la **gestión de reservas de espacios deportivos** (canchas)
en distintas sedes. Trabajo Práctico — Electiva General, Universidad de Morón
(Docente: Marcelo Camicha).

## Descripción

Permite a los usuarios:
- Registrarse e iniciar sesión (con recuperación de contraseña).
- Consultar sedes y espacios deportivos, filtrando por tipo (Fútbol, Paddle, Básquet…).
- Consultar disponibilidad y **reservar** un espacio para una fecha y horario.
- Ver sus reservas activas y su historial, y cancelar reservas.
- Recibir notificaciones push de reservas próximas *(pendiente)*.

## Estructura del repositorio

```
ClubMartinianoHerenu/
├── backend/   API REST (FastAPI + PostgreSQL)   → ver backend/README.md
├── mobile/    App móvil (Flutter)               → ver mobile/README.md
├── docs/      Documentación del proyecto
└── design/    Diseño UX/UI (Figma, assets)
```

## Stack

| Capa          | Tecnología                                    |
|---------------|-----------------------------------------------|
| App móvil     | Flutter                                        |
| Backend / API | FastAPI (Python) + SQLAlchemy + Alembic        |
| Base de datos | PostgreSQL                                      |
| Autenticación | Firebase Authentication                        |
| Deploy        | Render (API + DB)                              |
| Docs API      | Swagger / OpenAPI                              |

## Documentación

- [`docs/CONTEXTO.md`](docs/CONTEXTO.md) — estado del proyecto, decisiones y próximos pasos.
- [`docs/requerimientos.md`](docs/requerimientos.md) — resumen del enunciado.
- [`docs/arquitectura.md`](docs/arquitectura.md) — arquitectura, endpoints y validaciones.
- [`docs/modelo-datos.md`](docs/modelo-datos.md) — modelo entidad-relación.
- [`docs/plan.md`](docs/plan.md) — plan de desarrollo por hitos.

## Autor

Martiniano Hereñu

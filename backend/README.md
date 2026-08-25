# Backend — ClubMartinianoHerenu

API REST en **FastAPI** + **PostgreSQL**. Documentación automática en `/docs` (Swagger).

> 🚧 En construcción. Los pasos de configuración y ejecución se completan al armar el backend (Hito 2).

## Requisitos previos (previstos)
- Python 3.11+
- PostgreSQL

## Puesta en marcha (se completará)
```bash
# python -m venv .venv && source .venv/Scripts/activate   (Windows: .venv\Scripts\activate)
# pip install -r requirements.txt
# cp .env.example .env   y completar variables
# alembic upgrade head
# uvicorn app.main:app --reload
```

## Variables de entorno (previstas)
- `DATABASE_URL` — conexión a PostgreSQL.
- `FIREBASE_CREDENTIALS` — ruta/JSON de la cuenta de servicio de Firebase.

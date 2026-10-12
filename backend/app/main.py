"""Punto de entrada de la API REST de ClubMartinianoHerenu.

Crea la aplicación FastAPI, registra el formato único de errores y expone los
endpoints de salud. Los routers de negocio (usuarios, catálogo, disponibilidad,
reservas, notificaciones y tareas) se montan bajo /api/v1 desde `app.api.router`.

Ejecutar en desarrollo:
    uvicorn app.main:app --reload
Documentación interactiva (Swagger): http://localhost:8000/docs
"""
from fastapi import FastAPI

from app.api.router import api_router
from app.core.config import settings
from app.core.errores import registrar_manejadores_de_error

app = FastAPI(
    title="ClubMartinianoHerenu API",
    description=(
        "API REST para la gestión de reservas de espacios deportivos.\n\n"
        "Los endpoints protegidos requieren `Authorization: Bearer <ID token de Firebase>`."
    ),
    version="0.1.0",
)

registrar_manejadores_de_error(app)
app.include_router(api_router)


@app.get("/", tags=["health"])
def root():
    """Chequeo básico de que la API está viva."""
    return {"app": "ClubMartinianoHerenu", "status": "ok", "env": settings.ENVIRONMENT}


@app.get("/health", tags=["health"])
def health():
    """Endpoint de salud (lo usará Render para verificar el despliegue)."""
    return {"status": "ok"}

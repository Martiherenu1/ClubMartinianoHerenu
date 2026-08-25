"""Punto de entrada de la API REST de ClubMartinianoHerenu.

Crea la aplicación FastAPI y expone endpoints de salud. Los routers de negocio
(usuarios, sedes, espacios, reservas) se irán montando en las próximas etapas.

Ejecutar en desarrollo:
    uvicorn app.main:app --reload
Documentación interactiva (Swagger): http://localhost:8000/docs
"""
from fastapi import FastAPI

from app.core.config import settings

app = FastAPI(
    title="ClubMartinianoHerenu API",
    description="API REST para la gestión de reservas de espacios deportivos.",
    version="0.1.0",
)


@app.get("/", tags=["health"])
def root():
    """Chequeo básico de que la API está viva."""
    return {"app": "ClubMartinianoHerenu", "status": "ok", "env": settings.ENVIRONMENT}


@app.get("/health", tags=["health"])
def health():
    """Endpoint de salud (lo usará Render para verificar el despliegue)."""
    return {"status": "ok"}

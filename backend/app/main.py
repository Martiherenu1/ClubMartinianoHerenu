"""Punto de entrada de la API REST de ClubMartinianoHerenu.

Crea la aplicación FastAPI, registra el formato único de errores y expone los
endpoints de salud. Los routers de negocio (usuarios, sedes, espacios, reservas)
se montan bajo /api/v1 a medida que se implementan.

Ejecutar en desarrollo:
    uvicorn app.main:app --reload
Documentación interactiva (Swagger): http://localhost:8000/docs
"""
from fastapi import FastAPI

from app.core.config import settings
from app.core.errores import registrar_manejadores_de_error

app = FastAPI(
    title="ClubMartinianoHerenu API",
    description="API REST para la gestión de reservas de espacios deportivos.",
    version="0.1.0",
)

registrar_manejadores_de_error(app)


@app.get("/", tags=["health"])
def root():
    """Chequeo básico de que la API está viva."""
    return {"app": "ClubMartinianoHerenu", "status": "ok", "env": settings.ENVIRONMENT}


@app.get("/health", tags=["health"])
def health():
    """Endpoint de salud (lo usará Render para verificar el despliegue)."""
    return {"status": "ok"}

"""Router principal de la versión 1 de la API: agrupa todos los recursos bajo /api/v1."""
from fastapi import APIRouter

from app.api.routers import catalogo, disponibilidad, reservas, usuarios

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(usuarios.router)
api_router.include_router(catalogo.router)
api_router.include_router(disponibilidad.router)
api_router.include_router(reservas.router)

"""Formato único de errores de la API.

Toda respuesta de error tiene la misma forma, así la app sabe qué mostrar:

    {"error": {"codigo": "HORARIO_OCUPADO", "mensaje": "El horario ... ya no está disponible."}}

- `codigo`: constante estable para que la app decida qué hacer.
- `mensaje`: texto en español para mostrarle al usuario.

Ver la tabla de códigos HTTP en docs/arquitectura.md.
"""
import logging

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger(__name__)


class ErrorAPI(Exception):
    """Error de negocio que la API devuelve con un código HTTP y un mensaje."""

    def __init__(self, status_code: int, codigo: str, mensaje: str) -> None:
        super().__init__(mensaje)
        self.status_code = status_code
        self.codigo = codigo
        self.mensaje = mensaje


def respuesta_error(status_code: int, codigo: str, mensaje: str) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={"error": {"codigo": codigo, "mensaje": mensaje}},
    )


async def _manejar_error_api(_: Request, exc: ErrorAPI) -> JSONResponse:
    return respuesta_error(exc.status_code, exc.codigo, exc.mensaje)


async def _manejar_validacion(_: Request, exc: RequestValidationError) -> JSONResponse:
    # Ej.: falta un campo obligatorio o una fecha no tiene formato válido.
    primero = exc.errors()[0] if exc.errors() else {}
    campo = ".".join(str(p) for p in primero.get("loc", ()) if p not in ("body", "query", "path"))
    detalle = f" ({campo})" if campo else ""
    return respuesta_error(
        status.HTTP_422_UNPROCESSABLE_CONTENT,
        "DATOS_INVALIDOS",
        f"Los datos enviados no son válidos{detalle}.",
    )


async def _manejar_http(_: Request, exc: StarletteHTTPException) -> JSONResponse:
    # Errores que genera el framework, como una ruta inexistente (404).
    codigos = {404: "NO_ENCONTRADO", 405: "METODO_NO_PERMITIDO"}
    return respuesta_error(
        exc.status_code,
        codigos.get(exc.status_code, "ERROR_HTTP"),
        str(exc.detail),
    )


async def _manejar_inesperado(_: Request, exc: Exception) -> JSONResponse:
    # Se registra el detalle en el log del servidor, pero al cliente no se le
    # muestra información interna (buena práctica de seguridad, módulo 11).
    logger.exception("Error no controlado", exc_info=exc)
    return respuesta_error(
        status.HTTP_500_INTERNAL_SERVER_ERROR,
        "ERROR_INTERNO",
        "Ocurrió un error en el servidor. Intentá de nuevo más tarde.",
    )


def registrar_manejadores_de_error(app: FastAPI) -> None:
    app.add_exception_handler(ErrorAPI, _manejar_error_api)
    app.add_exception_handler(RequestValidationError, _manejar_validacion)
    app.add_exception_handler(StarletteHTTPException, _manejar_http)
    app.add_exception_handler(Exception, _manejar_inesperado)

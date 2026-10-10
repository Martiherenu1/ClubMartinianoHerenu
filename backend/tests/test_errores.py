"""Tests del formato único de errores."""
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import BaseModel

from app.core.errores import ErrorAPI, registrar_manejadores_de_error


class Datos(BaseModel):
    cantidad: int


@pytest.fixture
def cliente_errores():
    app = FastAPI()
    registrar_manejadores_de_error(app)

    @app.get("/negocio")
    def negocio():
        raise ErrorAPI(409, "HORARIO_OCUPADO", "El horario ya no está disponible.")

    @app.post("/validar")
    def validar(datos: Datos):
        return datos

    @app.get("/explota")
    def explota():
        raise RuntimeError("detalle interno que no debe verse")

    return TestClient(app, raise_server_exceptions=False)


def test_error_de_negocio(cliente_errores):
    r = cliente_errores.get("/negocio")
    assert r.status_code == 409
    assert r.json() == {
        "error": {
            "codigo": "HORARIO_OCUPADO",
            "mensaje": "El horario ya no está disponible.",
        }
    }


def test_datos_invalidos_responde_422_con_el_campo(cliente_errores):
    r = cliente_errores.post("/validar", json={"cantidad": "no es un número"})
    assert r.status_code == 422
    assert r.json()["error"]["codigo"] == "DATOS_INVALIDOS"
    assert "cantidad" in r.json()["error"]["mensaje"]


def test_error_inesperado_no_muestra_detalles_internos(cliente_errores):
    r = cliente_errores.get("/explota")
    assert r.status_code == 500
    assert r.json()["error"]["codigo"] == "ERROR_INTERNO"
    assert "detalle interno" not in r.text


def test_ruta_inexistente_en_la_api_real(cliente):
    r = cliente.get("/api/v1/no-existe")
    assert r.status_code == 404
    assert r.json()["error"]["codigo"] == "NO_ENCONTRADO"


def test_health(cliente):
    assert cliente.get("/health").json() == {"status": "ok"}

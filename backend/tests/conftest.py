"""Configuración compartida de los tests.

- Usa una base SEPARADA (`<base>_test`, ej. `clubdb_test`) en el mismo PostgreSQL de
  Docker, así los tests nunca tocan los datos de desarrollo.
- Crea esa base si no existe y le aplica las migraciones de Alembic (las mismas
  que en producción).
- Cada test corre dentro de una transacción que se deshace al terminar: todos
  arrancan con la base limpia.
- Firebase se reemplaza por un verificador falso: el token "token-<uid>" es
  válido para ese uid. Así se prueba la autenticación sin internet.
"""
import os

from sqlalchemy.engine import make_url

# Hay que apuntar a la base de prueba ANTES de importar la app, porque el engine
# de SQLAlchemy se crea al importar app.db.session.
from app.core.config import settings  # noqa: E402

URL_TEST = make_url(settings.DATABASE_URL).set(
    database=f"{make_url(settings.DATABASE_URL).database}_test"
)
os.environ["DATABASE_URL"] = URL_TEST.render_as_string(hide_password=False)
settings.DATABASE_URL = os.environ["DATABASE_URL"]

import pytest  # noqa: E402
from alembic import command  # noqa: E402
from alembic.config import Config  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from firebase_admin import auth as firebase_auth  # noqa: E402
from sqlalchemy import create_engine, text  # noqa: E402
from sqlalchemy.orm import Session  # noqa: E402

from app.core import firebase  # noqa: E402
from app.db.session import get_db  # noqa: E402
from app.main import app  # noqa: E402

PREFIJO_TOKEN = "token-"


def _crear_base_de_prueba() -> None:
    admin = create_engine(
        URL_TEST.set(database="postgres"), isolation_level="AUTOCOMMIT"
    )
    with admin.connect() as conn:
        existe = conn.scalar(
            text("SELECT 1 FROM pg_database WHERE datname = :n"),
            {"n": URL_TEST.database},
        )
        if not existe:
            conn.execute(text(f'CREATE DATABASE "{URL_TEST.database}"'))
    admin.dispose()


@pytest.fixture(scope="session")
def engine():
    _crear_base_de_prueba()
    cfg = Config(os.path.join(os.path.dirname(__file__), "..", "alembic.ini"))
    cfg.set_main_option("sqlalchemy.url", os.environ["DATABASE_URL"])
    command.upgrade(cfg, "head")
    eng = create_engine(os.environ["DATABASE_URL"])
    yield eng
    eng.dispose()


@pytest.fixture
def db(engine):
    """Sesión dentro de una transacción que se deshace al terminar el test."""
    conexion = engine.connect()
    transaccion = conexion.begin()
    sesion = Session(bind=conexion, join_transaction_mode="create_savepoint")
    yield sesion
    sesion.close()
    transaccion.rollback()
    conexion.close()


def _verificador_falso(token: str) -> dict:
    if token == "token-vencido":
        raise firebase_auth.ExpiredIdTokenError("vencido", cause=None)
    if token.startswith(PREFIJO_TOKEN):
        return {"uid": token.removeprefix(PREFIJO_TOKEN)}
    raise firebase_auth.InvalidIdTokenError("token inválido")


class FirebaseFalso:
    """Reemplaza las llamadas a Firebase y recuerda qué se pidió."""

    def __init__(self) -> None:
        self.cuentas: dict[str, str] = {}  # email -> uid
        self.eliminados: list[str] = []
        self._creados = 0

    def crear_usuario(self, email: str, password: str, nombre_visible: str) -> str:
        if email in self.cuentas:
            raise firebase_auth.EmailAlreadyExistsError(
                "existe", cause=None, http_response=None
            )
        self._creados += 1
        uid = f"uid-{self._creados}"
        self.cuentas[email] = uid
        return uid

    def eliminar_usuario(self, uid: str) -> None:
        self.eliminados.append(uid)


@pytest.fixture(autouse=True)
def firebase_falso(monkeypatch) -> FirebaseFalso:
    falso = FirebaseFalso()
    monkeypatch.setattr(firebase, "verificar_id_token", _verificador_falso)
    monkeypatch.setattr(firebase, "crear_usuario", falso.crear_usuario)
    monkeypatch.setattr(firebase, "eliminar_usuario", falso.eliminar_usuario)
    return falso


@pytest.fixture
def cliente(db):
    """Cliente HTTP de la API real, usando la sesión de prueba."""
    app.dependency_overrides[get_db] = lambda: db
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c
    app.dependency_overrides.clear()


def auth_header(uid: str) -> dict[str, str]:
    """Header Authorization con un token falso válido para `uid`."""
    return {"Authorization": f"Bearer {PREFIJO_TOKEN}{uid}"}

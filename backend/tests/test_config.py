"""La URL de la base que entrega Render se adapta al formato de SQLAlchemy."""
import pytest

from app.core.config import normalizar_url_de_base


@pytest.mark.parametrize(
    "entrada, esperada",
    [
        # Render puede entregarla con cualquiera de los dos prefijos.
        ("postgres://u:p@host/db", "postgresql+psycopg2://u:p@host/db"),
        ("postgresql://u:p@host:5432/db", "postgresql+psycopg2://u:p@host:5432/db"),
        # La de desarrollo ya viene completa: no se toca.
        (
            "postgresql+psycopg2://club:clubpass@localhost:5433/clubdb",
            "postgresql+psycopg2://club:clubpass@localhost:5433/clubdb",
        ),
        # Espacios sobrantes al pegarla en el panel de Render.
        ("  postgres://u:p@host/db \n", "postgresql+psycopg2://u:p@host/db"),
    ],
)
def test_normaliza_la_url_de_base(entrada, esperada):
    assert normalizar_url_de_base(entrada) == esperada

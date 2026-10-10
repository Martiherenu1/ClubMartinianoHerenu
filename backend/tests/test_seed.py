"""Tests del catálogo inicial y del nombre compuesto de las canchas."""
import pytest
from sqlalchemy import func, select

from app.models import EspacioDeportivo, Sede
from app.seed import cargar_catalogo
from app.services.nombres import generar_nombre_compuesto


@pytest.mark.parametrize(
    ("sede", "direccion", "deporte", "tipo", "numero", "esperado"),
    [
        ("Morón", "Av. Rivadavia 17500", "Fútbol", "F5", 1, "Moron_Rivadavia_17500_Futbol_F5_1"),
        ("Ramos Mejía", "Calle Belgrano 1240", "Vóley", "Indoor parquet", 1,
         "RamosMejia_Belgrano_1240_Voley_IndoorParquet_1"),
        ("San Justo", "Av. Casanova 320", "Golf", "9 hoyos", 1, "SanJusto_Casanova_320_Golf_9Hoyos_1"),
    ],
)
def test_nombre_compuesto(sede, direccion, deporte, tipo, numero, esperado):
    assert generar_nombre_compuesto(sede, direccion, deporte, tipo, numero) == esperado


def test_catalogo_tiene_4_sedes_y_22_canchas(db):
    assert cargar_catalogo(db) == (4, 22)
    assert db.scalar(select(func.count()).select_from(Sede)) == 4
    assert db.scalar(select(func.count()).select_from(EspacioDeportivo)) == 22


def test_seed_se_puede_correr_dos_veces_sin_duplicar(db):
    cargar_catalogo(db)
    cargar_catalogo(db)
    assert db.scalar(select(func.count()).select_from(EspacioDeportivo)) == 22

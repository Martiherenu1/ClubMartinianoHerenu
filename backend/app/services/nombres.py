"""Generación del nombre compuesto de un espacio deportivo.

Formato pedido por el TP: Sede_Direccion_Tipo_Numero, por ejemplo
`Moron_Rivadavia_19850_Paddle_1`. Como en este club un deporte tiene varios
tipos (Fútbol 5, 7, 11…), se agrega el deporte, igual que en el CU-21:
`Moron_Rivadavia_17500_Futbol_F5_1`.
"""
import re
import unicodedata

# Palabras de la dirección que no aportan al nombre ("Av. Rivadavia" -> "Rivadavia").
_PALABRAS_IGNORADAS = {"av", "avenida", "calle", "pje", "pasaje"}


def _sin_acentos(texto: str) -> str:
    """'Morón' -> 'Moron', 'Fútbol' -> 'Futbol'."""
    normalizado = unicodedata.normalize("NFKD", texto)
    return "".join(c for c in normalizado if not unicodedata.combining(c))


def _palabras(texto: str) -> list[str]:
    """Separa en palabras alfanuméricas, sin acentos ni signos."""
    return re.findall(r"[A-Za-z0-9]+", _sin_acentos(texto))


def _camel(texto: str) -> str:
    """'Ramos Mejía' -> 'RamosMejia', 'Polvo de ladrillo' -> 'PolvoDeLadrillo'."""
    return "".join(p[:1].upper() + p[1:] for p in _palabras(texto))


def generar_nombre_compuesto(
    sede: str, direccion: str, deporte: str, tipo: str, numero: int
) -> str:
    """Arma el nombre compuesto de un espacio deportivo.

    >>> generar_nombre_compuesto("Morón", "Av. Rivadavia 17500", "Fútbol", "F5", 1)
    'Moron_Rivadavia_17500_Futbol_F5_1'
    >>> generar_nombre_compuesto("Ramos Mejía", "Calle Belgrano 1240", "Tenis", "Polvo de ladrillo", 2)
    'RamosMejia_Belgrano_1240_Tenis_PolvoDeLadrillo_2'
    """
    partes_direccion = [
        p for p in _palabras(direccion) if p.lower() not in _PALABRAS_IGNORADAS
    ]
    return "_".join(
        [_camel(sede), *partes_direccion, _camel(deporte), _camel(tipo), str(numero)]
    )

"""Prueba contra el Firebase real: que las credenciales configuradas funcionen.

Se saltea si no hay FIREBASE_CREDENTIALS. Necesita internet.
Correr solo este test:  pytest -m firebase
"""
import pytest
from firebase_admin import auth

from app.core import firebase
from app.core.config import settings

pytestmark = [
    pytest.mark.firebase,
    pytest.mark.skipif(
        not settings.FIREBASE_CREDENTIALS, reason="Sin FIREBASE_CREDENTIALS"
    ),
]


def test_credenciales_de_firebase_validas():
    app_firebase = firebase.obtener_app_firebase()
    # Pedir un usuario cualquiera alcanza para comprobar que Firebase acepta la clave.
    pagina = auth.list_users(max_results=1, app=app_firebase)
    assert pagina is not None


def test_firebase_rechaza_un_token_inventado(monkeypatch):
    # Se usa la función real, no el verificador falso de conftest.
    monkeypatch.undo()
    with pytest.raises(auth.InvalidIdTokenError):
        firebase.verificar_id_token("esto-no-es-un-token")

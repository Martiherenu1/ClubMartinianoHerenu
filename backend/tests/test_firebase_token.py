"""La verificación del ID token tolera un reloj atrasado respecto de Google.

Caso real: con la PC 13 s atrasada, un token válido recién emitido se rechazaba
con "Token used too early" (el margen era de 10 s) y la app volvía al login.
"""
from firebase_admin import auth

from app.core import firebase
# Se importa acá, antes de que el fixture autouse reemplace la función por la falsa.
from app.core.firebase import verificar_id_token as verificar_real


def test_tolera_un_reloj_atrasado(monkeypatch):
    pedido = {}

    def falso(token, app=None, check_revoked=False, clock_skew_seconds=0):
        pedido["clock_skew_seconds"] = clock_skew_seconds
        return {"uid": "abc"}

    monkeypatch.setattr(auth, "verify_id_token", falso)
    monkeypatch.setattr(firebase, "obtener_app_firebase", lambda: object())

    assert verificar_real("un-token")["uid"] == "abc"
    assert pedido["clock_skew_seconds"] == 60  # el máximo que admite el SDK

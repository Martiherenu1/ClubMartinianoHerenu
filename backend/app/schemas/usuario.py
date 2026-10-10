"""Esquemas de entrada y salida de usuarios (lo que viaja como JSON).

Las validaciones de formato se hacen acá: si fallan, la API responde 422
`DATOS_INVALIDOS` sin llegar a tocar Firebase ni la base (CU-03 FA1, CU-06 FA1).
"""
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.core.tiempo import ahora


class DatosPersonales(BaseModel):
    """Datos que el usuario carga al registrarse y puede editar después."""

    nombre: str = Field(min_length=1, max_length=80, examples=["Martiniano"])
    apellido: str = Field(min_length=1, max_length=80, examples=["Hereñu"])
    # DNI argentino: 7 u 8 dígitos, sin puntos.
    dni: str = Field(pattern=r"^\d{7,8}$", examples=["40123456"])
    fecha_nacimiento: date = Field(examples=["2001-03-15"])

    @field_validator("nombre", "apellido")
    @classmethod
    def sin_espacios_sobrantes(cls, valor: str) -> str:
        valor = " ".join(valor.split())
        if not valor:
            raise ValueError("no puede estar vacío")
        return valor

    @field_validator("dni", mode="before")
    @classmethod
    def dni_sin_puntos(cls, valor):
        # Acepta "40.123.456" y lo guarda como "40123456".
        return valor.replace(".", "").strip() if isinstance(valor, str) else valor

    @field_validator("fecha_nacimiento")
    @classmethod
    def fecha_razonable(cls, valor: date) -> date:
        hoy = ahora().date()
        if valor >= hoy:
            raise ValueError("tiene que ser una fecha pasada")
        if hoy.year - valor.year > 120:
            raise ValueError("no es una fecha válida")
        return valor


class RegistroUsuario(DatosPersonales):
    """Body de POST /usuarios (CU-03)."""

    email: EmailStr = Field(examples=["martiniano@mail.com"])
    # Firebase exige al menos 6 caracteres.
    password: str = Field(min_length=6, max_length=128, examples=["clave123"])


class EdicionUsuario(DatosPersonales):
    """Body de PUT /usuarios/me (CU-06). El email no se puede editar."""


class UsuarioOut(BaseModel):
    """Perfil que devuelve la API (CU-05)."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    nombre: str
    apellido: str
    dni: str
    fecha_nacimiento: date
    activo: bool
    creado_en: datetime


class DispositivoIn(BaseModel):
    """Body de POST /usuarios/me/dispositivos (CU-24)."""

    fcm_token: str = Field(min_length=10, max_length=512)
    plataforma: str = Field(default="android", max_length=20)

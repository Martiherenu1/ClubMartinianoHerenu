# Backend — ClubMartinianoHerenu

API REST en **FastAPI** + **PostgreSQL**. Documentación automática (Swagger) en `/docs`.

## Requisitos

- Python 3.13
- Docker Desktop (para la base PostgreSQL local)

## Puesta en marcha (local)

### 1. Levantar la base de datos (PostgreSQL en Docker)
```bash
docker compose up -d
```
> Publica PostgreSQL 16 en `localhost:5433` (usuario `club`, clave `clubpass`, base `clubdb`).
> Se usa el 5433 para no chocar con un PostgreSQL nativo que pueda existir en el 5432.

### 2. Crear el entorno virtual e instalar dependencias
```bash
py -3.13 -m venv .venv
```
```bash
.venv\Scripts\activate
```
```bash
pip install -r requirements-dev.txt
```
(`requirements-dev.txt` incluye `requirements.txt` más las herramientas de tests.)

### 3. Configurar variables de entorno
```bash
copy .env.example .env
```
El `.env` ya viene apuntando a la base local del `docker-compose.yml`. Falta la
clave de Firebase:

1. Firebase Console → tu proyecto → ⚙ **Configuración del proyecto** →
   **Cuentas de servicio** → **Generar nueva clave privada**.
2. Guardar el `.json` descargado en esta carpeta (`backend/`). **Es secreto**:
   `.gitignore` lo excluye (`*firebase-adminsdk*.json`).
3. En `.env`, poner su nombre en `FIREBASE_CREDENTIALS`.

### 4. Crear las tablas (migraciones con Alembic)
```bash
alembic upgrade head
```
Aplica todas las migraciones de `alembic/versions/` y deja la base con el esquema
actual. Se corre la primera vez y cada vez que se agrega una migración nueva.

### 5. Cargar el catálogo (sedes y canchas)
```bash
python -m app.seed
```
Carga las 4 sedes y las 22 canchas del Figma. Se puede correr las veces que haga
falta: actualiza lo existente y no duplica.

### 6. Ejecutar el servidor
```bash
uvicorn app.main:app --reload
```

- API: http://localhost:8000
- **Swagger (docs interactivas):** http://localhost:8000/docs
- Health check: http://localhost:8000/health

## Estructura

```
backend/
├── app/
│   ├── main.py            # crea la app FastAPI y monta routers
│   ├── core/config.py     # settings desde variables de entorno (.env)
│   ├── db/
│   │   ├── base.py        # Base declarativa de SQLAlchemy
│   │   └── session.py     # engine + sesiones + dependencia get_db
│   ├── models/            # tablas: usuario, sede, espacio_deportivo, reserva,
│   │                      #   dispositivo, notificacion (ver docs/modelo-datos.md)
│   ├── core/firebase.py   # Admin SDK: verificación de tokens
│   ├── core/errores.py    # formato único de errores
│   ├── api/deps.py        # get_uid_autenticado, get_usuario_actual
│   ├── services/          # lógica de negocio (nombres compuestos, …)
│   ├── seed.py            # carga del catálogo de sedes y canchas
│   ├── schemas/           # esquemas Pydantic (próxima etapa)
│   └── api/               # routers de negocio (próxima etapa)
├── alembic/               # migraciones (versions/ = historial del esquema)
├── alembic.ini            # configuración de Alembic (la URL sale del .env)
├── docker-compose.yml     # PostgreSQL local
├── requirements.txt
└── .env.example
```

## Variables de entorno

| Variable              | Descripción                                                |
|-----------------------|------------------------------------------------------------|
| `DATABASE_URL`        | Conexión a PostgreSQL (formato SQLAlchemy).                |
| `FIREBASE_CREDENTIALS`| Ruta al JSON de la cuenta de servicio de Firebase (Auth y push). En Render, el contenido del JSON. |
| `TAREAS_CLAVE`        | Clave secreta del cron de recordatorios (header `X-Tareas-Clave`). Vacía = el endpoint rechaza todo. |
| `ENVIRONMENT`         | `development` o `production`.                              |

## Tests

Con la base de Docker levantada:

```bash
pytest
```

- Usan una base aparte, `clubdb_test`, que se crea sola y recibe las mismas
  migraciones. **No tocan** los datos de `clubdb`.
- Cada test corre en una transacción que se deshace al terminar.
- Firebase se simula: el token `token-<uid>` vale para ese uid. Los tests de
  `test_firebase_real.py` sí van contra Firebase (necesitan la clave e internet) y
  se saltean si no hay `FIREBASE_CREDENTIALS`.

## Endpoints implementados

Documentación interactiva completa en `/docs` (Swagger). Para probar los
protegidos: botón **Authorize** → pegar el ID token de Firebase.

| Método | Ruta | Auth | CU | Qué hace |
|---|---|---|---|---|
| POST | `/api/v1/usuarios` | — | 03 | Registro: crea la cuenta en Firebase + perfil. 409 si el email o el DNI ya existen. |
| GET | `/api/v1/usuarios/me` | ✔ | 05 | Perfil del usuario autenticado. |
| PUT | `/api/v1/usuarios/me` | ✔ | 06 | Edita nombre, apellido, DNI y fecha de nacimiento (no el email). |
| DELETE | `/api/v1/usuarios/me` | ✔ | 07 | Baja: cancela reservas futuras, borra la cuenta de Firebase y anonimiza el perfil. |
| POST | `/api/v1/usuarios/me/dispositivos` | ✔ | 24 | Registra el token de push del celular. |
| DELETE | `/api/v1/usuarios/me/dispositivos/{token}` | ✔ | 02 | Lo quita al cerrar sesión. |
| GET | `/api/v1/sedes` | ✔ | 16 | Sedes con dirección, horario, cantidad de canchas y deportes. `?deporte=` filtra. |
| GET | `/api/v1/sedes/{id}` | ✔ | 16 | Una sede. |
| GET | `/api/v1/espacios` | ✔ | 13, 20 | Canchas; filtros combinables `?sede_id=&deporte=&tipo=`. |
| GET | `/api/v1/espacios/{id}` | ✔ | 16 | Una cancha (404 si no existe o está inactiva). |
| GET | `/api/v1/deportes` | ✔ | 20 | Deportes y sus tipos, para los chips de filtro. |
| GET | `/api/v1/espacios/{id}/disponibilidad` | ✔ | **12** | Grilla de horarios de un día: `?fecha=AAAA-MM-DD&duracion=1\|2`. Ver `docs/cu-12-disponibilidad.md`. |
| POST | `/api/v1/reservas` | ✔ | 09 | Reserva `{espacio_id, fecha, hora_inicio, duracion}`. 400 fuera de horario o pasado, 409 `HORARIO_OCUPADO`. |
| GET | `/api/v1/reservas` | ✔ | 08 | Mis reservas: `?vista=proximas` (por defecto) o `historial`. |
| GET | `/api/v1/reservas/{id}` | ✔ | 24 | Detalle de una reserva propia. |
| DELETE | `/api/v1/reservas/{id}` | ✔ | 10 | Cancela (pasa a `cancelada`, libera el horario). 409 si ya empezó, terminó o estaba cancelada. Avisa por push. |
| POST | `/api/v1/tareas/recordatorios` | clave | 24 | Lo llama el cron: envía los recordatorios de 24 h y 1 h pendientes. Header `X-Tareas-Clave`. |

## Notificaciones push (CU-24)

- **Registro del celular:** la app manda su token de FCM a `POST /usuarios/me/dispositivos`.
  Si FCM informa que un token ya no existe, el backend lo borra.
- **Recordatorios:** `POST /tareas/recordatorios` revisa las reservas confirmadas de hoy y
  mañana y manda el aviso de **24 h** (desde 24 h antes y hasta 1 h antes) y el de **1 h**
  (desde 1 h antes hasta que empieza). No avisa a quien reservó ya dentro de esa ventana.
  Cada aviso queda en `notificacion` (una fila por reserva y tipo), así que se puede llamar
  las veces que se quiera sin duplicar. Si el usuario no tenía celular registrado o Firebase
  falló, se reintenta en la corrida siguiente mientras siga la ventana.
- **Cancelación:** al cancelar una reserva se manda el aviso en el momento. Si el push
  falla, la cancelación igual queda hecha.
- **Quién lo dispara:** un workflow de GitHub Actions (`.github/workflows/recordatorios.yml`)
  cada 15 minutos. Necesita los secretos `API_URL` y `TAREAS_CLAVE` del repositorio; sin
  ellos termina sin hacer nada.
- **Cada push lleva** `{"tipo": ..., "reserva_id": ...}` para que la app abra el detalle
  de la reserva al tocarlo.

Probar a mano (con la clave de `.env`):

```bash
curl -X POST http://localhost:8000/api/v1/tareas/recordatorios -H "X-Tareas-Clave: <TAREAS_CLAVE>"
```

> **Nota técnica:** el Admin SDK 7.x marca `Message.token` como obsoleto a favor de `fid`
> (ID de instalación). Seguimos usando el token de FCM porque es lo que entrega el plugin
> `firebase_messaging` de Flutter; sigue funcionando y solo muestra un aviso de deprecación.

## Autenticación

Cada request protegido lleva `Authorization: Bearer <ID token de Firebase>`.
`app/api/deps.py` lo verifica con el Admin SDK y obtiene el usuario:

| Situación | Respuesta |
|---|---|
| Sin header o token inválido | 401 `NO_AUTENTICADO` |
| Token vencido | 401 `NO_AUTENTICADO` ("Tu sesión expiró…") |
| Token válido pero sin perfil en la base | 404 `PERFIL_NO_ENCONTRADO` |
| Cuenta dada de baja | 401 `NO_AUTENTICADO` |

Todos los errores de la API tienen la forma
`{"error": {"codigo": "...", "mensaje": "..."}}` (`app/core/errores.py`).

## Migraciones (Alembic)

Cuando se cambia un modelo en `app/models/`:

```bash
alembic revision --autogenerate -m "descripcion del cambio"
```
Genera un archivo nuevo en `alembic/versions/`. **Revisarlo** antes de aplicarlo y
después correr `alembic upgrade head`.

```bash
alembic check
```
Verifica que los modelos y la base estén sincronizados (no falta ninguna migración).

```bash
alembic downgrade -1
```
Deshace la última migración.

## Comandos útiles de la base

```bash
docker compose up -d        # levantar la base
```
```bash
docker compose down          # apagar (conserva los datos)
```
```bash
docker compose down -v       # apagar y BORRAR los datos
```

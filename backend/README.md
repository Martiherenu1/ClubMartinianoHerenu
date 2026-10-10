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
pip install -r requirements.txt
```

### 3. Configurar variables de entorno
```bash
copy .env.example .env
```
El `.env` ya viene apuntando a la base local del `docker-compose.yml`.

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
| `FIREBASE_CREDENTIALS`| Ruta al JSON de la cuenta de servicio de Firebase (Auth).  |
| `ENVIRONMENT`         | `development` o `production`.                              |

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

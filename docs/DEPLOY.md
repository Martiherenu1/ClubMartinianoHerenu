# Deploy en Render — paso a paso

La API y la base de datos se publican en **Render** con un solo archivo,
[`render.yaml`](../render.yaml) (un *Blueprint*). Render lo lee, crea la base
PostgreSQL y el servicio web, y los conecta.

## Qué crea el Blueprint

| Recurso | Nombre | Notas |
|---|---|---|
| Base PostgreSQL (plan gratuito) | `club-db` | Región Virginia. **Vence a los 30 días de creada.** |
| Servicio web (plan gratuito) | `clubmartinianoherenu-api` | Construye con `pip install`; al arrancar corre `alembic upgrade head`, `python -m app.seed` y `uvicorn`. |

Variables del servicio: `DATABASE_URL` (la conecta sola a `club-db`),
`TAREAS_CLAVE` (la genera Render), `ENVIRONMENT=production`, `PYTHON_VERSION`
y `FIREBASE_CREDENTIALS` (la pegás vos, ver paso 2).

## 1. Que el Blueprint esté en `main`

Mergear el PR que agrega `render.yaml`. Render lee el repositorio, así que el
archivo tiene que estar en la rama que despliega.

## 2. Crear el Blueprint en Render

1. En [dashboard.render.com](https://dashboard.render.com): **New +** → **Blueprint**.
2. Conectar GitHub (si lo pide) y elegir `Martiherenu1/ClubMartinianoHerenu`.
3. Render muestra los dos recursos (base y servicio) y pide el valor de
   **`FIREBASE_CREDENTIALS`**: abrir con el Bloc de notas el archivo
   `backend/clubmartinianoherenu-firebase-adminsdk-….json`, copiar **todo** su
   contenido y pegarlo ahí.
4. **Apply**. La primera construcción tarda unos minutos.

> El JSON de Firebase es un secreto: se pega solo en Render, nunca en el repositorio ni en el chat.

## 3. Comprobar que está viva

Anotar la URL del servicio (arriba de su página, algo como
`https://clubmartinianoherenu-api.onrender.com`) y abrir:

- `<URL>/health` → `{"status":"ok"}`
- `<URL>/docs` → Swagger
- `<URL>/api/v1/sedes` sin token → error `401` con el formato `{"error": …}` (la API está protegida).

En **Logs** del servicio tiene que verse que Alembic aplicó la migración y que el
seed cargó 4 sedes y 22 canchas.

## 4. Activar los recordatorios (cron de GitHub Actions)

1. En Render → servicio → **Environment** → copiar el valor de `TAREAS_CLAVE`.
2. En GitHub → repositorio → **Settings → Secrets and variables → Actions → New repository secret**, crear:
   - `API_URL` = la URL del servicio (sin `/` final).
   - `TAREAS_CLAVE` = el valor copiado.
3. En la pestaña **Actions** → *Recordatorios de reservas* → **Run workflow** para probarlo. Tiene que terminar en verde.

## 5. Conectar pgAdmin a la base de Render

En Render → `club-db` → **Connections** están los datos de la conexión externa.
En pgAdmin: **Register → Server** y completar:

| pgAdmin | Dato de Render |
|---|---|
| Host name/address | *Hostname* (termina en `.render.com`) |
| Port | `5432` |
| Maintenance database | `clubdb` |
| Username | `club` |
| Password | *Password* |

En la pestaña **SSL** poner el modo `Require`. La conexión externa está habilitada
para cualquier IP en el Blueprint; conviene restringirla o borrar la base cuando
termine la defensa.

## 6. Apuntar la app a la nube

La app lee la URL de la API con `--dart-define`:

```bash
flutter run --dart-define=API_URL=https://clubmartinianoherenu-api.onrender.com
```

Sin ese parámetro apunta a la API local (`http://10.0.2.2:8000`).

## Antes de la demo

- **Despertar la API** 5 minutos antes: abrir `<URL>/health`. En el plan gratuito
  el servicio se duerme tras ~15 minutos sin tráfico y el primer pedido tarda ~1 minuto.
- Tener a mano: emulador, Render, pgAdmin conectado, Firebase (Authentication y
  Cloud Messaging), GitHub y VSCode.

## Si algo falla

| Síntoma | Causa probable |
|---|---|
| El build falla instalando dependencias | Versión de Python: revisar `PYTHON_VERSION` en `render.yaml`. |
| La API arranca y responde `500` en todo | `FIREBASE_CREDENTIALS` mal pegado (tiene que ser el JSON completo, empezando con `{`). |
| `could not translate host name` en los logs | La base y el servicio están en regiones distintas. |
| `/api/v1/tareas/recordatorios` responde `401 CLAVE_INVALIDA` | El secreto `TAREAS_CLAVE` de GitHub no es el mismo que el de Render. |
| La base desapareció | Venció el plan gratuito (30 días). Se recrea desde el Blueprint y el seed vuelve a cargar el catálogo; los usuarios y reservas se pierden. |

# Guía de defensa — ClubMartinianoHerenu

Para el día de la presentación. Sigue el guion que usó un compañero que ya defendió
(demo en el emulador, base de datos, GitHub, Render y Firebase) y lo traduce a **este**
proyecto: qué abrir, qué decir y dónde está cada cosa en el código.

Para estudiar el código a fondo: [`GUIA-DEL-CODIGO.md`](GUIA-DEL-CODIGO.md).
Para publicar o rearmar la nube: [`DEPLOY.md`](DEPLOY.md).

---

## 1. Antes de entrar

### Una hora antes
- [ ] No hace falta Docker: la demo usa la base de Render (solo se necesita para el plan B).
- [ ] Emulador `Medium_Phone_API_37.0` encendido (tarda ~40 s; si aparece "offline" en `adb devices`, cerrarlo y arrancarlo de nuevo).
- [ ] La cuenta de la demo ya creada y con **una reserva próxima** (para mostrar el detalle y los recordatorios).
- [ ] pgAdmin con el servidor de Render registrado y conectado (ver [`DEPLOY.md`](DEPLOY.md) paso 5).
- [ ] Firebase abierto en dos pestañas: **Authentication → Users** y **Cloud Messaging**.
- [ ] GitHub abierto en el repo: pestañas *Pull requests*, *Releases* y *Actions*.
- [ ] Render abierto en el servicio `clubmartinianoherenu-api` (pestañas *Logs* y *Environment*) y en `club-db`.
- [ ] VSCode con la carpeta `C:\dev\ClubMartinianoHerenu`.

### Cinco minutos antes
- [ ] **Despertar la API**: abrir `https://clubmartinianoherenu-api.onrender.com/health` hasta que diga `{"status":"ok"}`. Si estaba dormida, la primera respuesta tarda ~1 minuto.
- [ ] Hacer un login de prueba en la app para confirmar que todo responde, y volver a la pantalla de login.

> **Plan B si Render no responde:** levantar el backend local (`docker compose up -d` en
> `backend/`, `uvicorn app.main:app`) y abrir la app con
> `flutter run --dart-define=API_URL=http://10.0.2.2:8000`. Decir con naturalidad que
> es el mismo código, apuntando a la base local.

---

## 2. El guion paso a paso

### Paso 1 — Flujo normal en el emulador: del login a confirmar una reserva

1. **Login** con la cuenta de la demo. Decir: *"El login lo hace Firebase Authentication; la app recibe un token y lo manda en cada pedido a mi API."*
2. **Home** → **Sedes** → elegir una sede → elegir una cancha.
3. En **Horarios** (tu CU-12): elegir fecha, duración y una franja libre. Mostrar que las franjas ocupadas aparecen deshabilitadas.
4. **Confirmar reserva** → pantalla "¡Reserva confirmada!" → lleva a **Reservas**, donde aparece la nueva.

Qué decir de CU-12: *"La disponibilidad no se guarda: se calcula en cada consulta. La API arma franjas de una hora entre la apertura y el cierre de la sede y marca cada una como libre, ocupada (se superpone con una reserva confirmada) o pasada."*

### Paso 2 — Volver y reservar de nuevo la misma cancha

1. Volver atrás, entrar a la **misma cancha**, la **misma fecha**.
2. Mostrar que la franja que acabás de reservar **ya aparece ocupada y no se puede elegir**.

Qué decir: *"Aunque la app deshabilita la franja, la regla de verdad está en el backend: si dos personas reservaran a la vez, la API bloquea la fila de la cancha con `SELECT … FOR UPDATE`, atiende de a una, y la segunda recibe un 409 `HORARIO_OCUPADO`."*

Si piden verlo: abrir [`backend/app/services/reservas.py`](../backend/app/services/reservas.py), función `crear`. Las cinco reglas están en orden: cancha activa → dentro del horario de la sede → en el futuro → **bloqueo de la cancha** → sin superposición.

**— Fin de la app —**

### Paso 3 — Dónde se guarda el identificador de los usuarios (pgAdmin)

En pgAdmin, base `clubdb` de Render → *Query Tool*:

```sql
SELECT id, firebase_uid, email, nombre, apellido, activo
FROM usuario
ORDER BY id DESC;
```

Qué decir: *"Cada usuario tiene un `id` numérico interno y un `firebase_uid`, que es el identificador que Firebase le asigna. Ese es el que viaja dentro del token y el que usa la API para saber quién hace el pedido. La contraseña **no** está en mi base: la administra Firebase."*

> Si preguntan por "UUID": nuestro `id` interno es un entero y el `firebase_uid` es una cadena de 28 caracteres que genera Firebase. No usamos el tipo UUID de PostgreSQL.

Para mostrar la reserva que acabás de hacer:

```sql
SELECT r.id, u.email, e.nombre_compuesto, r.fecha, r.hora_inicio, r.hora_fin, r.precio_total, r.estado
FROM reserva r
JOIN usuario u ON u.id = r.usuario_id
JOIN espacio_deportivo e ON e.id = r.espacio_id
ORDER BY r.id DESC;
```

### Paso 4 — GitHub

Mostrar en este orden:
1. **Pull requests → Closed**: un PR por funcionalidad (GitHub Flow), todos revisados y mergeados.
2. **Releases**: `v0.1.0` a `v1.0.0`, una por fase.
3. **Actions**: el workflow *Recordatorios de reservas* corriendo cada 15 minutos.

Qué decir: *"Trabajé con GitHub Flow: una rama por funcionalidad, un Pull Request y merge a `main`. Las versiones usan SemVer y cada una tiene su Release."*

### Paso 5 — Render

1. Servicio `clubmartinianoherenu-api` → **Logs**: se ve el arranque (migraciones, catálogo, uvicorn) y los pedidos de la demo.
2. **Environment**: mostrar los **nombres** de las variables (`DATABASE_URL`, `FIREBASE_CREDENTIALS`, `TAREAS_CLAVE`), **sin revelar los valores**.
3. `club-db`: la base PostgreSQL.
4. Abrir `…/docs` (Swagger) para mostrar los endpoints.

Qué decir: *"Todo se despliega con un archivo, `render.yaml` (un Blueprint): crea la base y la API juntas. Al arrancar, la API aplica las migraciones y carga las 4 sedes y 22 canchas. Es el plan gratuito, por eso se duerme sin tráfico."*

### Paso 6 — Firebase, FCM y las notificaciones

1. **Authentication → Users**: mostrar los usuarios registrados. Decir: *"El registro pasa por mi API, que crea la cuenta en Firebase con el Admin SDK y el perfil en mi base."*
2. **El token de FCM** vive en la tabla `dispositivo` de PostgreSQL:

   ```sql
   SELECT d.id, u.email, d.plataforma, left(d.fcm_token, 24) || '…' AS token, d.actualizado_en
   FROM dispositivo d
   JOIN usuario u ON u.id = d.usuario_id;
   ```

   Decir: *"La app pide permiso, obtiene el token de FCM y lo registra en la API; al cerrar sesión lo borra."*
3. **Los avisos enviados**:

   ```sql
   SELECT id, reserva_id, tipo, resultado, enviada_en
   FROM notificacion
   ORDER BY id DESC;
   ```

#### ¿Cómo manejás las notificaciones? ¿2 horas antes? ¿24 horas antes?

*"Mando dos recordatorios: **24 horas antes y 1 hora antes**. Más un aviso inmediato cuando se cancela una reserva."*

Cómo funciona (la explicación corta):
1. Un **cron de GitHub Actions** llama cada 15 minutos a `POST /api/v1/tareas/recordatorios`, con una clave secreta en el header `X-Tareas-Clave`.
2. La API busca las reservas cuya ventana de recordatorio está abierta: el de 24 h cubre de 24 h a 1 h antes; el de 1 h, la última hora.
3. Por cada una manda el push con el Admin SDK de Firebase y deja una fila en `notificacion`.
4. Esa tabla tiene una restricción única por (`reserva_id`, `tipo`): **el mismo recordatorio no se manda dos veces**, aunque el cron corra seguido.

Por qué un cron externo y no un temporizador dentro de la API: *"En el plan gratuito de Render el servidor se duerme sin tráfico, y un temporizador interno dormido no corre. GitHub Actions sí corre siempre y, de paso, despierta la API."*

Para mostrar en el código: [`backend/app/services/notificaciones.py`](../backend/app/services/notificaciones.py) (`enviar_recordatorios`, `recordatorio_que_corresponde`) y [`.github/workflows/recordatorios.yml`](../.github/workflows/recordatorios.yml).

Si piden la prueba en vivo: en **Actions → Recordatorios de reservas → Run workflow**, o llamar al endpoint desde Swagger (`/docs`) con la clave.

> Si el recordatorio de 1 h o de 24 h no llega: una reserva creada **dentro** de la ventana (por ejemplo, reservar para dentro de 30 minutos) no recibe ese recordatorio, a propósito, porque sería avisar de algo que el usuario acaba de hacer.

---

## 3. Preguntas probables

### "¿Se puede cambiar el front?" (el profesor dijo que sí)

El front replica el flujo principal del Figma grupal. Se puede cambiar sin tocar el backend, porque la app y la API solo se hablan por el contrato REST (`/docs`).

Dónde tocar según lo que quieran cambiar:

| Si quieren cambiar… | Archivo |
|---|---|
| Colores, tipografías, modo claro/oscuro | `mobile/lib/app/tema.dart` |
| La barra inferior | `mobile/lib/widgets/barra_inferior.dart` |
| El home (próxima reserva, filtro por deporte) | `mobile/lib/features/inicio/pantalla_inicio.dart` |
| La lista de sedes y el detalle de una sede | `features/sedes/pantalla_sedes.dart`, `pantalla_sede.dart`, `tarjeta_cancha.dart` |
| La pantalla de horarios y reserva (CU-12) | `features/horarios/pantalla_horarios.dart` |
| Mis reservas, detalle y cancelación | `features/reservas/` |
| El perfil | `features/perfil/` |
| Login y registro | `features/auth/` |

### "¿Dónde está el home? ¿Y las reservas?" (layouts)

`PantallaPrincipal` (`features/shell/pantalla_principal.dart`) tiene **4 pestañas**, cada una con su propio `Navigator`: **Inicio, Sedes, Reservas y Perfil**. Las pantallas viven en `mobile/lib/features/`, una carpeta por flujo.

### "¿Cómo manejaste las reservas en el backend? ¿Lógica, archivos?"

Respuesta en una frase: *"Tres capas: el router recibe el pedido, el service aplica las reglas y el model habla con la base."*

| Capa | Archivo | Qué hace |
|---|---|---|
| Router | `backend/app/api/routers/reservas.py` | Define los endpoints (`POST /reservas`, listar, detalle, cancelar). Casi no tiene lógica. |
| Service | `backend/app/services/reservas.py` | **Las reglas de negocio.** `crear`, `listar`, `cancelar`, `estado_visible`. |
| Disponibilidad | `backend/app/services/disponibilidad.py` | `calcular_franjas` y `se_superponen`: el CU-12. |
| Schemas | `backend/app/schemas/reserva.py` | Qué entra y qué sale (validación con pydantic). |
| Model | `backend/app/models/reserva.py` | La tabla `reserva`, con restricciones en la propia base. |
| Auth | `backend/app/api/deps.py` | `get_usuario_actual`: quién hace el pedido. |

Reglas al reservar (en este orden): cancha activa → dentro del horario de la sede (`400 HORARIO_FUERA_DE_SEDE`) → en el futuro (`400 HORARIO_PASADO`) → bloqueo de la cancha → sin superposición (`409 HORARIO_OCUPADO`).

Reglas al cancelar: solo reservas **propias**, **confirmadas** y que **no hayan empezado**.

Dato útil: en la base solo se guardan los estados `confirmada` y `cancelada`; `en_curso` y `completada` se **calculan** según la hora, así nunca quedan desactualizados.

### Otras que pueden aparecer

- **¿Por qué FastAPI?** Liviano, rápido y genera Swagger solo.
- **¿Por qué Firebase para el login?** Delegar las contraseñas a un servicio probado. Mi base solo guarda el `firebase_uid`.
- **¿Qué pasa si se cae internet?** La app muestra una tarjeta "Error de conectividad" con reintentar. Los errores se traducen en `core/errores.dart`.
- **¿Cómo probaron todo?** 149 tests en el backend (`pytest`) y 121 en la app (`flutter test`), con Firebase y la API simulados. Además, pruebas manuales en el emulador contra Firebase y FCM reales.
- **¿Qué falta o qué limitaciones hay?** Decirlas antes: están en la sección 11 de [`GUIA-DEL-CODIGO.md`](GUIA-DEL-CODIGO.md). Las más importantes: solo Android; Render gratis se duerme y la base vence a los 30 días; la encuesta de salida de la baja no guarda las respuestas; algunos precios son estimados.

Más preguntas con respuesta: sección 9 de [`GUIA-DEL-CODIGO.md`](GUIA-DEL-CODIGO.md).

---

## 4. Si algo sale mal en vivo

| Qué pasa | Qué hacer |
|---|---|
| La app queda cargando mucho tiempo | La API estaba dormida. Esperar hasta ~1 minuto; es el primer pedido. Explicarlo: *"Render gratis se duerme."* |
| Error "sin conexión" en la app | Revisar internet del emulador y abrir `/health` en el navegador. |
| El login falla | Verificar usuario y contraseña; si venció la sesión, la app vuelve sola al login. |
| pgAdmin no conecta | Comprobar SSL en `Require` y que la contraseña sea la actual de `club-db`. |
| No llega el push | Ver que el emulador sea el de Google Play, que el permiso de notificaciones esté concedido y que haya una fila en `dispositivo`. |
| Render no responde | Plan B del inicio: backend local. |

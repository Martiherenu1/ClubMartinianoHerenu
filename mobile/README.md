# App móvil — ClubMartinianoHerenu

Aplicación en **Flutter** para reservar canchas. Se conecta a la API REST del
backend (`../backend`) y usa **Firebase Authentication** para el login.

## Requisitos

- Flutter SDK 3.47 o superior (`flutter doctor` sin errores de Android).
- Un emulador Android con Google Play (o un celular con depuración USB).
- El backend corriendo (ver `../backend/README.md`).

## Puesta en marcha

```bash
cd mobile
flutter pub get
flutter run
```

Por defecto la app apunta a la API local en `http://10.0.2.2:8000`: `10.0.2.2` es
la dirección con la que el emulador de Android ve el `localhost` de la PC.

Para apuntar a otra API (por ejemplo la de Render):

```bash
flutter run --dart-define=API_URL=https://mi-api.onrender.com
```

> El HTTP sin cifrar solo está permitido en la versión **debug**
> (`android/app/src/debug/AndroidManifest.xml`). La versión release exige HTTPS.

## Estructura

```
lib/
├── main.dart                     # punto de entrada
├── app/
│   ├── app.dart                  # MaterialApp, providers, modo claro/oscuro
│   ├── tema.dart                 # colores y tipografías del Figma
│   └── controlador_tema.dart     # modo claro/oscuro recordado en el celular
├── core/
│   ├── config.dart               # URL de la API
│   ├── api_client.dart           # cliente HTTP: token, timeout y errores
│   └── errores.dart              # SinConexion, ErrorServidor, NoAutenticado, ErrorNegocio
│   └── formato.dart              # precios, fechas, horas y etiquetas ($ 3.800, sáb, 15 ago)
├── data/                         # modelos y llamadas a la API
│   ├── usuarios_api.dart
│   ├── catalogo_api.dart         # sedes, canchas, filtros
│   └── reservas_api.dart
├── widgets/                      # piezas compartidas
│   ├── barra_inferior.dart       # Inicio · Sedes · Reservas · Perfil
│   ├── carga_async.dart          # cargando / error + reintentar / datos
│   ├── etiquetas.dart            # chips de deporte, tipo y condición
│   ├── imagen_catalogo.dart      # fotos de sedes y canchas
│   └── tarjeta_error.dart        # tarjetas "Error de conectividad / del servidor"
└── features/                     # una carpeta por pantalla/flujo
    ├── auth/                     # login, registro, recuperar contraseña
    ├── shell/                    # estructura con la barra inferior
    ├── inicio/                   # Home
    ├── sedes/                    # todas las sedes, detalle de sede, tarjeta de cancha
    ├── horarios/                 # (provisoria) CU-12
    ├── reservas/                 # (provisoria) mis reservas
    └── perfil/                   # (provisoria) perfil
```

## Manejo de errores

`ApiClient` traduce cualquier problema a un error que la interfaz sabe mostrar:

| Situación | Error | Qué muestra la app |
|---|---|---|
| Sin internet, sin red o el servidor no responde a tiempo | `SinConexion` | Tarjeta "Error de conexión a Internet" |
| El servidor falla (5xx) o responde algo inesperado | `ErrorServidor` | Tarjeta "Error del servidor" |
| Token vencido o cuenta dada de baja (401) | `NoAutenticado` | Vuelve al login |
| Regla de negocio (400, 404, 409, 422) | `ErrorNegocio` | Mensaje de la API, ej. "El horario seleccionado ya no está disponible" |

## Tests

```bash
flutter analyze
flutter test
```

## Configuración de Firebase

La app inicia sesión directo con **Firebase Authentication** (email y contraseña).

1. En la consola de Firebase, registrar una app **Android** con el paquete
   `com.martinianoherenu.club_martinianoherenu`.
2. Descargar `google-services.json` y copiarlo en `mobile/android/app/`.
   **No se versiona** (está en `.gitignore`).
3. En **Authentication → Método de acceso**, habilitar **Correo electrónico/contraseña**.

El plugin `com.google.gms.google-services` (en `android/settings.gradle.kts` y
`android/app/build.gradle.kts`) lee ese archivo; en `main.dart`, `Firebase.initializeApp()`
no necesita más configuración.

## Autenticación y navegación

```
AppClub
 └─ AuthGate ── escucha ServicioAuth.cambios (Firebase authStateChanges)
      ├─ sin sesión → PantallaLogin ─┬─ PantallaRegistro   (POST /usuarios)
      │                              └─ PantallaRecuperar  (Firebase: enlace por email)
      └─ con sesión → PantallaPrincipal (barra inferior, ver abajo)
```

- **Login (CU-01):** valida campos vacíos sin llamar al servidor; credenciales
  inválidas dan un mensaje genérico (no revela cuál dato falló); sin conexión y
  error del servidor abren las tarjetas del Figma.
- **Registro (CU-03):** pasa por la API (valida DNI y email duplicados y crea la
  cuenta en Firebase). Al terminar, vuelve al login.
- **Recuperar contraseña:** Firebase manda el email; si el email no tiene cuenta se
  responde igual, para no revelar qué emails están registrados.
- Un `401` de la API (token vencido o cuenta dada de baja) cierra la sesión y vuelve al login.

## Pantallas con sesión (Home, Sedes y Canchas)

```
PantallaPrincipal ── barra inferior, cada pestaña con su propio Navigator
 ├─ Inicio   → PantallaInicio   saludo, próxima reserva, filtro por deporte, sedes
 ├─ Sedes    → PantallaSedes ──→ PantallaSede ──→ PantallaHorarios (CU-12 + CU-09)
 ├─ Reservas → (provisoria)
 └─ Perfil   → (provisoria)
```

- **Barra inferior persistente:** al entrar al detalle de una sede la barra sigue
  visible (como en el Figma) y cada pestaña conserva su pila al cambiar de una a otra.
  El botón Atrás cierra lo apilado, después vuelve a Inicio y recién ahí sale de la app.
- **Home:** `GET /usuarios/me`, `/sedes` y `/reservas` en paralelo. Los chips de
  deporte vuelven a pedir `/sedes?deporte=`. Tocar una sede la abre en la pestaña Sedes.
- **Sede:** primero se elige el deporte y debajo el tipo; cada cambio vuelve a pedir
  `/espacios?sede_id=&deporte=&tipo=` (CU-20). Los tipos salen de la propia sede.
- **Fotos:** las del Figma viajan en `assets/images`. La API tiene `imagen_url` por
  sede: si algún día viene cargada, se usa esa.
- **Modo claro y oscuro:** las tarjetas, bordes y texto salen de `ColoresDeContexto`
  (`app/tema.dart`), así cada pantalla respeta el modo elegido.

## Horarios y reserva (CU-12 y CU-09)

`PantallaHorarios` junta en una sola pantalla, como el Figma: cancha, fecha,
duración, grilla de franjas, resumen y botón.

- **Cada cambio consulta la API** (`GET /espacios/{id}/disponibilidad?fecha=&duracion=`):
  cancha, fecha (hoy y 13 días más) o duración. La disponibilidad nunca se calcula en la app.
- **Franjas:** se muestran todas; las `ocupado` o `pasado` quedan deshabilitadas y no se
  pueden tocar. Debajo, el aviso "Algunos horarios están ocupados · N no disponibles".
- **Sin turnos (FA4):** "No hay horarios disponibles" y el botón queda deshabilitado.
- **Resumen:** `precio_hora × duración`, total y franja elegida. Es solo informativo.
- **Confirmar:** `POST /reservas` y pantalla "¡Reserva confirmada!", que a los 2 s lleva
  a la pestaña Reservas. La Home vuelve a pedir sus datos (`ReservasCambiadas`).
- **Si alguien tomó el horario antes (409 `HORARIO_OCUPADO`):** aviso con el mensaje de
  la API, se limpia la elección y la grilla se actualiza.
- **Sin conexión o error del servidor:** tarjeta del Figma; al confirmar se conserva la
  elección para reintentar.

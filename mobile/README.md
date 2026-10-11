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
└── features/                     # una carpeta por pantalla/flujo
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
      └─ con sesión → PantallaInicio (GET /usuarios/me con el ID token)
```

- **Login (CU-01):** valida campos vacíos sin llamar al servidor; credenciales
  inválidas dan un mensaje genérico (no revela cuál dato falló); sin conexión y
  error del servidor abren las tarjetas del Figma.
- **Registro (CU-03):** pasa por la API (valida DNI y email duplicados y crea la
  cuenta en Firebase). Al terminar, vuelve al login.
- **Recuperar contraseña:** Firebase manda el email; si el email no tiene cuenta se
  responde igual, para no revelar qué emails están registrados.
- Un `401` de la API (token vencido o cuenta dada de baja) cierra la sesión y vuelve al login.

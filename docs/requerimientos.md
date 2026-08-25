# Requerimientos — resumen del enunciado

Fuente: "Trabajo Práctico_2026" (Univ. de Morón, Electiva General, Doc. Marcelo Camicha).

## Funcionales

1. **Auth**
   - Registro con email + contraseña.
   - Home Page tras iniciar sesión.
   - Recuperación / cambio de contraseña seguro.

2. **Perfil de usuario**
   - Mostrar y editar todos los datos, **salvo el email**.
   - Mínimo: nombre, apellido, fecha de nacimiento.
   - Cerrar sesión.

3. **Gestión de reservas** (núcleo del sistema)
   - Reserva = espacio deportivo + fecha + hora inicio + hora fin.
   - Duración mínima **1 hora**; inicio y fin en **minuto 00** (horas completas).
   - Dentro del **horario de funcionamiento de la sede**; fin ≤ horario de cierre.
   - Solo **horarios futuros**.
   - **Backend valida solapamiento**: no se permite doble reserva del mismo espacio
     con horarios superpuestos en la misma fecha.
   - Consultar disponibilidad por sede.
   - Listar reservas del usuario (sede, espacio, fecha, horario).
   - Cancelar reserva → el horario vuelve a estar disponible.
   - Notificaciones push de reservas próximas.

4. **Módulo de Sedes**
   - Mínimo: nombre, dirección, horarios de funcionamiento.
   - Listar sedes y seleccionar una para ver sus espacios y horarios disponibles.

5. **Módulo de Espacios deportivos**
   - Listar espacios indicando su sede.
   - Cada espacio: asociado a una sede, con **tipo** y **nombre compuesto**
     `Sede_Direccion_Tipo_Numero` (ej: `Moron_Rivadavia_19850_Paddle_1`).
   - Filtrar por tipo (Fútbol, Paddle, Básquet, etc.).

6. **Historial de reservas**
   - Incluye reservas ya finalizadas.

7. **Manejo de errores**
   - Sin conexión, servidor caído, login incorrecto, usuario ya registrado, etc.

8. **Nombre app** = `Club[Nombre y Apellido]` → `ClubMartinianoHerenu`.
9. **Nombre repo GitHub** = igual al de la app.

## No funcionales

1. UX/UI en **Figma**; app en **Flutter**.
2. **Repo GitHub** propio, con commits durante el desarrollo (el historial se evalúa).
3. **REST API** documentada con **Swagger/OpenAPI**. Lenguaje libre (preferente Python).
4. **BBDD relacional** (preferente PostgreSQL).
5. **Cloud:** API + DB en la nube (Render). Auth y push con Firebase.
   La API debe **identificar al usuario autenticado** en operaciones de usuarios/reservas.
6. **README** en app y backend con pasos de configuración, ejecución y deploy.

## Entregables

- **Entrega 1 (Diseño):** mockup + prototipo navegable en Figma. Defensa grupal. Doc a Blackboard.
- **Entrega 2 (Desarrollo):** backend desplegado + app conectada, ícono, auth,
  gestión de reservas, modelo de datos, manejo de errores, demo en emulador.
  Backend (ZIP) + app (ZIP) a Blackboard. Defensa individual.

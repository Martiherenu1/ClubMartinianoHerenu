# CU-12 — Consultar horarios disponibles (implementación)

> Caso de uso de Martiniano Hereñu. Este documento explica cómo lo resuelve el
> backend, para la defensa individual de la Entrega 2.

## Endpoint

```
GET /api/v1/espacios/{espacio_id}/disponibilidad?fecha=2026-10-15&duracion=1
Authorization: Bearer <ID token de Firebase>
```

| Parámetro | Valores | Si es inválido |
|---|---|---|
| `espacio_id` | id de una cancha activa | 404 `ESPACIO_NO_ENCONTRADO` |
| `fecha` | `AAAA-MM-DD`, hoy o futura | 422 si el formato es malo, 400 `FECHA_PASADA` si ya pasó |
| `duracion` | `1` o `2` (horas); por defecto `1` | 422 `DATOS_INVALIDOS` |

Es **solo lectura**: consultar no reserva nada (la reserva es el CU-09).

## Respuesta (lo que dibuja la pantalla del Figma)

```json
{
  "espacio": { "nombre_compuesto": "Moron_Rivadavia_17500_Futbol_F5_1", "tipo": "F5", "numero": 1, "...": "..." },
  "fecha": "2026-10-15",
  "duracion": 1,
  "precio_hora": 3800,
  "precio_total": 3800,
  "cantidad_disponibles": 14,
  "cantidad_no_disponibles": 1,
  "franjas": [
    { "hora_inicio": "08:00:00", "hora_fin": "09:00:00", "disponible": true,  "motivo": null },
    { "hora_inicio": "18:00:00", "hora_fin": "19:00:00", "disponible": false, "motivo": "ocupado" }
  ]
}
```

| Elemento del Figma | Dato de la respuesta |
|---|---|
| Grilla de botones de horario | `franjas` (la app muestra las `disponible: true`) |
| "Algunos horarios están ocupados · 5 no disponibles" | `cantidad_no_disponibles` |
| Resumen "$ 3.800 × 1" y "Total $ 3.800" | `precio_hora`, `duracion`, `precio_total` |
| Estado vacío "No hay horarios disponibles" (FA4) | `cantidad_disponibles == 0` |
| Cambio de fecha, cancha o duración (FA1–FA3) | la app vuelve a llamar con otro `fecha`, `espacio_id` o `duracion` |
| Error de conexión / del servidor (FA5–FA6) | la app no recibe respuesta o recibe un 5xx |

## Algoritmo (`app/services/disponibilidad.py`)

La disponibilidad **no se guarda**: se calcula en cada consulta con tres datos.

1. **Horario de la sede**, por ejemplo Morón de 08:00 a 23:00.
2. **Duración** elegida: 1 o 2 horas.
3. **Reservas confirmadas** de esa cancha en esa fecha. Las canceladas no cuentan,
   porque cancelar libera el horario (CU-10).

Pasos:

1. Se arman franjas **de hora en hora** desde la apertura. La última es la que
   termina justo al cierre, porque el TP no permite reservas que se pasen del cierre.
   - 1 h en Morón: 08–09, 09–10, …, 22–23 → **15 franjas**.
   - 2 h en Morón: 08–10, 09–11, …, 21–23 → **14 franjas**.
2. Cada franja se marca **no disponible** si:
   - **se superpone** con una reserva confirmada → `motivo: "ocupado"`;
   - es **de hoy y ya empezó** → `motivo: "pasado"`. El TP pide reservas futuras.
3. Regla de superposición: dos rangos `[a, b)` y `[c, d)` se pisan si `a < d` y `c < b`.
   - 18–19 y 19–20 **no** se pisan: una termina cuando empieza la otra.
   - Con 2 h, una reserva de 18–19 bloquea las franjas 17–19 y 18–20.

`calcular_franjas()` es una **función pura**: recibe todo por parámetro y no toca ni
la base ni el reloj. Por eso se puede probar con cualquier caso sin preparar datos.

## Hora de Argentina

"Hoy" y "ya empezó" se calculan con `app/core/tiempo.ahora()`, en
`America/Argentina/Buenos_Aires`. Render corre en UTC: sin esto, a partir de las
21:00 la API pensaría que ya es el día siguiente.

## Tests (`backend/tests/test_disponibilidad.py`)

El reloj se fija en el **miércoles 14/10/2026 a las 15:30**, así el resultado no
depende del día en que se corren. Hay 22 tests:

- **Grilla:** 15 franjas con 1 h y 14 con 2 h.
- **Reservas:** una reserva ocupa su franja; con 2 h bloquea las dos franjas que la pisan; una reserva de 2 h bloquea dos franjas de 1 h.
- **Qué no cuenta:** las canceladas no ocupan, y las reservas de otra cancha no afectan.
- **Hoy:** a las 15:30, las 8 franjas de 08 a 16 figuran como pasadas.
- **Día completo:** 0 disponibles (estado vacío, FA4).
- **Otra sede:** Ramos Mejía abre de 09 a 22, así que da 13 franjas.
- **Errores:** fecha pasada (400), duración 0 o 3, fecha mal escrita o faltante (422), cancha inexistente (404) y sin sesión (401).

## Cómo lo usa la app

`mobile/lib/features/horarios/pantalla_horarios.dart` (ver `mobile/README.md`):

- Cada cambio de cancha, fecha o duración vuelve a llamar a este endpoint (FA1–FA3).
- Se muestran **todas** las franjas: las `ocupado` y `pasado` quedan deshabilitadas, como
  en el diseño propio del CU-12 ("Consulta"). El Figma grupal solo muestra las libres.
- `cantidad_disponibles == 0` → estado vacío "No hay horarios disponibles" (FA4).
- Error de red o 5xx → tarjeta "Error de conectividad" / "Error del servidor" con
  "Reintentar" (FA5–FA6).
- La reserva (`POST /reservas`) se hace desde la misma pantalla; es el CU-09.

/// Llamadas a la API del catálogo: sedes, canchas y deportes (CU-13, CU-16, CU-20).
library;

import '../core/api_client.dart';
import '../core/formato.dart';

/// Un deporte con los tipos de cancha que hay (para los chips de filtro).
class DeporteConTipos {
  const DeporteConTipos({required this.deporte, required this.tipos});

  factory DeporteConTipos.fromJson(Map<String, dynamic> json) => DeporteConTipos(
        deporte: json['deporte'] as String,
        tipos: (json['tipos'] as List).cast<String>(),
      );

  final String deporte;
  final List<String> tipos;
}

/// Datos mínimos de la sede que acompañan a cada cancha.
class SedeResumen {
  const SedeResumen({required this.id, required this.nombre, required this.direccion});

  factory SedeResumen.fromJson(Map<String, dynamic> json) => SedeResumen(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        direccion: json['direccion'] as String,
      );

  final int id;
  final String nombre;
  final String direccion;
}

class Sede {
  const Sede({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.horaApertura,
    required this.horaCierre,
    required this.imagenUrl,
    required this.cantidadCanchas,
    required this.deportes,
  });

  factory Sede.fromJson(Map<String, dynamic> json) => Sede(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        direccion: json['direccion'] as String,
        horaApertura: recortarHora(json['hora_apertura'] as String),
        horaCierre: recortarHora(json['hora_cierre'] as String),
        imagenUrl: json['imagen_url'] as String?,
        cantidadCanchas: json['cantidad_canchas'] as int,
        deportes: (json['deportes'] as List)
            .map((d) => DeporteConTipos.fromJson(d as Map<String, dynamic>))
            .toList(),
      );

  final int id;
  final String nombre;
  final String direccion;
  final String horaApertura;
  final String horaCierre;
  final String? imagenUrl;
  final int cantidadCanchas;
  final List<DeporteConTipos> deportes;

  /// "SEDE MORÓN", como en los títulos del Figma.
  String get titulo => 'SEDE ${nombre.toUpperCase()}';

  /// Deportes de la sede en el orden del Figma (Fútbol, Tenis, Golf, Hockey, Vóley).
  List<String> get nombresDeportes =>
      ordenarDeportes(deportes.map((d) => d.deporte));
}

class Espacio {
  const Espacio({
    required this.id,
    required this.sede,
    required this.deporte,
    required this.tipo,
    required this.numero,
    required this.nombreCompuesto,
    required this.cubierto,
    required this.iluminacion,
    required this.precioHora,
    required this.horaApertura,
    required this.horaCierre,
  });

  factory Espacio.fromJson(Map<String, dynamic> json) => Espacio(
        id: json['id'] as int,
        sede: SedeResumen.fromJson(json['sede'] as Map<String, dynamic>),
        deporte: json['deporte'] as String,
        tipo: json['tipo'] as String,
        numero: json['numero'] as int,
        nombreCompuesto: json['nombre_compuesto'] as String,
        cubierto: json['cubierto'] as bool,
        iluminacion: json['iluminacion'] as bool,
        precioHora: (json['precio_hora'] as num).toDouble(),
        horaApertura: recortarHora(json['hora_apertura'] as String),
        horaCierre: recortarHora(json['hora_cierre'] as String),
      );

  final int id;
  final SedeResumen sede;
  final String deporte;
  final String tipo;
  final int numero;
  final String nombreCompuesto;
  final bool cubierto;
  final bool iluminacion;
  final double precioHora;
  final String horaApertura;
  final String horaCierre;
}

class CatalogoApi {
  const CatalogoApi(this._api);

  final ApiClient _api;

  /// `GET /sedes`. Con [deporte] solo trae las sedes que lo ofrecen.
  Future<List<Sede>> sedes({String? deporte}) async {
    final json = await _api.get('/sedes', query: {'deporte': deporte});
    return (json as List).map((s) => Sede.fromJson(s as Map<String, dynamic>)).toList();
  }

  /// `GET /espacios`. Los filtros se combinan.
  Future<List<Espacio>> espacios({int? sedeId, String? deporte, String? tipo}) async {
    final json = await _api.get('/espacios', query: {
      'sede_id': sedeId?.toString(),
      'deporte': deporte,
      'tipo': tipo,
    });
    return (json as List).map((e) => Espacio.fromJson(e as Map<String, dynamic>)).toList();
  }
}

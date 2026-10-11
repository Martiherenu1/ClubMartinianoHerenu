/// Autenticación con Firebase Authentication.
///
/// La app inicia sesión DIRECTO contra Firebase (la contraseña nunca pasa por
/// nuestra API). Firebase devuelve un ID token que `ApiClient` manda en cada
/// request y que el backend verifica con el Admin SDK.
///
/// `ServicioAuth` es una interfaz para poder reemplazar Firebase en los tests.
library;

import 'package:firebase_auth/firebase_auth.dart';

import 'errores.dart';

class UsuarioSesion {
  const UsuarioSesion({required this.uid, this.email});

  final String uid;
  final String? email;
}

abstract interface class ServicioAuth {
  /// Emite el usuario actual cada vez que se inicia o cierra sesión
  /// (`null` = sin sesión). Es lo que escucha el `AuthGate`.
  Stream<UsuarioSesion?> get cambios;

  UsuarioSesion? get actual;

  /// ID token vigente (Firebase lo renueva solo), o `null` sin sesión.
  Future<String?> idToken();

  Future<void> iniciarSesion(String email, String password);

  Future<void> cerrarSesion();

  /// Manda el email para restablecer la contraseña.
  Future<void> enviarEnlaceRecuperacion(String email);
}

/// Traduce un error de Firebase a un [ErrorApp] que la interfaz sabe mostrar.
ErrorApp traducirErrorFirebase(FirebaseAuthException e) {
  switch (e.code) {
    case 'network-request-failed':
      return const SinConexion();
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
    case 'invalid-email':
    case 'user-disabled':
      return const CredencialesInvalidas();
    case 'too-many-requests':
      return const ErrorNegocio(
        codigo: 'DEMASIADOS_INTENTOS',
        mensaje: 'Demasiados intentos. Esperá unos minutos e intentá de nuevo.',
        status: 429,
      );
    default:
      return const ErrorServidor();
  }
}

class AuthFirebase implements ServicioAuth {
  AuthFirebase({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  static UsuarioSesion? _convertir(User? u) =>
      u == null ? null : UsuarioSesion(uid: u.uid, email: u.email);

  @override
  Stream<UsuarioSesion?> get cambios => _auth.authStateChanges().map(_convertir);

  @override
  UsuarioSesion? get actual => _convertir(_auth.currentUser);

  @override
  Future<String?> idToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } on FirebaseAuthException catch (e) {
      throw traducirErrorFirebase(e);
    }
  }

  @override
  Future<void> iniciarSesion(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw traducirErrorFirebase(e);
    }
  }

  @override
  Future<void> cerrarSesion() => _auth.signOut();

  @override
  Future<void> enviarEnlaceRecuperacion(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      // Si el email no tiene cuenta se responde igual que si la tuviera: así no
      // se puede averiguar qué emails están registrados.
      if (e.code == 'user-not-found') return;
      throw traducirErrorFirebase(e);
    }
  }
}

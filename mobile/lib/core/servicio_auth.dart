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

  /// Cambia la contraseña de la cuenta con sesión (CU-04). Firebase pide
  /// confirmar la contraseña actual antes de aceptar la nueva.
  ///
  /// Si la actual no es correcta lanza un [ErrorNegocio] con código
  /// [codigoPasswordActualIncorrecta].
  Future<void> cambiarPassword({required String actual, required String nueva});
}

/// Código del [ErrorNegocio] que se lanza al confirmar una contraseña actual
/// equivocada.
const codigoPasswordActualIncorrecta = 'PASSWORD_ACTUAL_INCORRECTA';

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

  @override
  Future<void> cambiarPassword({required String actual, required String nueva}) async {
    final usuario = _auth.currentUser;
    final email = usuario?.email;
    if (usuario == null || email == null) {
      throw const NoAutenticado('Tu sesión expiró. Volvé a iniciar sesión.');
    }
    try {
      await usuario.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: actual),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw const ErrorNegocio(
          codigo: codigoPasswordActualIncorrecta,
          mensaje: 'La contraseña actual no es correcta.',
          status: 400,
        );
      }
      throw traducirErrorFirebase(e);
    }
    try {
      await usuario.updatePassword(nueva);
    } on FirebaseAuthException catch (e) {
      throw traducirErrorFirebase(e);
    }
  }
}

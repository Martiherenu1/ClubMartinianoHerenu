import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/servicio_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // En Android toma la configuración de android/app/google-services.json.
  await Firebase.initializeApp();
  runApp(AppClub(auth: AuthFirebase()));
}

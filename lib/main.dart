import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:saarthi2025/pages/login_page.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
    
  // Configure Firebase for web
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyA1Os5lHZqiaRRdBsZm1cO1JsX7sdrYgk0",
        authDomain: "study-76861.firebaseapp.com",
        projectId: "study-76861",
        storageBucket: "study-76861.firebasestorage.app",
        messagingSenderId: "230162719736",
        appId: "1:230162719736:web:9160e32815ca50a230ac0d"
      ),
    );
  } else {

      await Firebase.initializeApp();
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Department App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
import 'package:flutter/material.dart';
import 'main_navigation.dart';
import 'services/api_service.dart';
import 'welcome_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zidash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF66C665),
          primary: const Color(0xFF66C665),
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<bool> _hasCompletedSignup;

  @override
  void initState() {
    super.initState();
    _hasCompletedSignup = ApiService.instance.hasCompletedSignup();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasCompletedSignup,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: SizedBox.expand(
              child: Image(
                image: AssetImage('assets/splashscreen2.png'),
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          );
        }

        if (snapshot.data == true) return const MainNavigation();
        return const WelcomeScreen();
      },
    );
  }
}

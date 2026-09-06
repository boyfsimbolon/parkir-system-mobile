import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'session.dart';
import 'screens/activation_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('id_ID');
  final session = SessionManager();
  await session.load();
  runApp(ParkirApp(session: session));
}

class SessionScope extends InheritedNotifier<SessionManager> {
  const SessionScope({super.key, required SessionManager session, required super.child})
      : super(notifier: session);

  static SessionManager of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}

class ParkirApp extends StatelessWidget {
  final SessionManager session;
  const ParkirApp({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: session,
      child: MaterialApp(
        title: 'Parkir Getter',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
          useMaterial3: true,
        ),
        home: AnimatedBuilder(
          animation: session,
          builder: (context, _) {
            if (!session.loaded) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return session.loggedIn ? const HomeScreen() : const ActivationScreen();
          },
        ),
      ),
    );
  }
}

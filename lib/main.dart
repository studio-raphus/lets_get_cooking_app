// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lets_get_cooking_app/providers/grocery_provider.dart';
import 'package:lets_get_cooking_app/screens/home_screen.dart';
import 'package:lets_get_cooking_app/screens/welcome_screen.dart';
import 'package:lets_get_cooking_app/secrets.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/premium_provider.dart';
import 'providers/recipe_provider.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: Secrets.supabaseUrl,
    anonKey: Secrets.supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PremiumProvider()),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => GroceryProvider()),
      ],
      child: MaterialApp(
        title: 'Recipe Action',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _supabase = Supabase.instance.client;
  bool _dataInitialized = false;

  @override
  void initState() {
    super.initState();

    // FIX 1: Check for an already-active session immediately at startup.
    // The StreamBuilder won't fire synchronously for a restored session,
    // so we must check the current session proactively here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final existingSession = _supabase.auth.currentSession;
      if (existingSession != null && !_dataInitialized) {
        _initializeData(existingSession.user.id);
      }
    });

    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      if (session != null && mounted) {
        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.initialSession) {
          if (!_dataInitialized) {
            _initializeData(session.user.id);
          }
        }

        if (event == AuthChangeEvent.tokenRefreshed && _dataInitialized) {
          context.read<PremiumProvider>().checkPremiumStatus();
        }
      }

      if (event == AuthChangeEvent.signedOut) {
        _dataInitialized = false;
      }
    });
  }

  Future<void> _initializeData(String userId) async {
    if (!mounted) return;
    _dataInitialized = true;
    context.read<PremiumProvider>().initialize(userId);
    context.read<RecipeProvider>().loadRecipes();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final hasSession = (snapshot.hasData && snapshot.data?.session != null)
            || _supabase.auth.currentSession != null;

        if (hasSession) {
          return const HomeScreen();
        }
        return const WelcomeScreen();
      },
    );
  }
}
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
  // 1. Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Load the .env file
  await dotenv.load(fileName: ".env");

  // 3. Now it is safe to access Secrets.supabaseUrl
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

  @override
  void initState() {
    super.initState();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null && mounted) {
        _initializeData(session.user.id);
      }
    });
  }

  Future<void> _initializeData(String userId) async {
    context.read<PremiumProvider>().initialize(userId);
    context.read<RecipeProvider>().loadRecipes();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data?.session != null) {
          return const HomeScreen();
        }

        return const WelcomeScreen();
      },
    );
  }
}


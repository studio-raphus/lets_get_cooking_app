import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lets_get_cooking_app/screens/login_screen.dart';
import 'package:lets_get_cooking_app/theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _time = 0.0;
  bool _showFeatures = false; // Toggles between Splash and Features list

  // Shader state
  ui.FragmentProgram? _program;

  // Features Data (From Old Screen)
  final List<OnboardingData> _features = [
    OnboardingData(
      illustration: '🍲',
      title: 'Save Any Recipe',
      description: 'From TikTok, Instagram, YouTube, or any recipe site. Just paste the link.',
    ),
    OnboardingData(
      illustration: '📝',
      title: 'AI-Powered Lists',
      description: 'Turn videos instantly into organized grocery lists. No more pausing and rewinding.',
    ),
    OnboardingData(
      illustration: '🥗',
      title: 'Plan & Cook',
      description: 'Organize meals for the week, generate one master list, and actually cook what you save.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadShader();
    _ticker = createTicker((elapsed) {
      setState(() {
        _time = elapsed.inMilliseconds / 1000.0;
      });
    })..start();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('lib/shaders/cinematic_blur.frag');
      setState(() {
        _program = program;
      });
    } catch (e) {
      debugPrint("Shader failed to load: $e");
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _showFeatureCards() {
    setState(() {
      _showFeatures = true;
    });
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.seedColor,
      body: Stack(
        children: [
          // 1. The Background Shader (Persistent)
          if (_program != null)
            Positioned.fill(
              child: CustomPaint(
                painter: ShaderPainter(
                  program: _program!,
                  time: _time,
                ),
              ),
            ),

          // 2. Content Overlay
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              reverseDuration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              transitionBuilder: (child, animation) {
                // Slight slide up + fade effect
                final offsetAnimation = Tween<Offset>(
                  begin: const Offset(0.0, 0.05),
                  end: Offset.zero,
                ).animate(animation);

                return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offsetAnimation, child: child)
                );
              },
              child: _showFeatures ? _buildFeaturesList() : _buildCinematicSplash(),
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. SPLASH SCREEN ---
  Widget _buildCinematicSplash() {
    return SizedBox.expand(
      key: const ValueKey('splash'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Text(
            "Let's Get\nCooking",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: AppTheme.seedColor,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Visual. Viral. Delicious.",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.seedColor,
              fontWeight: FontWeight.w100,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),

          Padding(
            padding: const EdgeInsets.only(bottom: 50.0),
            child: FilledButton.icon(
              onPressed: _showFeatureCards,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.seedColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text("START"),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. FEATURES LIST (HERO CARDS) ---
  Widget _buildFeaturesList() {
    final theme = Theme.of(context);

    return Column(
      key: const ValueKey('features'),
      children: [
        const SizedBox(height: 20),
        Text(
          "What's Inside",
          style: theme.textTheme.headlineMedium?.copyWith(
            color: AppTheme.seedColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),

        // Scrollable Card List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            itemCount: _features.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final data = _features[index];
              return _buildHeroCard(data);
            },
          ),
        ),

        // Bottom Action
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.0),
                Colors.white.withOpacity(0.5),
              ],
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _navigateToLogin,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.seedColor,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("CREATE ACCOUNT", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(OnboardingData data) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.8), // Glassmorphic
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.seedColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Illustration / Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              data.illustration,
              style: const TextStyle(fontSize: 32),
            ),
          ),
          const SizedBox(width: 16),

          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.seedColor,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- DATA MODEL ---
class OnboardingData {
  final String illustration;
  final String title;
  final String description;

  OnboardingData({
    required this.illustration,
    required this.title,
    required this.description,
  });
}

// --- SHADER PAINTER ---
class ShaderPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final double time;

  ShaderPainter({required this.program, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();
    shader.setFloat(0, time);
    shader.setFloat(1, size.width);
    shader.setFloat(2, size.height);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant ShaderPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.program != program;
  }
}
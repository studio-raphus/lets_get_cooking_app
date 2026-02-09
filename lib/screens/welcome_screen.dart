import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:lets_get_cooking_app/models/recipe.dart';
import 'package:lets_get_cooking_app/screens/login_screen.dart';
import 'package:lets_get_cooking_app/services/ai_recipe_extractor.dart';
import 'package:lets_get_cooking_app/theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _time = 0.0;
  bool _isDemoMode = false; // Tracks if we are in "Splash" or "Interactive" mode

  // Input Controller
  final TextEditingController _linkController = TextEditingController();

  // Shader state
  ui.FragmentProgram? _program;

  // AI & Logic State
  final AIRecipeExtractor _aiService = AIRecipeExtractor();
  bool _isProcessing = false;
  Recipe? _generatedRecipe;
  bool _hasUsedFreeTrial = false; // The "One Time Only" Lock
  String? _errorMessage;

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
      // Ensure 'shaders/cinematic_blur.frag' is declared in pubspec.yaml
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
    _linkController.dispose();
    super.dispose();
  }

  void _startApp() {
    setState(() {
      _isDemoMode = true;
    });
  }

  Future<void> _handleGenerateAction() async {
    // 1. If user already used the free trial, force login
    if (_hasUsedFreeTrial) {
      _navigateToLogin();
      return;
    }

    // 2. Validate Input
    final url = _linkController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = "Please paste a link first.");
      return;
    }

    // 3. Start Processing
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // 4. CALL REAL AI SERVICE
      final recipe = await _aiService.extractFromUrl(url);

      if (mounted) {
        setState(() {
          _generatedRecipe = recipe;
          _hasUsedFreeTrial = true; // Lock the feature
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = "Could not extract recipe. Try a different link.";
        });
      }
    }
  }

  void _navigateToLogin() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.seedColor,
      resizeToAvoidBottomInset: true,
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
                return FadeTransition(opacity: animation, child: child);
              },
              child: _isDemoMode ? _buildInteractiveMode() : _buildCinematicSplash(),
            ),
          ),
        ],
      ),
    );
  }

  // --- THE SPLASH SCREEN (Untouched as requested) ---
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
              onPressed: _startApp,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.seedColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text("START COOKING"),
            ),
          ),
        ],
      ),
    );
  }

  // --- THE INTERACTIVE DEMO (Themed & Functional) ---
  Widget _buildInteractiveMode() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      key: const ValueKey('interactive'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glassmorphism Card (Using App Theme Colors)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                // Use the Warm Surface color from AppTheme, but semi-transparent
                  color: colorScheme.surface.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(24),
                  // Border matches the secondary "Wheat" color
                  border: Border.all(color: colorScheme.secondary.withOpacity(0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Header ---
                  Text(
                    _generatedRecipe == null
                        ? "Try It Once, Free."
                        : "Recipe Extracted!",
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colorScheme.primary, // Forest Green text
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _generatedRecipe == null
                        ? "Paste a video link to see our AI generate a grocery list instantly."
                        : "We found ${_generatedRecipe!.ingredients.length} ingredients from your link.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Input / Result Area ---
                  if (_generatedRecipe == null) ...[
                    // Input Field (Themed)
                    TextField(
                      controller: _linkController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: "Paste TikTok or YouTube link...",
                        hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                        filled: true,
                        fillColor: colorScheme.surface, // Solid warm background for input
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colorScheme.primary, width: 2),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.paste, color: colorScheme.primary),
                          onPressed: () async {
                            // Simple clipboard logic would go here
                            // For now, user can type or paste manually
                            final data = await Clipboard.getData('text/plain');
                            if (data?.text != null) {
                              _linkController.text = data!.text!;
                            }
                          },
                        ),
                      ),
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: colorScheme.error, fontSize: 12),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isProcessing ? null : _handleGenerateAction,
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary, // Forest Green
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isProcessing
                            ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: colorScheme.onPrimary, strokeWidth: 2))
                            : const Text("GENERATE LIST", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else ...[
                    // --- Result View (Real Data) ---
                    Container(
                      height: 200, // Limit height
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(0),
                          itemCount: _generatedRecipe!.ingredients.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: colorScheme.outlineVariant),
                          itemBuilder: (context, index) {
                            final ing = _generatedRecipe!.ingredients[index];
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: Icon(Icons.check_circle, color: colorScheme.secondary, size: 20),
                              title: Text(
                                ing.item,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                "${ing.quantity} ${ing.unit}",
                                style: theme.textTheme.bodySmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Want to save this list?",
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    // "Create Account" Button (High Emphasis)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _navigateToLogin,
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text("CREATE FREE ACCOUNT TO SAVE"),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Skip button
            if (_generatedRecipe == null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: TextButton(
                  onPressed: _navigateToLogin,
                  child: Text(
                      "Skip to Login",
                      style: TextStyle(
                          color: AppTheme.seedColor, // Keeping white to contrast with Shader background
                          fontWeight: FontWeight.w100
                      )
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- The Painter that draws the Shader ---
class ShaderPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final double time;

  ShaderPainter({required this.program, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    // Uniforms: float uTime, vec2 uResolution (width, height)
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

// Helper for clipboard access if not importing services
// (Standard Flutter services allow this without extra package in newer versions,
// but for robustness in demo, the manual paste is safer)
class Clipboard {
  static Future<ClipboardData?> getData(String format) async {
    return null; // Placeholder: Add 'package:flutter/services.dart' to imports for real clipboard
  }
}
class ClipboardData { final String? text; ClipboardData({this.text}); }
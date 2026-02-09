import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lets_get_cooking_app/models/recipe.dart';
import 'package:lets_get_cooking_app/theme/app_theme.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class CookModeScreen extends StatefulWidget {
  final Recipe recipe;

  const CookModeScreen({Key? key, required this.recipe}) : super(key: key);

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen> with TickerProviderStateMixin {
  // Page Control
  late PageController _pageController;
  int _currentStep = 0;

  // Voice Control
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _lastWords = '';

  // Timer & Shader
  ui.FragmentProgram? _program;
  late Ticker _ticker;
  double _time = 0.0;

  Timer? _countdownTimer;
  int _timerDuration = 60 * 5; // Default 5 mins
  int _timerRemaining = 0;
  bool _isTimerRunning = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _speech = stt.SpeechToText();

    // Initialize things
    _initShader();
    _initVoice();

    // Ticker for Shader Animation
    _ticker = createTicker((elapsed) {
      setState(() {
        _time = elapsed.inMilliseconds / 1000.0;
      });
    })..start();
  }

  Future<void> _initShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('lib/shaders/magma_timer.frag');
      setState(() => _program = program);
    } catch (e) {
      debugPrint("Shader Error: $e");
    }
  }

  Future<void> _initVoice() async {
    // Request microphone permission first
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      bool available = await _speech.initialize(
        onStatus: (status) => debugPrint('Voice Status: $status'),
        onError: (errorNotification) => debugPrint('Voice Error: $errorNotification'),
      );
      if (available) {
        _startListening();
      }
    }
  }

  void _startListening() async {
    if (!_isTimerRunning) { // Don't listen if timer is beeping to avoid loops
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _lastWords = result.recognizedWords.toLowerCase();
            _processVoiceCommand(_lastWords);
          });
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
      );
      setState(() => _isListening = true);
    }
  }

  void _processVoiceCommand(String command) {
    if (command.contains('next')) {
      _nextStep();
      _lastWords = ''; // Reset to avoid double triggering
    } else if (command.contains('back') || command.contains('previous')) {
      _prevStep();
      _lastWords = '';
    } else if (command.contains('start timer')) {
      _startTimer(300); // Default 5 mins for demo
      _lastWords = '';
    } else if (command.contains('stop') || command.contains('cancel')) {
      _stopTimer();
      _lastWords = '';
    }
  }

  void _nextStep() {
    if (_currentStep < widget.recipe.instructions.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void _startTimer(int seconds) {
    setState(() {
      _timerDuration = seconds;
      _timerRemaining = seconds;
      _isTimerRunning = true;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timerRemaining > 0) {
          _timerRemaining--;
        } else {
          _stopTimer();
          // Ideally play a sound here
        }
      });
    });
  }

  void _stopTimer() {
    _countdownTimer?.cancel();
    setState(() => _isTimerRunning = false);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _speech.stop();
    _ticker.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Content Layer
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),

                      // Voice Status Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isListening ? Colors.red.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _isListening ? Colors.red : Colors.grey),
                        ),
                        child: Row(
                          children: [
                            Icon(_isListening ? Icons.mic : Icons.mic_off, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              _isListening ? "Listening..." : "Mic Off",
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Step Progress Bar
                LinearProgressIndicator(
                  value: (_currentStep + 1) / widget.recipe.instructions.length,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(AppTheme.seedColor),
                ),

                // Main Instruction Area
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) => setState(() => _currentStep = index),
                    itemCount: widget.recipe.instructions.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "STEP ${index + 1}",
                              style: TextStyle(
                                color: AppTheme.secondarySeed,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              widget.recipe.instructions[index],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Controls
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
                        onPressed: _prevStep,
                        iconSize: 32,
                      ),

                      // Timer Button triggers the overlay
                      FloatingActionButton(
                        onPressed: () {
                          if (_isTimerRunning) {
                            _stopTimer();
                          } else {
                            _startTimer(300); // 5 min demo
                          }
                        },
                        backgroundColor: _isTimerRunning ? Colors.red : AppTheme.secondarySeed,
                        child: Icon(_isTimerRunning ? Icons.stop : Icons.timer),
                      ),

                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                        onPressed: _nextStep,
                        iconSize: 32,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Shader Timer Overlay
          // Only visible when timer is running
          if (_isTimerRunning && _program != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: TimerShaderPainter(
                    program: _program!,
                    time: _time,
                    progress: _timerRemaining / _timerDuration,
                  ),
                ),
              ),
            ),

          // Timer Text Overlay
          if (_isTimerRunning)
            Positioned(
              bottom: 140,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  _formatTime(_timerRemaining),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                ),
              ),
            ),

          // Voice Feedback Toast
          if (_lastWords.isNotEmpty)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Heard: "$_lastWords"',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class TimerShaderPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final double time;
  final double progress;

  TimerShaderPainter({
    required this.program,
    required this.time,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();
    shader.setFloat(0, time);             // uTime
    shader.setFloat(1, size.width);       // uResolution.x
    shader.setFloat(2, size.height);      // uResolution.y
    shader.setFloat(3, progress);         // uProgress

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant TimerShaderPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.progress != progress;
  }
}
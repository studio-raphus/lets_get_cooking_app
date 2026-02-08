import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/recipe_provider.dart';
import '../services/ai_recipe_extractor.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';

enum ImportType {
  aiLink,
  manual,
  image,
}

class AddRecipeScreen extends StatefulWidget {
  final ImportType importType;

  const AddRecipeScreen({
    super.key,
    required this.importType,
  });

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  Recipe? _extractedRecipe;

  final AIRecipeExtractor _aiExtractor = AIRecipeExtractor();
  late AnimationController _shaderController;

  @override
  void initState() {
    super.initState();
    _shaderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _shaderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true, // Allow gradient to show behind app bar
      appBar: AppBar(
        title: Text(
          _getTitle(),
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent, // Make transparent
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background Shader
          Positioned.fill(
            child: CustomPaint(
              painter: MeshGradientPainter(
                animation: _shaderController,
                colors: theme.colorScheme,
              ),
              child: Container(color: theme.colorScheme.surface.withOpacity(0.9)), // Heavy overlay for readability
            ),
          ),

          // Content
          SafeArea(
            child: _isLoading ? _buildLoadingState() : _buildContent(),
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (widget.importType) {
      case ImportType.aiLink:
        return 'Import from Link';
      case ImportType.image:
        return 'Scan Recipe';
      case ImportType.manual:
        return 'New Recipe';
    }
  }

  Widget _buildContent() {
    switch (widget.importType) {
      case ImportType.aiLink:
        return _buildLinkImport();
      case ImportType.image:
        return _buildImageImport(); // Or immediately trigger picker in initState if preferred
      case ImportType.manual:
        return _buildManualForm();
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            'Chefs are working...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  // --- 1. Link Import UI ---

  Widget _buildLinkImport() {
    final theme = Theme.of(context);

    if (_extractedRecipe != null) {
      return _buildReviewScreen();
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.link, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'Paste a recipe link',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'We support Instagram, TikTok, YouTube, and most food blogs.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'Recipe URL',
              hintText: 'https://...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: theme.colorScheme.surface, // Glassy look
              prefixIcon: const Icon(Icons.paste),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const Spacer(),
          FilledButton.icon(
            onPressed: _processLink,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Import Recipe'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processLink() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final recipe = await _aiExtractor.extractFromUrl(url);
      setState(() {
        _extractedRecipe = recipe;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not extract recipe. Please check the link.';
      });
    }
  }

  // --- 2. Manual Form UI ---

  Widget _buildManualForm() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Recipe Title',
                hintText: 'e.g., Grandma\'s Apple Pie',
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              style: theme.textTheme.titleLarge,
              validator: (value) => value == null || value.isEmpty ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description / Notes',
                hintText: 'Brief description of the dish...',
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saveManualRecipe,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Create Recipe'),
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. Image Import UI ---

  Widget _buildImageImport() {
    final theme = Theme.of(context);

    if (_extractedRecipe != null) {
      return _buildReviewScreen();
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.camera_alt_outlined, size: 80, color: theme.colorScheme.tertiary),
          const SizedBox(height: 24),
          Text(
            'Scan a Cookbook Page',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Take a photo of a recipe and we\'ll convert it to digital format instantly.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: () => _pickImage(ImageSource.camera),
            icon: const Icon(Icons.camera),
            label: const Text('Take Photo'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.tertiary,
              foregroundColor: theme.colorScheme.onTertiary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Choose from Gallery'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: theme.colorScheme.tertiary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final recipe = await _aiExtractor.extractFromImage(pickedFile.path);
        setState(() {
          _extractedRecipe = recipe;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error processing image: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  // --- Common: Review Screen ---

  Widget _buildReviewScreen() {
    final theme = Theme.of(context);
    final recipe = _extractedRecipe!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Recipe Found!',
            style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text('${recipe.ingredients.length} Ingredients', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                  const SizedBox(height: 4),
                  Text(recipe.ingredients.take(3).join(', ') + (recipe.ingredients.length > 3 ? '...' : ''), style: theme.textTheme.bodyMedium),

                  const SizedBox(height: 16),
                  Text('Instructions', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                  const SizedBox(height: 4),
                  Text('${recipe.instructions.length} steps', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saveExtractedRecipe,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: theme.colorScheme.primary,
            ),
            child: const Text('Save to Cookbook'),
          ),
          TextButton(
            onPressed: () => setState(() { _extractedRecipe = null; _urlController.clear(); }),
            child: const Text('Discard & Try Again'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveManualRecipe() async {
    if (_formKey.currentState!.validate()) {
      final recipe = Recipe(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        ingredients: [],
        instructions: [],
        sourceType: 'manual',
        wantToCook: true,
        createdAt: DateTime.now(),
        // You might want to add description here if your model supports it
      );

      final recipeProvider = context.read<RecipeProvider>();
      await recipeProvider.addRecipe(recipe);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Recipe saved! Add ingredients in details.'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    }
  }

  Future<void> _saveExtractedRecipe() async {
    if (_extractedRecipe == null) return;

    final recipeProvider = context.read<RecipeProvider>();
    await recipeProvider.addRecipe(_extractedRecipe!);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🎉 Recipe saved successfully!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }
}
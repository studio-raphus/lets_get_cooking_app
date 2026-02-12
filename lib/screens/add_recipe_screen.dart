import 'dart:ui'; // Required for BackdropFilter
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/recipe_provider.dart';
import '../services/ai_recipe_extractor.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart'; // Ensures MeshGradientPainter is available

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

  // Controllers
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final List<TextEditingController> _ingredientControllers = [];

  // Categorization State
  final List<String> _availableTags = ['Breakfast', 'Lunch', 'Dinner', 'Dessert', 'Snack', 'Healthy', 'Quick', 'Vegan'];
  final Set<String> _selectedTags = {};

  // State Variables
  bool _isLoading = false;
  String? _errorMessage;
  Recipe? _extractedRecipe;

  // TODO: Connect this to your actual User/Subscription Provider
  final bool _isBasicPlan = true;

  final AIRecipeExtractor _aiExtractor = AIRecipeExtractor();
  late AnimationController _shaderController;

  @override
  void initState() {
    super.initState();
    _shaderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    // Initialize with one empty ingredient field
    _addIngredientField();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    for (var controller in _ingredientControllers) {
      controller.dispose();
    }
    _shaderController.dispose();
    super.dispose();
  }

  void _addIngredientField() {
    setState(() {
      _ingredientControllers.add(TextEditingController());
    });
  }

  void _removeIngredientField(int index) {
    setState(() {
      _ingredientControllers[index].dispose();
      _ingredientControllers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _getTitle(),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: theme.colorScheme.surface.withOpacity(0.4),
            child: IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              color: theme.colorScheme.onSurface,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // 1. Animated Mesh Gradient Background
          Positioned.fill(
            child: CustomPaint(
              painter: MeshGradientPainter(
                animation: _shaderController,
                colors: theme.colorScheme,
              ),
            ),
          ),

          // 2. Global Blur for readability (Frosted Effect)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: theme.colorScheme.surface.withOpacity(0.3),
              ),
            ),
          ),

          // 3. Content
          SafeArea(
            child: _isLoading ? _buildLoadingState() : _buildContent(),
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    if (_extractedRecipe != null) return 'Review Recipe';
    switch (widget.importType) {
      case ImportType.aiLink: return 'Import Link';
      case ImportType.image: return 'Scan Recipe';
      case ImportType.manual: return 'New Recipe';
    }
  }

  Widget _buildContent() {
    if (_extractedRecipe != null) {
      return _buildReviewScreen();
    }

    switch (widget.importType) {
      case ImportType.aiLink: return _buildLinkImport();
      case ImportType.image: return _buildImageImport();
      case ImportType.manual: return _buildManualForm();
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
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
    return Center(
      child: _buildGlassContainer(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.link, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Paste a Recipe URL',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _urlController,
              decoration: _glassInputDecoration('https://...', Icons.paste),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _processLink,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Import Recipe'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processLink() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final recipe = await _aiExtractor.extractFromUrl(url);
      setState(() { _extractedRecipe = recipe; _isLoading = false; });
    } catch (e) {
      setState(() { _isLoading = false; _errorMessage = 'Could not extract recipe. Please check the link.'; });
    }
  }

  // --- 2. Manual Form UI (Fully Features) ---
  Widget _buildManualForm() {
    final theme = Theme.of(context);
    final isLimitReached = _isBasicPlan && _ingredientControllers.length >= 3;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A. Title Input
            TextFormField(
              controller: _titleController,
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 32,
              ),
              decoration: InputDecoration(
                hintText: 'Recipe Title',
                hintStyle: theme.textTheme.displaySmall?.copyWith(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  fontSize: 32,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 24),
              ),
              validator: (val) => val == null || val.isEmpty ? 'Please give it a name' : null,
            ),

            const SizedBox(height: 20),

            // B. Categories / Tags (NEW)
            _buildGlassCard(
              title: 'Categories',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                    backgroundColor: Colors.white.withOpacity(0.3),
                    selectedColor: theme.colorScheme.primaryContainer,
                    checkmarkColor: theme.colorScheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide.none,
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // C. Ingredients
            _buildGlassCard(
              title: 'Ingredients',
              trailing: _isBasicPlan
                  ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_ingredientControllers.length}/3',
                  style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              )
                  : null,
              child: Column(
                children: [
                  ..._ingredientControllers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final controller = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: theme.colorScheme.secondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: controller,
                              decoration: const InputDecoration(
                                hintText: 'e.g., 2 cups flour',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: theme.textTheme.bodyLarge,
                              validator: (val) => index == 0 && (val == null || val.isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          if (_ingredientControllers.length > 1)
                            IconButton(
                              icon: Icon(Icons.close, size: 18, color: theme.colorScheme.error.withOpacity(0.5)),
                              onPressed: () => _removeIngredientField(index),
                            ),
                        ],
                      ),
                    );
                  }),

                  const Divider(),

                  if (!isLimitReached)
                    TextButton.icon(
                      onPressed: _addIngredientField,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Add Ingredient'),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Basic Plan Limit Reached',
                        style: TextStyle(color: theme.colorScheme.secondary, fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // D. Instructions
            _buildGlassCard(
              title: 'Preparation & Notes',
              child: TextFormField(
                controller: _notesController,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Describe the steps to create this masterpiece...',
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 40),

            FilledButton(
              onPressed: _saveManualRecipe,
              style: FilledButton.styleFrom(
                elevation: 4,
                shadowColor: theme.colorScheme.primary.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              child: const Text('Save to Cookbook'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildGlassCard({required String title, required Widget child, Widget? trailing}) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          color: Colors.white.withOpacity(0.5),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child, EdgeInsets? padding, EdgeInsets? margin}) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding,
            color: Colors.white.withOpacity(0.4),
            child: child,
          ),
        ),
      ),
    );
  }

  InputDecoration _glassInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white.withOpacity(0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  // --- 3. Image Import UI ---
  Widget _buildImageImport() {
    return Center(
      child: _buildGlassContainer(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_outlined, size: 60, color: Theme.of(context).colorScheme.tertiary),
            const SizedBox(height: 24),
            Text('Scan Cookbook', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera),
              label: const Text('Take Photo'),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Choose from Gallery'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() => _isLoading = true);
      try {
        final recipe = await _aiExtractor.extractFromImage(pickedFile.path);
        setState(() { _extractedRecipe = recipe; _isLoading = false; });
      } catch (e) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Review Screen ---
  Widget _buildReviewScreen() {
    final recipe = _extractedRecipe!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildGlassCard(
            title: 'Review Recipe',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    recipe.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)
                ),
                const Divider(),
                const SizedBox(height: 10),
                Text('Ingredients:', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                ...recipe.ingredients.take(8).map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text('• ${e.item.toString()}'),
                )),
                if (recipe.ingredients.length > 8)
                  Text('...and ${recipe.ingredients.length - 8} more', style: const TextStyle(fontStyle: FontStyle.italic)),

                const SizedBox(height: 20),
                Text('Instructions:', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                ...recipe.instructions.take(3).map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text('${recipe.instructions.indexOf(e) + 1}. $e', maxLines: 2, overflow: TextOverflow.ellipsis),
                )),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() { _extractedRecipe = null; });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Theme.of(context).colorScheme.error),
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Discard'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _saveExtractedRecipe,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save Recipe'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Logic: Save Manual Recipe (Parsed) ---
  Future<void> _saveManualRecipe() async {
    if (_formKey.currentState!.validate()) {

      // PARSE LOGIC: Convert text fields to Ingredient objects
      final List<Ingredient> ingredientsList = _ingredientControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .map((text) {
        double quantity = 1.0;
        String unit = '';
        String item = text;

        final parts = text.split(' ');
        if (parts.isNotEmpty) {
          final parsedQuantity = double.tryParse(parts[0]);
          if (parsedQuantity != null) {
            quantity = parsedQuantity;
            if (parts.length > 1) {
              unit = parts[1];
              if (parts.length > 2) {
                item = parts.sublist(2).join(' ');
              } else {
                item = parts.sublist(1).join(' ');
                unit = '';
              }
            } else {
              item = '';
            }
          }
        }

        // Cleanup fallback
        if (item.trim().isEmpty) {
          item = text;
          quantity = 0.0;
          unit = '';
        }

        return Ingredient(
          item: item,
          quantity: quantity,
          unit: unit,
        );
      })
          .toList();

      final recipe = Recipe(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        ingredients: ingredientsList,
        instructions: _notesController.text.trim().isNotEmpty
            ? [_notesController.text.trim()]
            : [],
        sourceType: 'manual',
        wantToCook: true,
        tags: _selectedTags.toList(), // SAVE CATEGORIES
        createdAt: DateTime.now(),
      );

      final recipeProvider = context.read<RecipeProvider>();

      try {
        await recipeProvider.addRecipe(recipe);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Recipe saved successfully!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving: $e')),
          );
        }
      }
    }
  }

  Future<void> _saveExtractedRecipe() async {
    if (_extractedRecipe == null) return;
    await context.read<RecipeProvider>().addRecipe(_extractedRecipe!);
    if (mounted) Navigator.pop(context);
  }
}
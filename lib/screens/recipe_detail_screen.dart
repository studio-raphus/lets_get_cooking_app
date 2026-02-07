import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recipe.dart';
import '../models/grocery_item.dart';
import '../providers/recipe_provider.dart';
import '../services/grocery_list_generator.dart';
import '../theme/app_theme.dart';
import '../widgets/grocery_list_sheet.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({
    Key? key,
    required this.recipe,
  }) : super(key: key);

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _shaderController;
  bool _isGeneratingGroceryList = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _shaderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12), // Slow, subtle movement for detail
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _shaderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildSliverAppBar(innerBoxIsScrolled),
          ];
        },
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Block
                  Text(
                    widget.recipe.title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
                  ],
                ),
                dividerColor: Colors.transparent,
                padding: const EdgeInsets.all(4),
                tabs: const [
                  Tab(text: 'Ingredients'),
                  Tab(text: 'Instructions'),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildIngredientsList(),
                  _buildInstructionsList(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generateGroceryList,
        icon: _isGeneratingGroceryList
            ? Container(width: 24, height: 24, padding: const EdgeInsets.all(2), child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.shopping_cart_checkout),
        label: Text(_isGeneratingGroceryList ? 'Generating...' : 'Make List'),
        elevation: 4,
      ),
    );
  }

  Widget _buildSliverAppBar(bool innerBoxIsScrolled) {
    final theme = Theme.of(context);

    return SliverAppBar.large(
      expandedHeight: 220.0,
      pinned: true,
      stretch: true,
      backgroundColor: theme.colorScheme.surface,
      leading: IconButton(
        icon: CircleAvatar(
          backgroundColor: theme.colorScheme.surface.withOpacity(0.5),
          child: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Mesh Gradient Base
            CustomPaint(
              painter: MeshGradientPainter(
                animation: _shaderController,
                colors: theme.colorScheme,
              ),
            ),
            // 2. Image (if exists) or Icon Overlay
            if (widget.recipe.imageUrl != null)
              Image.network(
                widget.recipe.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (c,e,s) => const SizedBox(),
              )
            else
              Center(
                child: Icon(
                  Icons.restaurant_menu,
                  size: 80,
                  color: theme.colorScheme.onPrimaryContainer.withOpacity(0.2),
                ),
              ),

            // 3. Gradient Fade at bottom for text readability
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.colorScheme.surface.withOpacity(0),
                      theme.colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        CircleAvatar(
          backgroundColor: theme.colorScheme.surface.withOpacity(0.5),
          child: IconButton(
            icon: const Icon(Icons.share, size: 20, color: Colors.black),
            onPressed: _shareRecipe,
          ),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          backgroundColor: theme.colorScheme.surface.withOpacity(0.5),
          child: IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
            onPressed: _deleteRecipe,
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Consumer<RecipeProvider>(
      builder: (context, provider, _) {
        // Safe check for index
        final index = provider.recipes.indexWhere((r) => r.id == widget.recipe.id);
        if (index == -1) return const SizedBox.shrink(); // Recipe might be deleted

        final currentRecipe = provider.recipes[index];
        final theme = Theme.of(context);

        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final updated = currentRecipe.copyWith(wantToCook: !currentRecipe.wantToCook);
                  provider.updateRecipe(updated);
                },
                icon: Icon(
                  currentRecipe.wantToCook ? Icons.bookmark : Icons.bookmark_border,
                  color: currentRecipe.wantToCook ? theme.colorScheme.primary : theme.colorScheme.outline,
                ),
                label: Text(currentRecipe.wantToCook ? 'Saved' : 'Save'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: currentRecipe.wantToCook ? theme.colorScheme.primary : theme.colorScheme.outline),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  final updated = currentRecipe.copyWith(isCooked: !currentRecipe.isCooked);
                  provider.updateRecipe(updated);
                },
                icon: Icon(
                  currentRecipe.isCooked ? Icons.check_circle : Icons.check_circle_outline,
                  color: currentRecipe.isCooked ? theme.colorScheme.onSecondary : theme.colorScheme.onPrimary,
                ),
                label: Text(currentRecipe.isCooked ? 'Cooked' : 'Mark Cooked'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: currentRecipe.isCooked ? theme.colorScheme.secondary : theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIngredientsList() {
    final theme = Theme.of(context);

    if (widget.recipe.ingredients.isEmpty) {
      return Center(child: Text("No ingredients listed.", style: theme.textTheme.bodyLarge));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      itemCount: widget.recipe.ingredients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final ingredient = widget.recipe.ingredients[index];
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
          ),
          child: CheckboxListTile(
            value: false, // State management for local checkboxes can be added if needed
            onChanged: (val) {},
            title: Text(ingredient as String, style: theme.textTheme.bodyMedium),
            controlAffinity: ListTileControlAffinity.leading,
            checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            activeColor: theme.colorScheme.secondary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          ),
        );
      },
    );
  }

  Widget _buildInstructionsList() {
    final theme = Theme.of(context);

    if (widget.recipe.instructions.isEmpty) {
      return Center(child: Text("No instructions listed.", style: theme.textTheme.bodyLarge));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      itemCount: widget.recipe.instructions.length,
      itemBuilder: (context, index) {
        final step = widget.recipe.instructions[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  step,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _generateGroceryList() async {
    setState(() {
      _isGeneratingGroceryList = true;
    });

    try {
      final generator = GroceryListGenerator();
      final items = await generator.generateFromRecipes([widget.recipe]);

      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => GroceryListSheet(
            groceryItems: items,
            recipeName: widget.recipe.title,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating list: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingGroceryList = false;
        });
      }
    }
  }

  Future<void> _shareRecipe() async {
    final StringBuffer shareText = StringBuffer();
    shareText.writeln(widget.recipe.title);
    shareText.writeln('\nIngredients:');
    for (var i in widget.recipe.ingredients) {
      shareText.writeln('- $i');
    }

    if (widget.recipe.instructions.isNotEmpty) {
      shareText.writeln('\nInstructions:');
      for (int i = 0; i < widget.recipe.instructions.length; i++) {
        shareText.writeln('${i + 1}. ${widget.recipe.instructions[i]}');
      }
    }

    await Share.share(
      shareText.toString(),
      subject: widget.recipe.title,
    );
  }

  void _deleteRecipe() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Delete Recipe'),
        content: Text('Are you sure you want to delete "${widget.recipe.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final recipeProvider = context.read<RecipeProvider>();
              await recipeProvider.deleteRecipe(widget.recipe.id);

              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to home

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Recipe deleted'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
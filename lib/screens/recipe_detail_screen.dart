import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../services/grocery_list_generator.dart';
import '../theme/app_theme.dart';
import '../widgets/grocery_list_sheet.dart';
import 'cook_mode_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isGeneratingGroceryList = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Actions ---

  Future<void> _confirmDelete() async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recipe?'),
        content: const Text('Are you sure you want to remove this recipe from your cookbook? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<RecipeProvider>().deleteRecipe(widget.recipe.id);
      if (mounted) {
        Navigator.pop(context); // Return to previous screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe deleted')),
        );
      }
    }
  }

  Future<void> _shareRecipe() async {
    final StringBuffer shareText = StringBuffer();
    shareText.writeln(widget.recipe.title);
    shareText.writeln('\nIngredients:');
    for (var ing in widget.recipe.ingredients) {
      shareText.writeln('- ${ing.quantity} ${ing.unit} ${ing.item}');
    }
    shareText.writeln('\nInstructions:');
    for (int i = 0; i < widget.recipe.instructions.length; i++) {
      shareText.writeln('${i + 1}. ${widget.recipe.instructions[i]}');
    }
    await Share.share(shareText.toString());
  }

  // --- FIXED: Grocery List Generation ---
  Future<void> _generateGroceryList() async {
    setState(() => _isGeneratingGroceryList = true);
    try {
      // 1. Convert Recipe Ingredients to GroceryItems
      // FIXED: Use generateFromRecipes (plural) and pass a list
      // Removed 'await' because the method is synchronous
      final groceryGenerator = GroceryListGenerator();
      final groceryItems = groceryGenerator.generateFromRecipes([widget.recipe]);

      // 2. Show the Sheet
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => GroceryListSheet(initialItems: groceryItems),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating list: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingGroceryList = false);
    }
  }

  // --- Helpers for Icon Styling ---

  ButtonStyle _circleButtonStyle(ThemeData theme) {
    return IconButton.styleFrom(
      backgroundColor: theme.colorScheme.surface.withOpacity(0.6),
      foregroundColor: theme.colorScheme.onSurface,
      padding: const EdgeInsets.all(12),
      elevation: 2,
    );
  }

  ButtonStyle _circleDeleteButtonStyle(ThemeData theme) {
    return IconButton.styleFrom(
      backgroundColor: theme.colorScheme.error,
      foregroundColor: theme.colorScheme.onError,
      padding: const EdgeInsets.all(12),
      elevation: 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              backgroundColor: theme.colorScheme.surface,
              // 1. CIRCULAR BACK BUTTON
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: () => Navigator.pop(context),
                  style: _circleButtonStyle(theme),
                ),
              ),
              actions: [
                // 2. CIRCULAR DELETE BUTTON
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 22),
                    onPressed: _confirmDelete,
                    style: _circleDeleteButtonStyle(theme),
                    tooltip: 'Delete Recipe',
                  ),
                ),
                // 3. CIRCULAR SHARE BUTTON
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: IconButton(
                    icon: const Icon(Icons.share, size: 22),
                    onPressed: _shareRecipe,
                    style: _circleButtonStyle(theme),
                    tooltip: 'Share',
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Recipe Image
                    if (widget.recipe.imageUrl != null)
                      Image.network(
                        widget.recipe.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (c, o, s) => Container(color: AppTheme.seedColor),
                      )
                    else
                      Container(color: AppTheme.seedColor),

                    // Gradient Overlay
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),

                    // Title and Tags
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.recipe.sourceType.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.recipe.title,
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontSize: 28,
                              height: 1.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // TabBar pinned at the bottom of the AppBar
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: theme.colorScheme.surface,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                    indicatorColor: theme.colorScheme.primary,
                    tabs: const [
                      Tab(text: "Ingredients"),
                      Tab(text: "Instructions"),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildIngredientsList(theme),
            _buildInstructionsList(theme),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CookModeScreen(recipe: widget.recipe),
            ),
          );
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text("Start Cooking"),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
    );
  }

  // --- Content Builders ---

  Widget _buildIngredientsList(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Grocery Generator Button
        Card(
          color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
          elevation: 0,
          child: ListTile(
            leading: Icon(Icons.shopping_basket_outlined, color: theme.colorScheme.primary),
            title: const Text('Add to Grocery List'),
            subtitle: const Text('Generate a smart shopping list'),
            trailing: _isGeneratingGroceryList
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _generateGroceryList,
          ),
        ),
        const SizedBox(height: 20),

        // Ingredients List
        ...widget.recipe.ingredients.map((ing) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.circle, size: 8, color: theme.colorScheme.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyLarge,
                      children: [
                        TextSpan(
                          text: '${ing.quantity > 0 ? ing.quantity : ""} ${ing.unit} ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: ing.item),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 80), // Space for FAB
      ],
    );
  }

  Widget _buildInstructionsList(ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: widget.recipe.instructions.length,
      separatorBuilder: (c, i) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Text(
                "${index + 1}",
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                widget.recipe.instructions[index],
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ),
          ],
        );
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recipe.dart';
import '../models/grocery_item.dart'; // Ensure this import exists
import '../providers/recipe_provider.dart';
import '../services/grocery_list_generator.dart';
import '../theme/app_theme.dart';
import '../widgets/grocery_list_sheet.dart';
import 'cook_mode_screen.dart';

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
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _shaderController.dispose();
    super.dispose();
  }

  // --- Logic for Generating Grocery List ---
  Future<void> _generateGroceryList() async {
    setState(() => _isGeneratingGroceryList = true);

    // Simulate a short delay for UX
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    // Use the generator service
    final generator = GroceryListGenerator();
    final items = generator.generateFromRecipes([widget.recipe]);

    setState(() => _isGeneratingGroceryList = false);

    // Show the Bottom Sheet with the generated list
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GroceryListSheet(
        groceryItems: items,        // Correct parameter name
        recipeName: widget.recipe.title, // <--- ADDED THIS PARAMETER
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface, // Updated to surface for better theme consistency

      // --- DUAL FLOATING ACTION BUTTONS ---
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. MAKE LIST BUTTON
            Expanded(
              child: FloatingActionButton.extended(
                heroTag: "btn_make_list",
                onPressed: _isGeneratingGroceryList ? null : _generateGroceryList,
                backgroundColor: theme.colorScheme.secondaryContainer,
                foregroundColor: theme.colorScheme.onSecondaryContainer,
                elevation: 4,
                icon: _isGeneratingGroceryList
                    ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onSecondaryContainer
                    )
                )
                    : const Icon(Icons.shopping_cart_checkout),
                label: Text(
                  _isGeneratingGroceryList ? 'Generating...' : 'Make List',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(width: 16), // Space between buttons

            // 2. COOK MODE BUTTON (Visual Emphasis)
            Expanded(
              child: FloatingActionButton.extended(
                heroTag: "btn_cook_mode",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CookModeScreen(recipe: widget.recipe),
                    ),
                  );
                },
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                elevation: 6,
                icon: const Icon(Icons.play_circle_fill),
                label: const Text(
                    "Cook Mode",
                    style: TextStyle(fontWeight: FontWeight.bold)
                ),
              ),
            ),
          ],
        ),
      ),

      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 320,
              floating: false,
              pinned: true,
              backgroundColor: theme.colorScheme.surface,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    widget.recipe.wantToCook ? Icons.favorite : Icons.favorite_border,
                    color: widget.recipe.wantToCook ? Colors.redAccent : Colors.white,
                    size: 28,
                  ),
                  onPressed: () {
                    context.read<RecipeProvider>().toggleCookedStatus(widget.recipe.id);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white, size: 28),
                  onPressed: _shareRecipe,
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

                    // Gradient Overlay for text readability
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.4),
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
            ),
          ];
        },
        body: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorColor: theme.colorScheme.primary,
              tabs: const [
                Tab(text: "Ingredients"),
                Tab(text: "Instructions"),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildIngredientsList(theme),
                  _buildInstructionsList(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildIngredientsList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), // Padding for FABs
      itemCount: widget.recipe.ingredients.length,
      itemBuilder: (context, index) {
        final ingredient = widget.recipe.ingredients[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(Icons.circle, size: 8, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "${ingredient.quantity > 0 ? ingredient.quantity : ''} ${ingredient.unit} ${ingredient.item}",
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstructionsList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), // Padding for FABs
      itemCount: widget.recipe.instructions.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
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
          ),
        );
      },
    );
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
}
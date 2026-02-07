import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/recipe_provider.dart';
import '../providers/premium_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/recipe_card.dart';
import 'add_recipe_screen.dart';
import 'recipe_detail_screen.dart';
import 'paywall_screen.dart';
import 'meal_plan_screen.dart';
import '../widgets/empty_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  late AnimationController _shaderController;

  @override
  void initState() {
    super.initState();
    // Animation for the "Living" background in AppBar
    _shaderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecipes();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _shaderController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    final recipeProvider = context.read<RecipeProvider>();
    await recipeProvider.loadRecipes();
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubicEmphasized,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: [
          _HomeTab(shaderController: _shaderController), // Pass controller
          const _RecipesTab(),
          const MealPlanScreen(),
        ],
      ),
      floatingActionButton: _selectedIndex < 2 ? _buildFAB() : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu),
            selectedIcon: Icon(Icons.restaurant_menu_rounded),
            label: 'Cookbook',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today_rounded),
            label: 'Plan',
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Consumer2<RecipeProvider, PremiumProvider>(
      builder: (context, recipeProvider, premiumProvider, _) {
        final canAdd = premiumProvider.canAddMoreRecipes(
          recipeProvider.wantToCookRecipes.length,
        );

        return FloatingActionButton.extended(
          onPressed: () {
            if (canAdd) {
              _showAddRecipeOptions(context);
            } else {
              _navigateToPaywall('Add More Recipes');
            }
          },
          icon: Icon(canAdd ? Icons.add_rounded : Icons.lock_outline_rounded),
          label: Text(canAdd ? 'Add Recipe' : 'Upgrade'),
          elevation: 4,
        );
      },
    );
  }

  void _navigateToPaywall(String feature) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaywallScreen(feature: feature),
      ),
    );
  }

  void _showAddRecipeOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AddRecipeBottomSheet(
        onAIImport: () => _navigateToAdd(ImportType.aiLink),
        onScan: () => _navigateToAdd(ImportType.image),
        onManual: () => _navigateToAdd(ImportType.manual),
      ),
    );
  }

  void _navigateToAdd(ImportType type) {
    Navigator.pop(context); // Close sheet
    final premium = context.read<PremiumProvider>();

    if (type != ImportType.manual && !premium.canUseAIImport()) {
      _navigateToPaywall('AI Features');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddRecipeScreen(importType: type),
      ),
    );
  }
}

// ==============================================================================
// 1. HOME TAB (Modern "Explore" Style with Shader)
// ==============================================================================

class _HomeTab extends StatelessWidget {
  final AnimationController shaderController;

  const _HomeTab({required this.shaderController});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return CustomScrollView(
      slivers: [
        // DYNAMIC HEADER
        SliverAppBar.large(
          centerTitle: false,
          expandedHeight: 140,
          stretch: true,
          flexibleSpace: FlexibleSpaceBar(
            background: CustomPaint(
              painter: MeshGradientPainter(
                animation: shaderController,
                colors: colorScheme,
              ),
              child: Container(color: Colors.white.withOpacity(0.1)), // Glass overlay
            ),
            titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            title: Text(
              'What\'s cooking?',
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () { /* Navigate to settings */ },
            ),
            const SizedBox(width: 8),
          ],
        ),

        // Search Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: _ModernSearchBar(),
          ),
        ),

        // Categories
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _FilterChip(label: 'Breakfast', icon: Icons.wb_twilight_rounded),
                  _FilterChip(label: 'Dinner', icon: Icons.dinner_dining_rounded),
                  _FilterChip(label: 'Healthy', icon: Icons.eco_rounded),
                  _FilterChip(label: 'Quick', icon: Icons.timer_outlined),
                  _FilterChip(label: 'Dessert', icon: Icons.cake_outlined),
                ],
              ),
            ),
          ),
        ),

        // "Ready to Cook" (Horizontal)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: _SectionHeader(title: 'Ready to Cook'),
          ),
        ),

        SliverToBoxAdapter(
          child: SizedBox(
            height: 280,
            child: Consumer<RecipeProvider>(
              builder: (context, provider, _) {
                if (provider.wantToCookRecipes.isEmpty) {
                  return _CompactEmptyState(
                    message: "Add recipes you want to cook!",
                    icon: Icons.bookmark_add_outlined,
                  );
                }
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: provider.wantToCookRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = provider.wantToCookRecipes[index];
                    return Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 12),
                      child: RecipeCard(
                        recipe: recipe,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe))),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // "Recent Collection" (Grid)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: _SectionHeader(title: 'Recent Collection'),
          ),
        ),

        Consumer<RecipeProvider>(
          builder: (context, provider, _) {
            if (provider.recipes.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text("Your kitchen is empty. Time to add some flavor!"),
                  ),
                ),
              );
            }
            final recentRecipes = provider.recipes.take(10).toList();
            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, index) => RecipeCard(
                    recipe: recentRecipes[index],
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recentRecipes[index]))),
                  ),
                  childCount: recentRecipes.length,
                ),
              ),
            );
          },
        ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }
}

// ==============================================================================
// 2. RECIPES TAB (Preserved Functionality)
// ==============================================================================

class _RecipesTab extends StatelessWidget {
  const _RecipesTab();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Cookbook'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Want to Cook'),
              Tab(text: 'Cooked'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _RecipeGridList(wantToCook: true),
            _RecipeGridList(wantToCook: false),
          ],
        ),
      ),
    );
  }
}

class _RecipeGridList extends StatelessWidget {
  final bool wantToCook;

  const _RecipeGridList({required this.wantToCook});

  @override
  Widget build(BuildContext context) {
    return Consumer<RecipeProvider>(
      builder: (context, provider, _) {
        final recipes = wantToCook
            ? provider.wantToCookRecipes
            : provider.cookedRecipes;

        if (recipes.isEmpty) {
          return EmptyState(
            icon: wantToCook ? Icons.bookmark_border : Icons.check_circle_outline,
            title: wantToCook ? 'No Saved Recipes' : 'Nothing Cooked Yet',
            description: wantToCook
                ? 'Recipes you add will appear here.'
                : 'Mark recipes as cooked to build your history.',
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            return RecipeCard(
              recipe: recipes[index],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(recipe: recipes[index]),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ==============================================================================
// HELPER WIDGETS
// ==============================================================================

class _ModernSearchBar extends StatelessWidget {
  const _ModernSearchBar();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceVariant.withOpacity(0.5),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () {
          // Trigger search functionality
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.search, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 16),
              Text(
                'Search recipes, ingredients...',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _FilterChip({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        avatar: icon != null ? Icon(icon, size: 18) : null,
        onSelected: (bool selected) {},
        backgroundColor: Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: colorScheme.outline)),
        labelStyle: TextStyle(color: colorScheme.onSurface),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Icon(Icons.arrow_forward, size: 20, color: Theme.of(context).colorScheme.primary),
      ],
    );
  }
}

class _CompactEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const _CompactEmptyState({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ==============================================================================
// ADD RECIPE BOTTOM SHEET
// ==============================================================================

class _AddRecipeBottomSheet extends StatelessWidget {
  final VoidCallback onAIImport;
  final VoidCallback onScan;
  final VoidCallback onManual;

  const _AddRecipeBottomSheet({
    required this.onAIImport,
    required this.onScan,
    required this.onManual,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Add Recipe',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),

              _buildOption(
                context,
                icon: Icons.auto_awesome,
                title: 'AI Import',
                subtitle: 'Paste link from TikTok, IG, or Web',
                color: theme.colorScheme.primary,
                isPro: true,
                onTap: onAIImport,
              ),
              const SizedBox(height: 12),
              _buildOption(
                context,
                icon: Icons.camera_alt_outlined,
                title: 'Scan Photo',
                subtitle: 'Extract recipe from cookbook page',
                color: theme.colorScheme.tertiary,
                isPro: true,
                onTap: onScan,
              ),
              const SizedBox(height: 12),
              _buildOption(
                context,
                icon: Icons.edit_outlined,
                title: 'Manual Entry',
                subtitle: 'Type ingredients and steps',
                color: theme.colorScheme.secondary,
                isPro: false,
                onTap: onManual,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required Color color,
        required bool isPro,
        required VoidCallback onTap,
      }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isPro) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'PRO',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
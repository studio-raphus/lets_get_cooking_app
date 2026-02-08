import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../providers/premium_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/recipe_card.dart';
import 'add_recipe_screen.dart';
import 'recipe_detail_screen.dart';
import 'paywall_screen.dart';
import 'meal_plan_screen.dart';
import 'profile_screen.dart';
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
    // Animation for the "Living" background in AppBar and NavBar
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
        physics: const NeverScrollableScrollPhysics(), // Prevent swipe conflicts
        children: [
          _HomeTab(shaderController: _shaderController),
          const _RecipesTab(),
          const MealPlanScreen(),
          const ProfileScreen(),
        ],
      ),
      floatingActionButton: _selectedIndex < 2 ? _buildFAB() : null,

      // ANIMATED NAVIGATION BAR
      bottomNavigationBar: Container(
        color: colorScheme.primary, // Base color
        child: CustomPaint(
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            indicatorColor: colorScheme.secondary,
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
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
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
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
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
    Navigator.pop(context);
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
// 1. HOME TAB (With Functional Search & Filter)
// ==============================================================================

class _HomeTab extends StatefulWidget {
  final AnimationController shaderController;

  const _HomeTab({required this.shaderController});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  // Search & Filter State
  String _searchQuery = '';
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Filter Logic
  List<Recipe> _filterRecipes(List<Recipe> allRecipes) {
    return allRecipes.where((recipe) {
      // 1. Search Filter
      final matchesSearch = _searchQuery.isEmpty ||
          recipe.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          recipe.ingredients.any((i) => i.toString().toLowerCase().contains(_searchQuery.toLowerCase()));

      // 2. Category Filter
      // (Assuming category logic matches title/tags for now)
      final matchesCategory = _selectedCategory == null ||
          recipe.title.toLowerCase().contains(_selectedCategory!.toLowerCase());

      return matchesSearch && matchesCategory;
    }).toList();
  }

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
                animation: widget.shaderController,
                colors: colorScheme,
              ),
              child: Container(color: Colors.white.withOpacity(0.25)),
            ),
            titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            title: const Text(
              'What\'s cooking?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          actions: [
            // Dynamic Icon based on Subscription Status
            Consumer<PremiumProvider>(
              builder: (context, premium, child) {
                return IconButton(
                  icon: Icon(
                    premium.isPremium ? Icons.verified : Icons.account_circle_outlined,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    // Switch to Profile Tab (index 3) via parent controller if possible,
                    // or just let user tap the bottom bar.
                  },
                  tooltip: premium.isPremium ? 'Premium Chef' : 'Basic Account',
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),

        // SEARCH BAR
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: _ModernSearchBar(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
        ),

        // CATEGORY CHIPS
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterChip('Breakfast', Icons.wb_twilight_rounded),
                  _buildFilterChip('Dinner', Icons.dinner_dining_rounded),
                  _buildFilterChip('Healthy', Icons.eco_rounded),
                  _buildFilterChip('Quick', Icons.timer_outlined),
                  _buildFilterChip('Dessert', Icons.cake_outlined),
                ],
              ),
            ),
          ),
        ),

        // SECTION HEADER (Dynamic Title)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: _SectionHeader(
              title: _searchQuery.isNotEmpty || _selectedCategory != null
                  ? 'Found Recipes'
                  : 'Recent Collection',
            ),
          ),
        ),

        // RECIPE GRID
        Consumer<RecipeProvider>(
          builder: (context, provider, _) {
            // Use local filter function
            final displayRecipes = _searchQuery.isEmpty && _selectedCategory == null
                ? provider.recipes.take(10).toList() // Show recent by default
                : _filterRecipes(provider.recipes);  // Show filtered

            if (displayRecipes.isEmpty) {
              if (provider.recipes.isEmpty) {
                // Totally empty state
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text("Your kitchen is empty. Time to add some flavor!"),
                    ),
                  ),
                );
              } else {
                // No search results
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text("No recipes found matching your search."),
                    ),
                  ),
                );
              }
            }

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
                    recipe: displayRecipes[index],
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => RecipeDetailScreen(recipe: displayRecipes[index])
                        )
                    ),
                  ),
                  childCount: displayRecipes.length,
                ),
              ),
            );
          },
        ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    return _FilterChip(
      label: label,
      icon: icon,
      isSelected: _selectedCategory == label,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = selected ? label : null;
        });
      },
    );
  }
}

// ==============================================================================
// 2. RECIPES TAB
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
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
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
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  const _ModernSearchBar({this.controller, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          icon: Icon(Icons.search, color: colorScheme.primary),
          hintText: 'Search recipes, ingredients...',
          hintStyle: TextStyle(
            color: colorScheme.primary.withOpacity(0.7),
            fontSize: 16,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  const _FilterChip({
    required this.label,
    this.icon,
    this.isSelected = false,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        avatar: icon != null ? Icon(
            icon,
            size: 18,
            color: isSelected ? colorScheme.onPrimary : colorScheme.primary
        ) : null,
        selected: isSelected,
        onSelected: onSelected,
        backgroundColor: Colors.transparent,
        selectedColor: colorScheme.primary,
        checkmarkColor: colorScheme.onPrimary,
        shape: StadiumBorder(side: BorderSide(color: colorScheme.primary.withOpacity(0.3))),
        labelStyle: TextStyle(
          color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
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
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../providers/premium_provider.dart';
import '../theme/app_theme.dart';
import 'add_recipe_screen.dart';
import 'recipe_detail_screen.dart';
import 'paywall_screen.dart';
import 'meal_plan_screen.dart';
import 'profile_screen.dart';
import '../widgets/empty_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
        physics: const NeverScrollableScrollPhysics(),
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
        color: colorScheme.primary,
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
// GREETING HELPERS
// ==============================================================================

String _getGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  if (hour < 21) return 'Good evening';
  return 'Late-night';
}

String _getTimeEmoji() {
  final hour = DateTime.now().hour;
  if (hour < 6) return '🌙';
  if (hour < 12) return '🌅';
  if (hour < 17) return '☀️';
  if (hour < 21) return '🌇';
  return '🌙';
}

String _getFormattedTime() {
  final now = DateTime.now();
  final hour = now.hour;
  final minute = now.minute.toString().padLeft(2, '0');
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
  return '$displayHour:$minute $period';
}

// ==============================================================================
// 1. HOME TAB
// ==============================================================================

class _HomeTab extends StatefulWidget {
  final AnimationController shaderController;

  const _HomeTab({required this.shaderController});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  String _searchQuery = '';
  String? _selectedCategory;
  _StatsFilter _statsFilter = _StatsFilter.week;
  final TextEditingController _searchController = TextEditingController();

  // Canonical category definitions with icons + colors
  static const List<_CategoryDef> _categories = [
    _CategoryDef('Breakfast', Icons.wb_twilight_rounded, Color(0xFFFF9800), ['breakfast', 'morning', 'brunch']),
    _CategoryDef('Lunch', Icons.lunch_dining_rounded, Color(0xFF4CAF50), ['lunch', 'midday']),
    _CategoryDef('Dinner', Icons.dinner_dining_rounded, Color(0xFF3F51B5), ['dinner', 'supper', 'evening']),
    _CategoryDef('Dessert', Icons.cake_outlined, Color(0xFFE91E63), ['dessert', 'sweet', 'cake', 'pastry']),
    _CategoryDef('Snack', Icons.cookie_outlined, Color(0xFF795548), ['snack', 'appetizer', 'bite']),
    _CategoryDef('Quick', Icons.timer_outlined, Color(0xFF009688), ['quick', 'fast', '15 min', '30 min']),
    _CategoryDef('Healthy', Icons.eco_rounded, Color(0xFF8BC34A), ['healthy', 'vegan', 'vegetarian', 'salad']),
    _CategoryDef('Soup', Icons.soup_kitchen_outlined, Color(0xFFFF5722), ['soup', 'stew', 'broth']),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _recipeMatchesCategory(Recipe recipe, _CategoryDef category) {
    final allText = [
      recipe.title.toLowerCase(),
      ...recipe.tags.map((t) => t.toLowerCase()),
    ].join(' ');
    return category.keywords.any((kw) => allText.contains(kw));
  }

  List<Recipe> _filterRecipes(List<Recipe> allRecipes) {
    return allRecipes.where((recipe) {
      final matchesSearch = _searchQuery.isEmpty ||
          recipe.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          recipe.ingredients.any((i) => i.toString().toLowerCase().contains(_searchQuery.toLowerCase())) ||
          recipe.tags.any((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()));

      final matchesCategory = _selectedCategory == null ||
          _recipeMatchesCategory(
            recipe,
            _categories.firstWhere((c) => c.label == _selectedCategory),
          );

      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return CustomScrollView(
      slivers: [
        // ──────────────────────────────────────────────────────────────────────
        // PREMIUM APP BAR with greeting, user name, time
        // ──────────────────────────────────────────────────────────────────────
        SliverAppBar.large(
          centerTitle: false,
          expandedHeight: 160,
          stretch: true,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Animated mesh gradient
                CustomPaint(
                  painter: MeshGradientPainter(
                    animation: widget.shaderController,
                    colors: colorScheme,
                  ),
                ),
                // Light glass overlay
                Container(color: Colors.black.withOpacity(0.15)),
                // Greeting content (only visible when expanded)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 60,
                  child: _ExpandedGreeting(),
                ),
              ],
            ),
            titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            title: _CollapsedAppBarTitle(),
          ),
          actions: [
            Consumer<PremiumProvider>(
              builder: (context, premium, child) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _PremiumBadge(isPremium: premium.isPremium),
                );
              },
            ),
          ],
        ),

        // ──────────────────────────────────────────────────────────────────────
        // ENGAGEMENT STATS CARD
        // ──────────────────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: _EngagementStatsCard(
              filter: _statsFilter,
              onFilterChanged: (f) => setState(() => _statsFilter = f),
            ),
          ),
        ),

        // ──────────────────────────────────────────────────────────────────────
        // SEARCH BAR
        // ──────────────────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: _ModernSearchBar(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
        ),

        // ──────────────────────────────────────────────────────────────────────
        // CATEGORY CHIPS (now matched to recipe tags)
        // ──────────────────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: _CategoryChipsRow(
              categories: _categories,
              selectedCategory: _selectedCategory,
              onCategorySelected: (label) {
                setState(() {
                  _selectedCategory = _selectedCategory == label ? null : label;
                });
              },
              allRecipes: context.watch<RecipeProvider>().recipes,
              matchFn: _recipeMatchesCategory,
            ),
          ),
        ),

        // ──────────────────────────────────────────────────────────────────────
        // SECTION HEADER
        // ──────────────────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: _SectionHeader(
              title: _searchQuery.isNotEmpty
                  ? 'Search Results'
                  : _selectedCategory != null
                  ? '$_selectedCategory Recipes'
                  : 'Recent Collection',
            ),
          ),
        ),

        // ──────────────────────────────────────────────────────────────────────
        // RECIPE GRID (glass cards)
        // ──────────────────────────────────────────────────────────────────────
        Consumer<RecipeProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final displayRecipes = _searchQuery.isEmpty && _selectedCategory == null
                ? provider.recipes.take(20).toList()
                : _filterRecipes(provider.recipes);

            if (displayRecipes.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.no_food_outlined,
                          size: 64,
                          color: colorScheme.primary.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          provider.recipes.isEmpty
                              ? 'Your kitchen is empty.\nTime to add some flavor! 🍳'
                              : 'No recipes found.\nTry a different search.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, index) => _GlassRecipeCard(
                    recipe: displayRecipes[index],
                    isRecent: index < 3,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailScreen(recipe: displayRecipes[index]),
                      ),
                    ),
                  ),
                  childCount: displayRecipes.length,
                ),
              ),
            );
          },
        ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }
}

// ==============================================================================
// EXPANDED GREETING (visible in large app bar)
// ==============================================================================

class _ExpandedGreeting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final displayName = user?.userMetadata?['full_name'] ?? 'Home Chef';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              _getTimeEmoji(),
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 8),
            Text(
              _getFormattedTime(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${_getGreeting()},',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ==============================================================================
// COLLAPSED APP BAR TITLE (when scrolled)
// ==============================================================================

class _CollapsedAppBarTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final displayName = user?.userMetadata?['full_name'] ?? 'Home Chef';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            'What\'s Cooking',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ==============================================================================
// PREMIUM BADGE (AppBar action)
// ==============================================================================

class _PremiumBadge extends StatelessWidget {
  final bool isPremium;

  const _PremiumBadge({required this.isPremium});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isPremium
            ? Colors.amber.withOpacity(0.25)
            : Colors.white.withOpacity(0.15),
        border: Border.all(
          color: isPremium ? Colors.amber : Colors.white.withOpacity(0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPremium ? Icons.verified_rounded : Icons.person_outline_rounded,
            size: 14,
            color: isPremium ? Colors.amber : Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            isPremium ? 'CHEF PRO' : 'BASIC',
            style: TextStyle(
              color: isPremium ? Colors.amber : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================================================================
// ENGAGEMENT STATS CARD
// ==============================================================================

enum _StatsFilter { week, month, allTime }

class _EngagementStatsCard extends StatelessWidget {
  final _StatsFilter filter;
  final ValueChanged<_StatsFilter> onFilterChanged;

  const _EngagementStatsCard({
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<RecipeProvider>(
      builder: (context, provider, _) {
        final now = DateTime.now();
        final allRecipes = provider.recipes;

        // Calculate cooked count by filter
        final cooked = allRecipes.where((r) {
          if (!r.isCooked) return false;
          if (r.cookedDate == null) return false;
          switch (filter) {
            case _StatsFilter.week:
              return now.difference(r.cookedDate!).inDays <= 7;
            case _StatsFilter.month:
              return now.difference(r.cookedDate!).inDays <= 30;
            case _StatsFilter.allTime:
              return true;
          }
        }).toList();

        final saved = allRecipes.where((r) => r.wantToCook).toList();
        final total = allRecipes.length;

        // Cooking streak (consecutive days with cooked recipes)
        final streak = _calculateStreak(allRecipes);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withOpacity(0.08),
                colorScheme.secondary.withOpacity(0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.15),
              width: 1.2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row with filter
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.local_fire_department_rounded,
                                color: colorScheme.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Cooking Activity',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        // Filter toggle
                        _StatsFilterToggle(
                          selected: filter,
                          onChanged: onFilterChanged,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Stats row
                    Row(
                      children: [
                        _StatTile(
                          value: cooked.length.toString(),
                          label: filter == _StatsFilter.week
                              ? 'Cooked\nthis week'
                              : filter == _StatsFilter.month
                              ? 'Cooked\nthis month'
                              : 'Total\nCooked',
                          icon: Icons.check_circle_outline_rounded,
                          color: const Color(0xFF4CAF50),
                        ),
                        _StatDivider(),
                        _StatTile(
                          value: streak.toString(),
                          label: 'Day\nStreak 🔥',
                          icon: Icons.local_fire_department_rounded,
                          color: const Color(0xFFFF5722),
                        ),
                        _StatDivider(),
                        _StatTile(
                          value: saved.length.toString(),
                          label: 'Want to\nCook',
                          icon: Icons.bookmark_border_rounded,
                          color: const Color(0xFF2196F3),
                        ),
                        _StatDivider(),
                        _StatTile(
                          value: total.toString(),
                          label: 'Total\nCollected',
                          icon: Icons.collections_bookmark_outlined,
                          color: AppTheme.seedColor,
                        ),
                      ],
                    ),

                    if (cooked.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      // Mini activity bar chart
                      _ActivityMiniChart(
                        recipes: allRecipes,
                        filter: filter,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int _calculateStreak(List<Recipe> recipes) {
    final cookedDates = recipes
        .where((r) => r.isCooked && r.cookedDate != null)
        .map((r) => DateTime(r.cookedDate!.year, r.cookedDate!.month, r.cookedDate!.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (cookedDates.isEmpty) return 0;

    int streak = 0;
    DateTime check = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    for (final date in cookedDates) {
      if (date == check || date == check.subtract(const Duration(days: 1))) {
        streak++;
        check = date.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.55),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _StatsFilterToggle extends StatelessWidget {
  final _StatsFilter selected;
  final ValueChanged<_StatsFilter> onChanged;

  const _StatsFilterToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final labels = {
      _StatsFilter.week: '7D',
      _StatsFilter.month: '30D',
      _StatsFilter.allTime: 'All',
    };

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _StatsFilter.values.map((f) {
          final isSelected = f == selected;
          return GestureDetector(
            onTap: () => onChanged(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                labels[f]!,
                style: TextStyle(
                  color: isSelected ? Colors.white : colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActivityMiniChart extends StatelessWidget {
  final List<Recipe> recipes;
  final _StatsFilter filter;

  const _ActivityMiniChart({required this.recipes, required this.filter});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final days = filter == _StatsFilter.week ? 7 : 30;
    final now = DateTime.now();

    // Build a map of day offset -> cooked count
    final Map<int, int> dayCounts = {};
    for (int i = 0; i < days; i++) {
      dayCounts[i] = 0;
    }
    for (final r in recipes) {
      if (!r.isCooked || r.cookedDate == null) continue;
      final diff = now.difference(r.cookedDate!).inDays;
      if (diff >= 0 && diff < days) {
        dayCounts[diff] = (dayCounts[diff] ?? 0) + 1;
      }
    }

    final maxVal = dayCounts.values.fold(0, math.max).toDouble();
    if (maxVal == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cooking frequency',
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurface.withOpacity(0.45),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 32,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(days, (i) {
              final idx = days - 1 - i;
              final count = dayCounts[idx] ?? 0;
              final heightFrac = maxVal > 0 ? count / maxVal : 0.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300 + i * 10),
                    curve: Curves.easeOut,
                    height: 4 + (28 * heightFrac),
                    decoration: BoxDecoration(
                      color: count > 0
                          ? colorScheme.primary.withOpacity(0.3 + 0.7 * heightFrac)
                          : colorScheme.outline.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ==============================================================================
// CATEGORY DEFINITION MODEL
// ==============================================================================

class _CategoryDef {
  final String label;
  final IconData icon;
  final Color color;
  final List<String> keywords;

  const _CategoryDef(this.label, this.icon, this.color, this.keywords);
}

// ==============================================================================
// CATEGORY CHIPS ROW (with per-category counts)
// ==============================================================================

class _CategoryChipsRow extends StatelessWidget {
  final List<_CategoryDef> categories;
  final String? selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final List<Recipe> allRecipes;
  final bool Function(Recipe, _CategoryDef) matchFn;

  const _CategoryChipsRow({
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.allRecipes,
    required this.matchFn,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: categories.map((cat) {
          final isSelected = selectedCategory == cat.label;
          final count = allRecipes.where((r) => matchFn(r, cat)).length;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cat.label),
                    if (count > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.3)
                              : cat.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : cat.color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                avatar: Icon(
                  cat.icon,
                  size: 16,
                  color: isSelected ? Colors.white : cat.color,
                ),
                selected: isSelected,
                onSelected: (_) => onCategorySelected(cat.label),
                backgroundColor: cat.color.withOpacity(0.07),
                selectedColor: cat.color,
                checkmarkColor: Colors.white,
                showCheckmark: false,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: isSelected ? cat.color : cat.color.withOpacity(0.3),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : cat.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ==============================================================================
// GLASS RECIPE CARD (premium feel with glassmorphism)
// ==============================================================================

class _GlassRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final bool isRecent;

  const _GlassRecipeCard({
    required this.recipe,
    required this.onTap,
    this.isRecent = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Pick a deterministic gradient from recipe title hash
    final gradients = [
      [const Color(0xFF2D6A4F), const Color(0xFF40916C)],
      [const Color(0xFF1D3557), const Color(0xFF457B9D)],
      [const Color(0xFF6D2D2D), const Color(0xFFB5534E)],
      [const Color(0xFF4A3728), const Color(0xFF7D5A50)],
      [const Color(0xFF1A3C40), const Color(0xFF2D7D6F)],
    ];
    final gradIdx = recipe.title.hashCode.abs() % gradients.length;
    final grad = gradients[gradIdx];

    // Category tag to show on card
    final cardTag = recipe.tags.isNotEmpty ? recipe.tags.first : null;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background: image or gradient ──
            if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty)
              Image.network(
                recipe.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _GradientBackground(colors: grad),
              )
            else
              _GradientBackground(colors: grad),

            // ── Dark vignette overlay ──
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.70),
                  ],
                  stops: const [0.3, 0.6, 1.0],
                ),
              ),
            ),

            // ── Top row: RECENT badge + cooked checkmark ──
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isRecent)
                    _GlassBadge(
                      label: 'New',
                      color: const Color(0xFFE0B97F),
                      textColor: Colors.black87,
                    )
                  else if (cardTag != null)
                    _GlassBadge(label: cardTag)
                  else
                    const SizedBox.shrink(),

                  if (recipe.isCooked)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.85),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.5)),
                      ),
                      child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                    ),
                ],
              ),
            ),

            // ── Bottom content: title + meta ──
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.0),
                          Colors.black.withOpacity(0.55),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          recipe.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            height: 1.3,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (recipe.ingredients.isNotEmpty) ...[
                              Icon(
                                Icons.restaurant_outlined,
                                size: 11,
                                color: Colors.white.withOpacity(0.75),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${recipe.ingredients.length} ingredients',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (recipe.wantToCook)
                              Icon(
                                Icons.bookmark_rounded,
                                size: 14,
                                color: const Color(0xFFE0B97F).withOpacity(0.9),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Ink ripple effect ──
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(22),
                  splashColor: Colors.white.withOpacity(0.1),
                  highlightColor: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientBackground extends StatelessWidget {
  final List<Color> colors;

  const _GradientBackground({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          size: 48,
          color: Colors.white.withOpacity(0.15),
        ),
      ),
    );
  }
}

class _GlassBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;

  const _GlassBadge({required this.label, this.color, this.textColor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: (color ?? Colors.white).withOpacity(0.25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (color ?? Colors.white).withOpacity(0.4),
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: textColor ?? Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
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
          centerTitle: false,
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
            childAspectRatio: 0.72,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            return _GlassRecipeCard(
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
        border: Border.all(color: colorScheme.outline.withOpacity(0.15)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          icon: Icon(Icons.search, color: colorScheme.primary),
          hintText: 'Search recipes, ingredients, tags...',
          hintStyle: TextStyle(
            color: colorScheme.primary.withOpacity(0.55),
            fontSize: 15,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          suffixIcon: controller != null && (controller!.text.isNotEmpty)
              ? IconButton(
            icon: Icon(Icons.clear_rounded, color: colorScheme.primary.withOpacity(0.5), size: 18),
            onPressed: () {
              controller!.clear();
              onChanged?.call('');
            },
          )
              : null,
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
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Icon(Icons.arrow_forward_ios_rounded, size: 16, color: theme.colorScheme.primary.withOpacity(0.5)),
      ],
    );
  }
}

// ==============================================================================
// ADD RECIPE BOTTOM SHEET (unchanged, preserved exactly)
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
                      ],
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
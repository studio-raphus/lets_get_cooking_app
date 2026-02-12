import 'dart:ui'; // Required for BackdropFilter
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/premium_provider.dart';
import '../providers/recipe_provider.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../services/grocery_list_generator.dart';
import '../widgets/grocery_list_sheet.dart';
import 'recipe_detail_screen.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> with SingleTickerProviderStateMixin {
  late AnimationController _shaderController;

  // State: Day Index (0 = Mon, 6 = Sun) -> { MealType -> Recipe }
  final Map<int, Map<String, Recipe>> _weeklyPlan = {};

  int _selectedDayIndex = 0; // 0 = Monday
  final List<String> _mealTypes = ['Breakfast', 'Lunch', 'Dinner'];
  DateTime _currentWeekStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    _shaderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    // Calculate start of this week (Monday)
    final now = DateTime.now();
    _currentWeekStart = now.subtract(Duration(days: now.weekday - 1));

    // Set selected day to today (if within range)
    _selectedDayIndex = (now.weekday - 1).clamp(0, 6);
  }

  @override
  void dispose() {
    _shaderController.dispose();
    super.dispose();
  }

  // --- Actions ---

  void _addMeal(String mealType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecipePickerSheet(
        onSelect: (recipe) {
          setState(() {
            if (_weeklyPlan[_selectedDayIndex] == null) {
              _weeklyPlan[_selectedDayIndex] = {};
            }
            _weeklyPlan[_selectedDayIndex]![mealType] = recipe;
          });
        },
      ),
    );
  }

  void _removeMeal(String mealType) {
    setState(() {
      _weeklyPlan[_selectedDayIndex]?.remove(mealType);
    });
  }

  // --- IMPROVED AUTO-FILL ALGORITHM ---
  void _autoFillWeek() {
    final recipeProvider = context.read<RecipeProvider>();
    final allRecipes = recipeProvider.recipes;

    if (allRecipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Add recipes to your cookbook first!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() {
      final random = List<Recipe>.from(allRecipes)..shuffle();

      // Helper sets to ensure variety
      final Set<String> recipesUsedThisWeek = {};

      for (int day = 0; day < 7; day++) {
        _weeklyPlan[day] ??= {};

        // Track what we've eaten TODAY to prevent B/L/D duplicates
        final Set<String> recipesUsedToday = {};

        // Pre-fill "Used Today" if user manually added stuff
        _weeklyPlan[day]!.values.forEach((r) => recipesUsedToday.add(r.id));

        for (var type in _mealTypes) {
          // Skip if slot is already filled manually
          if (_weeklyPlan[day]!.containsKey(type)) continue;

          Recipe? selected;

          // Filter candidates:
          // 1. Must not be used TODAY.
          // 2. Ideally matches the meal type tag.

          List<Recipe> candidates = random.where((r) => !recipesUsedToday.contains(r.id)).toList();

          // Try to find a typed match (e.g., "Breakfast")
          try {
            selected = candidates.firstWhere((r) =>
            r.tags.any((t) => t.toLowerCase().contains(type.toLowerCase())) &&
                !recipesUsedThisWeek.contains(r.id) // Prefer unrepeated meals
            );
          } catch (_) {
            // Fallback: Try matching type, even if repeated in week
            try {
              selected = candidates.firstWhere((r) =>
                  r.tags.any((t) => t.toLowerCase().contains(type.toLowerCase()))
              );
            } catch (_) {}
          }

          // Fallback: No tag match? Just pick a random one that isn't used today
          if (selected == null && candidates.isNotEmpty) {
            // Try to pick one not used this week first
            try {
              selected = candidates.firstWhere((r) => !recipesUsedThisWeek.contains(r.id));
            } catch (_) {
              // Last resort: pick the first available candidate
              selected = candidates.first;
            }
          }

          if (selected != null) {
            _weeklyPlan[day]![type] = selected;
            recipesUsedToday.add(selected.id);
            recipesUsedThisWeek.add(selected.id);
          }
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✨ Menu planned! No daily duplicates.'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _generateGroceryList() async {
    final List<Recipe> allWeeklyRecipes = [];
    _weeklyPlan.forEach((day, meals) {
      allWeeklyRecipes.addAll(meals.values);
    });

    if (allWeeklyRecipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan some meals first!'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final generator = GroceryListGenerator();
    final items = generator.generateFromRecipes(allWeeklyRecipes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GroceryListSheet(initialItems: items),
    );
  }

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    return Consumer<PremiumProvider>(
      builder: (context, premiumProvider, _) {
        if (!premiumProvider.canUseMealPlanning()) {
          return _buildPremiumUpsell(context);
        }
        return _buildMealPlanContent(context);
      },
    );
  }

  Widget _buildMealPlanContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true, // Needed for full screen gradient
      appBar: AppBar(
        title: Text('Smart Meal Planner', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton.filledTonal(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Auto-Fill Week',
            onPressed: _autoFillWeek,
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton.outlined(
              icon: const Icon(Icons.shopping_cart_checkout),
              tooltip: 'Create Grocery List',
              onPressed: _generateGroceryList,
              style: IconButton.styleFrom(
                side: BorderSide(color: colorScheme.onSurface.withOpacity(0.2)),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Animated Mesh Gradient
          Positioned.fill(
            child: CustomPaint(
              painter: MeshGradientPainter(
                animation: _shaderController,
                colors: colorScheme,
              ),
            ),
          ),

          // 2. Frosted Glass Overlay (for readability)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: colorScheme.surface.withOpacity(0.6), // Semi-transparent surface
              ),
            ),
          ),

          // 3. Content
          SafeArea(
            child: Column(
              children: [
                // Date Strip (Glassy)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: _buildWeekStrip(theme),
                ),

                // Scrollable Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                    children: [
                      _buildDateHeader(theme),
                      const SizedBox(height: 24),
                      ..._mealTypes.map((type) => _buildMealSlot(type, theme)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generateGroceryList,
        icon: const Icon(Icons.shopping_basket),
        label: const Text('Shop This Week'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
      ),
    );
  }

  Widget _buildWeekStrip(ThemeData theme) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final colorScheme = theme.colorScheme;

    return SizedBox(
      height: 65,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = _selectedDayIndex == index;
          final date = _currentWeekStart.add(Duration(days: index));
          final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month;

          return GestureDetector(
            onTap: () => setState(() => _selectedDayIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary
                    : (isToday ? colorScheme.primaryContainer.withOpacity(0.5) : Colors.transparent),
                borderRadius: BorderRadius.circular(25),
                border: isSelected || isToday
                    ? null
                    : Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    days[index],
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date.day.toString(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateHeader(ThemeData theme) {
    final date = _currentWeekStart.add(Duration(days: _selectedDayIndex));
    final formatter = DateFormat('EEEE, MMMM d');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        formatter.format(date),
        style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
            shadows: [
              Shadow(offset: const Offset(0, 2), blurRadius: 4, color: Colors.black.withOpacity(0.1)),
            ]
        ),
      ),
    );
  }

  Widget _buildMealSlot(String type, ThemeData theme) {
    final recipe = _weeklyPlan[_selectedDayIndex]?[type];
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              type,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          if (recipe != null)
          // FILLED STATE: Glass Card
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: recipe)),
                  ),
                  borderRadius: BorderRadius.circular(16),
                  child: Dismissible(
                    key: ValueKey('${_selectedDayIndex}_$type'),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _removeMeal(type),
                    background: Container(
                      alignment: Alignment.centerRight,
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.only(right: 20),
                      child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                          child: SizedBox(
                            width: 100,
                            height: 100,
                            child: recipe.imageUrl != null
                                ? Image.network(recipe.imageUrl!, fit: BoxFit.cover)
                                : Container(
                              color: colorScheme.primaryContainer,
                              child: Icon(Icons.restaurant, color: colorScheme.onPrimaryContainer),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  recipe.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.schedule, size: 16, color: colorScheme.secondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      recipe.cookTime ?? '30m',
                                      style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.secondary),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
          // EMPTY STATE: Dashed/Glassy Outline
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _addMeal(type),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colorScheme.outlineVariant.withOpacity(0.5),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withOpacity(0.2), // Subtle fill
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline_rounded, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Add ${type}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Premium Upsell ---
  Widget _buildPremiumUpsell(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: MeshGradientPainter(
              animation: _shaderController,
              colors: colorScheme,
            ),
          ),
        ),
        Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.8),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_month_rounded, size: 64, color: colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  'Unlock Smart Planning',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Automate your weekly menu with smart logic that avoids repeating meals.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () {
                    // Trigger purchase flow
                  },
                  icon: const Icon(Icons.star_rounded),
                  label: const Text('Upgrade to Premium'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- Helper: Recipe Picker Sheet ---
class _RecipePickerSheet extends StatefulWidget {
  final Function(Recipe) onSelect;
  const _RecipePickerSheet({required this.onSelect});

  @override
  State<_RecipePickerSheet> createState() => _RecipePickerSheetState();
}

class _RecipePickerSheetState extends State<_RecipePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<RecipeProvider>();

    final recipes = provider.recipes.where((r) => r.title.toLowerCase().contains(_query.toLowerCase())).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search cookbook...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onChanged: (val) => setState(() => _query = val),
            ),
          ),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: recipes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final recipe = recipes[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: colorScheme.primaryContainer,
                      image: recipe.imageUrl != null
                          ? DecorationImage(image: NetworkImage(recipe.imageUrl!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: recipe.imageUrl == null
                        ? Icon(Icons.restaurant, color: colorScheme.onPrimaryContainer)
                        : null,
                  ),
                  title: Text(
                    recipe.title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${recipe.ingredients.length} ingredients',
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  onTap: () {
                    widget.onSelect(recipe);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
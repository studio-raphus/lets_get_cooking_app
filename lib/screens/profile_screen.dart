import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../providers/recipe_provider.dart';
import '../providers/premium_provider.dart';
import '../widgets/recipe_card.dart';
import 'paywall_screen.dart';
import 'recipe_detail_screen.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _shaderController;
  final _nameController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;

  // Supabase instance
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // 1. Initialize Mesh Gradient Animation
    _shaderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    // 2. Load initial user data
    final user = _supabase.auth.currentUser;
    if (user != null) {
      // Fetch 'full_name' or 'name' from metadata, default to 'Chef'
      _nameController.text = user.userMetadata?['full_name'] ?? 'Home Chef';
    }
  }

  @override
  void dispose() {
    _shaderController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // LOGIC
  // ===========================================================================

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      // Update Supabase User Metadata
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {'full_name': _nameController.text.trim()},
        ),
      );

      setState(() {
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (mounted) {
      // Navigate to Welcome/Login screen and remove all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
      );
    }
  }

  // ===========================================================================
  // UI BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = _supabase.auth.currentUser;

    return Stack(
      children: [
        // ---------------------------------------------------------------------
        // LAYER 1: Mesh Gradient Background
        // ---------------------------------------------------------------------
        Positioned.fill(
          child: CustomPaint(
            painter: MeshGradientPainter(
              animation: _shaderController,
              colors: colorScheme,
            ),
          ),
        ),

        // ---------------------------------------------------------------------
        // LAYER 2: Glass Overlay (Optional, for readability)
        // ---------------------------------------------------------------------
        Positioned.fill(
          child: Container(
            color: colorScheme.surface.withOpacity(0.3), // High opacity for readability
          ),
        ),

        // ---------------------------------------------------------------------
        // LAYER 3: Content
        // ---------------------------------------------------------------------
        Scaffold(
          backgroundColor: Colors.transparent, // Let gradient show through
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('My Kitchen'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: _signOut,
                tooltip: 'Sign Out',
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. PROFILE HEADER
                _buildProfileHeader(theme, user),

                const SizedBox(height: 32),

                // 2. SUBSCRIPTION CARD
                _buildSubscriptionCard(theme),

                const SizedBox(height: 32),

                // 3. STATS ROW
                _buildStatsRow(theme),

                const SizedBox(height: 32),

                // 4. RECENT ACTIVITY
                Text(
                  'Recent Activity',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRecentActivityList(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(ThemeData theme, User? user) {
    return Center(
      child: Column(
        children: [
          // Avatar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.primary, width: 2),
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                (_nameController.text.isNotEmpty ? _nameController.text[0] : 'U').toUpperCase(),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Editable Name
          if (_isEditing)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _nameController,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                IconButton(
                  icon: _isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: _isLoading ? null : _updateProfile,
                ),
              ],
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _nameController.text,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 20, color: theme.colorScheme.primary),
                  onPressed: () => setState(() => _isEditing = true),
                ),
              ],
            ),

          // Email
          Text(
            user?.email ?? 'No email',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(ThemeData theme) {
    return Consumer<PremiumProvider>(
      builder: (context, premium, child) {
        final isPremium = premium.isPremium;
        // Assuming your PremiumProvider has a getter 'isPremium'

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            // Use primary color for premium feel, or surface variant for free
            gradient: isPremium
                ? LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.tertiary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : null,
            color: isPremium ? null : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isPremium ? Colors.transparent : theme.colorScheme.outlineVariant,
            ),
            boxShadow: isPremium
                ? [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]
                : [],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPremium ? 'PREMIUM CHEF' : 'BASIC PLAN',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: isPremium ? Colors.white70 : theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPremium ? 'Unlimited Access' : 'Limited Recipes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isPremium ? Colors.white : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    isPremium ? Icons.verified : Icons.lock_open,
                    color: isPremium ? Colors.white : theme.colorScheme.outline,
                    size: 32,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // Navigate to Paywall or Manage Subscription
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaywallScreen(
                          feature: isPremium ? 'Manage Subscription' : 'Upgrade to Premium',
                        ),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: isPremium
                        ? Colors.white
                        : theme.colorScheme.primary,
                    foregroundColor: isPremium
                        ? theme.colorScheme.primary
                        : Colors.white,
                  ),
                  child: Text(isPremium ? 'Manage Subscription' : 'Get Premium'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(ThemeData theme) {
    return Consumer<RecipeProvider>(
      builder: (context, provider, _) {
        final cookedCount = provider.cookedRecipes.length;
        final savedCount = provider.wantToCookRecipes.length;
        // Total recipes in history (just an example metric)
        final totalCount = provider.recipes.length;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(theme, count: totalCount.toString(), label: 'Collected'),
            _buildVerticalDivider(theme),
            _buildStatItem(theme, count: cookedCount.toString(), label: 'Cooked'),
            _buildVerticalDivider(theme),
            _buildStatItem(theme, count: savedCount.toString(), label: 'Planned'),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(ThemeData theme, {required String count, required String label}) {
    return Column(
      children: [
        Text(
          count,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider(ThemeData theme) {
    return Container(
      height: 40,
      width: 1,
      color: theme.colorScheme.outlineVariant,
    );
  }

  Widget _buildRecentActivityList() {
    return Consumer<RecipeProvider>(
      builder: (context, provider, _) {
        // Just showing the last 5 added recipes
        final recentRecipes = provider.recipes.reversed.take(5).toList();

        if (recentRecipes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No recent activity yet!',
                style: TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
            ),
          );
        }

        return SizedBox(
          height: 260, // Height for the horizontal list
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: recentRecipes.length,
            clipBehavior: Clip.none,
            itemBuilder: (context, index) {
              final recipe = recentRecipes[index];
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 16),
                child: RecipeCard(
                  recipe: recipe,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailScreen(recipe: recipe),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
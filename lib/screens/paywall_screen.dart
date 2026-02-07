import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../providers/premium_provider.dart';
import '../theme/app_theme.dart';

class PaywallScreen extends StatefulWidget {
  final String? feature;

  const PaywallScreen({super.key, this.feature});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _shaderController;

  @override
  void initState() {
    super.initState();
    _shaderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shaderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Animated Mesh Gradient Background
          Positioned.fill(
            child: CustomPaint(
              painter: MeshGradientPainter(
                animation: _shaderController,
                colors: Theme.of(context).colorScheme,
              ),
              child: Container(color: Colors.white.withOpacity(0.4)),
            ),
          ),

          SafeArea(
            child: Consumer<PremiumProvider>(
              builder: (context, premiumProvider, _) {
                if (premiumProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (premiumProvider.isRevenueCatConfigured &&
                    premiumProvider.offerings != null &&
                    premiumProvider.offerings!.current != null) {
                  return _buildRealPaywall(context, premiumProvider);
                } else {
                  return _buildDemoPaywall(context, premiumProvider);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealPaywall(BuildContext context, PremiumProvider premiumProvider) {
    final offering = premiumProvider.offerings!.current!;
    final packages = offering.availablePackages;
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildHeader(context),
                const SizedBox(height: 40),
                _buildBenefitsList(context),
                const SizedBox(height: 40),

                // Package Selection
                ...packages.map((package) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildPackageCard(context, package, () {
                    _purchasePackage(context, premiumProvider, package);
                  }),
                )),
              ],
            ),
          ),
        ),
        _buildRestoreButton(context, premiumProvider),
      ],
    );
  }

  Widget _buildDemoPaywall(BuildContext context, PremiumProvider premiumProvider) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildHeader(context),
          const SizedBox(height: 40),
          _buildBenefitsList(context),
          const Spacer(),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Store not connected. Please configure RevenueCat.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.auto_awesome, size: 40, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 24),
        Text(
          'Unlock Premium Kitchen',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.feature != null) ...[
          const SizedBox(height: 8),
          Text(
            'Get access to ${widget.feature} and more!',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildBenefitsList(BuildContext context) {
    return Column(
      children: [
        _buildBenefitRow(context, 'Unlimited Recipes', Icons.all_inclusive),
        _buildBenefitRow(context, 'AI Link Import (Insta/TikTok)', Icons.link),
        _buildBenefitRow(context, 'Photo Scan to Recipe', Icons.camera_alt),
        _buildBenefitRow(context, 'Smart Grocery Lists', Icons.shopping_cart_checkout),
      ],
    );
  }

  Widget _buildBenefitRow(BuildContext context, String text, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 24),
          const SizedBox(width: 16),
          Text(text, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildPackageCard(BuildContext context, Package package, VoidCallback onTap) {
    final theme = Theme.of(context);
    final product = package.storeProduct;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface.withOpacity(0.8), // Semi-transparent
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      product.description,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    product.priceString,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'BEST VALUE', // You can add logic to toggle this
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestoreButton(BuildContext context, PremiumProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextButton(
        onPressed: () async {
          await provider.restorePurchases();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Purchases restored')),
            );
          }
        },
        child: Text(
          'Restore Purchases',
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }

  Future<void> _purchasePackage(
      BuildContext context, PremiumProvider provider, Package package) async {
    final success = await provider.purchasePackage(package);
    if (context.mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Welcome to Premium!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
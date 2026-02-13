import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';

class WardSelectionScreen extends StatefulWidget {
  const WardSelectionScreen({super.key});

  @override
  State<WardSelectionScreen> createState() => _WardSelectionScreenState();
}

class _WardSelectionScreenState extends State<WardSelectionScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh user data to pick up wards created by coaching admin
    Future.microtask(() {
      context.read<AuthController>().refreshUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authController = context.watch<AuthController>();
    final user = authController.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final wards = user.wards;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Who\'s learning today?',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a profile to continue',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 48),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 32,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: wards.length + 1, // +1 for Parent profile
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Parent Profile
                      return _buildProfileItem(
                        context,
                        name: 'Parent (${user.name ?? "Me"})',
                        picture: user.picture,
                        isSelected: authController.activeWard == null,
                        onTap: () => authController.selectWard(null),
                      );
                    }

                    final ward = wards[index - 1];
                    return _buildProfileItem(
                      context,
                      name: ward.name,
                      picture: ward.picture,
                      isSelected: authController.activeWard?.id == ward.id,
                      onTap: () => authController.selectWard(ward),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  // TODO: Implement ward creation
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create New Profile'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.3),
                  foregroundColor: theme.colorScheme.primary,
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileItem(
    BuildContext context, {
    required String name,
    String? picture,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: theme.colorScheme.primary, width: 3)
                      : Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                          width: 1,
                        ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.2,
                            ),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: ClipOval(
                  child: picture != null
                      ? Image.network(picture, fit: BoxFit.cover)
                      : Container(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.3,
                          ),
                          child: Icon(
                            Icons.person_outline_rounded,
                            size: 40,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? theme.colorScheme.primary : null,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

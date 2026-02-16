import 'package:flutter/material.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../profile/services/user_service.dart';
import '../models/coaching_model.dart';
import '../services/coaching_service.dart';

class CreateCoachingScreen extends StatefulWidget {
  final void Function(CoachingModel, UserModel)? onCoachingCreated;

  const CreateCoachingScreen({super.key, this.onCoachingCreated});

  @override
  State<CreateCoachingScreen> createState() => _CreateCoachingScreenState();
}

class _CreateCoachingScreenState extends State<CreateCoachingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final CoachingService _coachingService = CoachingService();
  final UserService _userService = UserService();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createCoaching() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final coaching = await _coachingService.createCoaching(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      if (coaching != null) {
        final updatedUser = await _userService.getMe();
        if (mounted) {
          if (widget.onCoachingCreated != null && updatedUser != null) {
            widget.onCoachingCreated!(coaching, updatedUser);
          }
          AppAlert.success(context, '${coaching.name} created successfully!');
          Navigator.pop(context, coaching);
        }
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, e, fallback: 'Failed to create coaching');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Launch Institute',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderIllustration(),
              const SizedBox(height: 40),

              // Name
              _buildField(
                controller: _nameController,
                label: 'Institute Name',
                hint: 'e.g., Apex Academy',
                icon: Icons.school_rounded,
                capitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please provide a name';
                  }
                  if (v.trim().length < 3) return 'Name is too short';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Description
              _buildField(
                controller: _descriptionController,
                label: 'Mission & Description',
                hint: 'Briefly describe your vision...',
                icon: Icons.auto_awesome_rounded,
                capitalization: TextCapitalization.sentences,
                maxLines: 4,
              ),
              const SizedBox(height: 32),

              // Info note
              _InfoNote(),
              const SizedBox(height: 48),

              // Submit
              FilledButton(
                onPressed: _isLoading ? null : _createCoaching,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Launch Institute',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextCapitalization capitalization = TextCapitalization.none,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: capitalization,
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: theme.colorScheme.primary),
        filled: true,
        fillColor: theme.colorScheme.tertiary.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        alignLabelWithHint: maxLines > 1,
      ),
      validator: validator,
    );
  }
}

// ── Private sub-widgets ──────────────────────────────────────────────────

class _HeaderIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  blurRadius: 15,
                ),
              ],
            ),
            child: Icon(
              Icons.rocket_launch_rounded,
              size: 48,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tutorix Institute',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary.withValues(alpha: 0.8),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.shield_rounded,
            size: 20,
            color: theme.colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'As the founder, you have full administrative control over curriculum and admissions.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

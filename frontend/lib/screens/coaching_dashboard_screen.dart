import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/coaching_service.dart';
import '../services/invitation_service.dart';

class CoachingDashboardScreen extends StatefulWidget {
  final CoachingModel coaching;
  final UserModel user;

  const CoachingDashboardScreen({
    super.key,
    required this.coaching,
    required this.user,
  });

  @override
  State<CoachingDashboardScreen> createState() =>
      _CoachingDashboardScreenState();
}

class _CoachingDashboardScreenState extends State<CoachingDashboardScreen> {
  int _selectedIndex = 0;
  late CoachingModel _coaching;
  final _coachingService = CoachingService();
  List<Map<String, dynamic>> _members = [];
  bool _membersLoading = true;

  @override
  void initState() {
    super.initState();
    _coaching = widget.coaching;
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await _coachingService.getMembers(_coaching.id);
      if (mounted) {
        setState(() {
          _members = members;
          _membersLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _membersLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          _coaching.name,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Members',
          ),
          NavigationDestination(
            icon: Icon(Icons.class_outlined),
            selectedIcon: Icon(Icons.class_rounded),
            label: 'Classes',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildOverview();
      case 1:
        return _buildMembers();
      case 2:
        return _buildClasses();
      case 3:
        return _buildSettings();
      default:
        return _buildOverview();
    }
  }

  // ──────────────────── Overview ────────────────────
  Widget _buildOverview() {
    return _emptyPage(
      icon: Icons.dashboard_rounded,
      title: 'Overview',
      subtitle: 'Dashboard analytics coming soon',
    );
  }

  // ──────────────────── Members ────────────────────
  Widget _buildMembers() {
    final theme = Theme.of(context);

    if (_membersLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Group members by role
    final teachers = _members
        .where((m) => m['role'] == 'TEACHER' || m['role'] == 'ADMIN')
        .toList();
    final parents = _members
        .where(
          (m) =>
              m['role'] == 'PARENT' ||
              (m['user'] != null &&
                  m['user']['isParent'] == true &&
                  m['role'] != 'TEACHER' &&
                  m['role'] != 'ADMIN'),
        )
        .toList();
    final studentWards = _members
        .where((m) => m['role'] == 'STUDENT' && m['ward'] != null)
        .toList();
    // Standalone students (user-based, not wards)
    final standaloneStudents = _members
        .where((m) => m['role'] == 'STUDENT' && m['ward'] == null)
        .toList();

    // Build parent UID -> list of ward members map
    final Map<String, List<Map<String, dynamic>>> parentWardMap = {};
    for (final wm in studentWards) {
      final parentId = wm['ward']?['parentId'] as String?;
      if (parentId != null) {
        parentWardMap.putIfAbsent(parentId, () => []).add(wm);
      }
    }

    // Collect unique parent users from parent members
    final parentUsers = <String, Map<String, dynamic>>{};
    for (final pm in parents) {
      final user = pm['user'] as Map<String, dynamic>?;
      if (user != null) {
        parentUsers[user['id'] as String] = user;
      }
    }
    // Also add parents from ward records not in the parent members list
    for (final wm in studentWards) {
      final parent = wm['ward']?['parent'] as Map<String, dynamic>?;
      if (parent != null) {
        parentUsers.putIfAbsent(parent['id'] as String, () => parent);
      }
    }

    final hasAny =
        teachers.isNotEmpty ||
        parentUsers.isNotEmpty ||
        standaloneStudents.isNotEmpty;

    return Stack(
      children: [
        if (!hasAny)
          _emptyPage(
            icon: Icons.people_outline_rounded,
            title: 'No members yet',
            subtitle: 'Tap + to invite teachers, parents or students',
          )
        else
          RefreshIndicator(
            onRefresh: _loadMembers,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                // Teachers
                if (teachers.isNotEmpty) ...[
                  _sectionHeader(
                    'Teachers',
                    Icons.school_rounded,
                    teachers.length,
                  ),
                  const SizedBox(height: 8),
                  ...teachers.map((m) => _memberTile(m, theme)),
                  const SizedBox(height: 20),
                ],
                // Parents & Wards
                if (parentUsers.isNotEmpty) ...[
                  _sectionHeader(
                    'Parents & Wards',
                    Icons.family_restroom_rounded,
                    parentUsers.length,
                  ),
                  const SizedBox(height: 8),
                  ...parentUsers.entries.map((entry) {
                    final parentId = entry.key;
                    final parent = entry.value;
                    final wards = parentWardMap[parentId] ?? [];
                    return _parentCard(parent, wards, theme);
                  }),
                  const SizedBox(height: 20),
                ],
                // Standalone students
                if (standaloneStudents.isNotEmpty) ...[
                  _sectionHeader(
                    'Students',
                    Icons.person_rounded,
                    standaloneStudents.length,
                  ),
                  const SizedBox(height: 8),
                  ...standaloneStudents.map((m) => _memberTile(m, theme)),
                ],
              ],
            ),
          ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            heroTag: 'invite_fab',
            onPressed: () => _showInviteSheet(context),
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Invite'),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon, int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberTile(Map<String, dynamic> member, ThemeData theme) {
    final user = member['user'] as Map<String, dynamic>?;
    final ward = member['ward'] as Map<String, dynamic>?;
    final name = user?['name'] ?? ward?['name'] ?? 'Unknown';
    final email = user?['email'] as String?;
    final pic = user?['picture'] ?? ward?['picture'];
    final role = member['role'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: pic != null ? NetworkImage(pic as String) : null,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: pic == null
                ? Text(
                    (name as String).isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(color: theme.colorScheme.primary),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name as String,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (email != null)
                  Text(
                    email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _roleColor(role).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              role,
              style: theme.textTheme.labelSmall?.copyWith(
                color: _roleColor(role),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _parentCard(
    Map<String, dynamic> parent,
    List<Map<String, dynamic>> wards,
    ThemeData theme,
  ) {
    final name = parent['name'] as String? ?? 'Unknown';
    final email = parent['email'] as String?;
    final pic = parent['picture'] as String?;
    final parentId = parent['id'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Parent header
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: pic != null ? NetworkImage(pic) : null,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: pic == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(color: theme.colorScheme.primary),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (email != null)
                      Text(
                        email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'PARENT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.purple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          // Wards list
          if (wards.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Column(
                children: wards.map((wm) {
                  final w = wm['ward'] as Map<String, dynamic>;
                  final wName = w['name'] as String? ?? 'Unknown';
                  final wPic = w['picture'] as String?;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.subdirectory_arrow_right_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: wPic != null
                              ? NetworkImage(wPic)
                              : null,
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          child: wPic == null
                              ? Text(
                                  wName.isNotEmpty
                                      ? wName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.secondary,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          wName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'WARD',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              color: Colors.teal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Add ward button
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: InkWell(
              onTap: () => _showAddWardDialog(parentId, name),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Add Ward',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
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

  Color _roleColor(String role) {
    switch (role) {
      case 'ADMIN':
        return Colors.deepOrange;
      case 'TEACHER':
        return Colors.blue;
      case 'STUDENT':
        return Colors.teal;
      case 'PARENT':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showAddWardDialog(
    String parentUserId,
    String parentName,
  ) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Ward under $parentName'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Ward Name',
            hintText: 'e.g. Aarav',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    try {
      await _coachingService.addWardToCoaching(
        coachingId: _coaching.id,
        parentUserId: parentUserId,
        wardName: name,
      );
      await _loadMembers(); // refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name added as ward'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ──────────────────── Classes ────────────────────
  Widget _buildClasses() {
    return _emptyPage(
      icon: Icons.class_rounded,
      title: 'Classes',
      subtitle: 'Batch & schedule management coming soon',
    );
  }

  // ──────────────────── Settings ────────────────────
  Widget _buildSettings() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Avatar section
        Center(
          child: GestureDetector(
            onTap: _pickCoachingLogo,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundImage: _coaching.logo != null
                      ? NetworkImage(_coaching.logo!)
                      : null,
                  backgroundColor: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.4),
                  child: _coaching.logo == null
                      ? Icon(
                          Icons.school_rounded,
                          size: 40,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 16,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),
        Center(
          child: Text(
            '@${_coaching.slug}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Name field
        _SettingsField(
          label: 'Coaching Name',
          value: _coaching.name,
          icon: Icons.badge_rounded,
          onSave: (v) => _updateField(name: v),
        ),

        const SizedBox(height: 16),

        // Description field
        _SettingsField(
          label: 'Description',
          value: _coaching.description ?? '',
          icon: Icons.description_rounded,
          maxLines: 3,
          onSave: (v) => _updateField(description: v),
        ),

        const SizedBox(height: 16),

        // Slug display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                Icons.link_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discovery Link',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${_coaching.slug}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Status
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                Icons.circle,
                color: _coaching.status == 'active'
                    ? Colors.green
                    : Colors.orange,
                size: 12,
              ),
              const SizedBox(width: 12),
              Text(
                _coaching.status == 'active' ? 'Active' : _coaching.status,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Danger zone
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Danger Zone',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('Delete Coaching'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ──────────────────── Shared empty page ────────────────────
  Widget _emptyPage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────── Invite bottom sheet ────────────────────
  void _showInviteSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteBottomSheet(
        coachingId: widget.coaching.id,
        coachingName: widget.coaching.name,
      ),
    );
  }

  // ──────────────────── Settings helpers ────────────────────
  Future<void> _pickCoachingLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
    );
    if (picked == null) return;

    try {
      final token = await const FlutterSecureStorage().read(key: 'jwt_token');
      if (token == null) return;

      final uri = Uri.parse('${_coachingService.baseUrl}/upload/logo');
      final req = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('file', picked.path));

      final resp = await req.send();
      if (resp.statusCode == 200) {
        final body = jsonDecode(await resp.stream.bytesToString());
        final url = body['url'] as String;
        final updated = await _coachingService.updateCoaching(
          id: _coaching.id,
          logo: url,
        );
        if (updated != null && mounted) {
          setState(() => _coaching = updated);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateField({String? name, String? description}) async {
    try {
      final updated = await _coachingService.updateCoaching(
        id: _coaching.id,
        name: name,
        description: description,
      );
      if (updated != null && mounted) {
        setState(() => _coaching = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Coaching?'),
        content: const Text(
          'This action is permanent. All members, classes, and data will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final ok = await _coachingService.deleteCoaching(_coaching.id);
      if (ok && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  Invite bottom sheet widget
// ════════════════════════════════════════════════════════════════
class _InviteBottomSheet extends StatefulWidget {
  final String coachingId;
  final String coachingName;

  const _InviteBottomSheet({
    required this.coachingId,
    required this.coachingName,
  });

  @override
  State<_InviteBottomSheet> createState() => _InviteBottomSheetState();
}

class _InviteBottomSheetState extends State<_InviteBottomSheet> {
  final _invitationService = InvitationService();
  final _contactCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  bool _searching = false;
  bool _sending = false;
  Map<String, dynamic>? _lookupResult;

  String _role = 'STUDENT';
  String? _userId;
  String? _wardId;
  String? _selectedName;

  @override
  void dispose() {
    _contactCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  // ── lookup ──
  Future<void> _search() async {
    final q = _contactCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _lookupResult = null;
      _userId = null;
      _wardId = null;
    });
    try {
      final res = await _invitationService.lookupContact(widget.coachingId, q);
      setState(() {
        _lookupResult = res;
        _searching = false;
      });
    } catch (e) {
      setState(() => _searching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  // ── send ──
  Future<void> _send() async {
    setState(() => _sending = true);
    final isResolved = _lookupResult?['found'] == true;
    try {
      await _invitationService.sendInvitation(
        coachingId: widget.coachingId,
        role: _role,
        userId: _userId,
        wardId: _wardId,
        invitePhone: !isResolved ? _contactCtrl.text.trim() : null,
        inviteEmail: !isResolved ? _contactCtrl.text.trim() : null,
        inviteName: _selectedName,
        message: _messageCtrl.text.trim().isNotEmpty
            ? _messageCtrl.text.trim()
            : null,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isResolved ? 'Invitation sent!' : 'Pending invitation created.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool get _canSend {
    if (_contactCtrl.text.trim().isEmpty) return false;
    if (_lookupResult == null) return false;
    if (_lookupResult!['found'] == true) {
      return _userId != null || _wardId != null;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
            child: Row(
              children: [
                Icon(
                  Icons.person_add_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Invite to ${widget.coachingName}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search
                  TextField(
                    controller: _contactCtrl,
                    decoration: InputDecoration(
                      hintText: 'Phone number or email',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.arrow_forward_rounded),
                              onPressed: _search,
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onSubmitted: (_) => _search(),
                  ),

                  const SizedBox(height: 16),

                  // Lookup result
                  if (_lookupResult != null) _buildResult(theme),

                  if (_lookupResult != null) ...[
                    const SizedBox(height: 20),
                    // Role
                    Text(
                      'Role',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'STUDENT',
                          label: Text('Student'),
                          icon: Icon(Icons.child_care_rounded),
                        ),
                        ButtonSegment(
                          value: 'TEACHER',
                          label: Text('Teacher'),
                          icon: Icon(Icons.school_rounded),
                        ),
                        ButtonSegment(
                          value: 'PARENT',
                          label: Text('Parent'),
                          icon: Icon(Icons.family_restroom_rounded),
                        ),
                      ],
                      selected: {_role},
                      onSelectionChanged: (s) =>
                          setState(() => _role = s.first),
                    ),

                    const SizedBox(height: 20),

                    // Message
                    TextField(
                      controller: _messageCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Add a message (optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Send
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _canSend && !_sending ? _send : null,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(_sending ? 'Sending…' : 'Send Invitation'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Lookup result card ──
  Widget _buildResult(ThemeData theme) {
    final found = _lookupResult!['found'] == true;

    if (!found) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.person_off_rounded,
              color: Colors.orange,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Not on the platform yet — a pending invite will be created.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.orange.shade800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final user = _lookupResult!['user'] as Map<String, dynamic>;
    final wards = (user['wards'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _profileTile(
          theme: theme,
          name: user['name'] ?? 'Unknown',
          sub: user['email'] ?? '',
          picture: user['picture'] as String?,
          selected: _userId == user['id'] && _wardId == null,
          onTap: () => setState(() {
            _userId = user['id'] as String;
            _wardId = null;
            _selectedName = user['name'] as String?;
          }),
        ),
        ...wards.map((w) {
          final ward = w as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _profileTile(
              theme: theme,
              name: ward['name'] ?? 'Ward',
              sub: 'Student profile',
              picture: ward['picture'] as String?,
              selected: _wardId == ward['id'],
              onTap: () => setState(() {
                _wardId = ward['id'] as String;
                _userId = null;
                _selectedName = ward['name'] as String?;
                _role = 'STUDENT';
              }),
            ),
          );
        }),
      ],
    );
  }

  Widget _profileTile({
    required ThemeData theme,
    required String name,
    required String sub,
    String? picture,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: picture != null ? NetworkImage(picture) : null,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: picture == null
                  ? Icon(
                      Icons.person_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    sub,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────── Reusable settings field ────────────────────
class _SettingsField extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final int maxLines;
  final ValueChanged<String> onSave;

  const _SettingsField({
    required this.label,
    required this.value,
    required this.icon,
    this.maxLines = 1,
    required this.onSave,
  });

  @override
  State<_SettingsField> createState() => _SettingsFieldState();
}

class _SettingsFieldState extends State<_SettingsField> {
  late TextEditingController _ctrl;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _SettingsField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_editing) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Icon(
              widget.icon,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                _editing
                    ? TextField(
                        controller: _ctrl,
                        maxLines: widget.maxLines,
                        autofocus: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                        ),
                      )
                    : Text(
                        widget.value.isEmpty ? 'Not set' : widget.value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: widget.value.isEmpty
                              ? theme.colorScheme.onSurfaceVariant
                              : null,
                        ),
                      ),
              ],
            ),
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Icon(
                _editing ? Icons.check_rounded : Icons.edit_rounded,
                size: 18,
              ),
              onPressed: () async {
                if (_editing) {
                  final newVal = _ctrl.text.trim();
                  if (newVal != widget.value && newVal.isNotEmpty) {
                    setState(() => _saving = true);
                    widget.onSave(newVal);
                    // Parent rebuilds with updated value
                    await Future.delayed(const Duration(milliseconds: 400));
                    if (mounted) {
                      setState(() {
                        _saving = false;
                        _editing = false;
                      });
                    }
                  } else {
                    setState(() => _editing = false);
                  }
                } else {
                  setState(() => _editing = true);
                }
              },
            ),
        ],
      ),
    );
  }
}

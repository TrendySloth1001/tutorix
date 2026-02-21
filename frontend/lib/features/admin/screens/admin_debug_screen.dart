import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/admin_logs_service.dart';
import '../../../core/services/error_logger_service.dart';
import '../../../shared/widgets/app_alert.dart';

/// Admin debug console with server logs, local device logs, and statistics.
/// Designed to match the Tutorix cream/olive theme.
class AdminDebugScreen extends StatefulWidget {
  const AdminDebugScreen({super.key});

  @override
  State<AdminDebugScreen> createState() => _AdminDebugScreenState();
}

class _AdminDebugScreenState extends State<AdminDebugScreen>
    with SingleTickerProviderStateMixin {
  final AdminLogsService _service = AdminLogsService.instance;
  final ErrorLoggerService _logger = ErrorLoggerService.instance;

  late TabController _tabController;
  bool _loading = true;
  bool _statsLoading = true;

  List<LogEntry> _logs = [];
  int _totalLogs = 0;
  LogStats? _stats;

  String? _selectedType;
  String? _selectedLevel;
  final int _limit = 50;
  int _offset = 0;

  // Local logs filter
  LogLevel? _localLevelFilter;
  LogCategory? _localCategoryFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLogs();
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final result = await _service.getLogs(
        type: _selectedType,
        level: _selectedLevel,
        limit: _limit,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        _logs = result['logs'] as List<LogEntry>;
        _totalLogs = result['total'] as int;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppAlert.error(context, 'Failed to load logs: $e');
    }
  }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    try {
      final stats = await _service.getStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _statsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statsLoading = false);
    }
  }

  void _onFilterChanged() {
    _offset = 0;
    _loadLogs();
  }

  List<LocalLogEntry> get _filteredLocalLogs {
    var logs = _logger.localLogs;
    if (_localLevelFilter != null) {
      logs = logs.where((l) => l.level == _localLevelFilter).toList();
    }
    if (_localCategoryFilter != null) {
      logs = logs.where((l) => l.category == _localCategoryFilter).toList();
    }
    return logs;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.terminal_rounded, size: 22),
            SizedBox(width: 10),
            Text(
              'Debug Console',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: theme.colorScheme.surface,
          labelColor: theme.colorScheme.surface,
          unselectedLabelColor: theme.colorScheme.outlineVariant,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_outlined, size: 18),
                  const SizedBox(width: 6),
                  const Text('Server', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  _buildBadge(_totalLogs.toString()),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_android_outlined, size: 18),
                  const SizedBox(width: 6),
                  const Text('Device', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  _buildBadge(_logger.localLogCount.toString()),
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insights_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Stats', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildServerLogsTab(),
          _buildLocalLogsTab(),
          _buildStatsTab(),
        ],
      ),
    );
  }

  Widget _buildBadge(String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ── Server Logs Tab ────────────────────────────────────────────────────

  Widget _buildServerLogsTab() {
    return Column(
      children: [
        _buildServerFilters(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _logs.isEmpty
              ? _buildEmptyState(
                  Icons.cloud_off_outlined,
                  'No server logs found',
                )
              : RefreshIndicator(
                  color: Theme.of(context).colorScheme.primary,
                  onRefresh: _loadLogs,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _logs.length + (_hasMorePages ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index >= _logs.length) {
                        return _buildLoadMoreButton();
                      }
                      return _ServerLogTile(log: _logs[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  bool get _hasMorePages => _offset + _limit < _totalLogs;

  Widget _buildLoadMoreButton() {
    return Center(
      child: TextButton.icon(
        onPressed: () {
          _offset += _limit;
          _loadLogs();
        },
        icon: Icon(
          Icons.expand_more_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        label: Text(
          'Load more (${_totalLogs - _offset - _limit} remaining)',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildServerFilters() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.outlineVariant.withValues(alpha: 0.25),
        border: Border(
          bottom: BorderSide(
            color: cs.onSurfaceVariant.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterChip(
              'Type',
              _selectedType,
              [null, 'API_REQUEST', 'API_ERROR', 'FRONTEND_ERROR', 'SYSTEM'],
              ['All', 'API', 'API Error', 'Frontend', 'System'],
              (val) {
                setState(() => _selectedType = val);
                _onFilterChanged();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildFilterChip(
              'Level',
              _selectedLevel,
              [null, 'INFO', 'WARN', 'ERROR', 'FATAL'],
              ['All', 'Info', 'Warn', 'Error', 'Fatal'],
              (val) {
                setState(() => _selectedLevel = val);
                _onFilterChanged();
              },
            ),
          ),
          const SizedBox(width: 10),
          _buildIconAction(Icons.refresh_rounded, _loadLogs),
        ],
      ),
    );
  }

  // ── Local Logs Tab ─────────────────────────────────────────────────────

  Widget _buildLocalLogsTab() {
    final logs = _filteredLocalLogs;
    return Column(
      children: [
        _buildLocalFilters(),
        Expanded(
          child: logs.isEmpty
              ? _buildEmptyState(
                  Icons.phone_android_outlined,
                  'No device logs yet',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    return _LocalLogTile(entry: logs[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLocalFilters() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.outlineVariant.withValues(alpha: 0.25),
        border: Border(
          bottom: BorderSide(
            color: cs.onSurfaceVariant.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterChip(
              'Level',
              _localLevelFilter?.value,
              [null, ...LogLevel.values],
              ['All', ...LogLevel.values.map((l) => l.value)],
              (val) => setState(
                () => _localLevelFilter = val == null
                    ? null
                    : LogLevel.values.firstWhere((l) => l == val),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildFilterChip(
              'Category',
              _localCategoryFilter?.value,
              [null, ...LogCategory.values],
              ['All', ...LogCategory.values.map((c) => c.value)],
              (val) => setState(
                () => _localCategoryFilter = val == null
                    ? null
                    : LogCategory.values.firstWhere((c) => c == val),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildIconAction(Icons.delete_outline_rounded, () {
            _logger.clearLocalLogs();
            setState(() {});
          }),
          const SizedBox(width: 6),
          _buildIconAction(Icons.refresh_rounded, () => setState(() {})),
        ],
      ),
    );
  }

  // ── Stats Tab ──────────────────────────────────────────────────────────

  Widget _buildStatsTab() {
    final cs = Theme.of(context).colorScheme;
    if (_statsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_stats == null) {
      return _buildEmptyState(
        Icons.insights_outlined,
        'Failed to load statistics',
      );
    }

    return RefreshIndicator(
      color: cs.primary,
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatHeader('Overview'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Total Logs',
                  value: _stats!.totalLogs,
                  icon: Icons.list_alt_rounded,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'Errors',
                  value: _stats!.errorCount,
                  icon: Icons.error_outline_rounded,
                  color: cs.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Warnings',
                  value: _stats!.warnCount,
                  icon: Icons.warning_amber_rounded,
                  color: cs.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'Frontend',
                  value: _stats!.frontendErrorCount,
                  icon: Icons.phone_android_rounded,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildStatHeader('API Health'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Requests',
                  value: _stats!.apiRequestCount,
                  icon: Icons.http_rounded,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'API Errors',
                  value: _stats!.apiErrorCount,
                  icon: Icons.cloud_off_rounded,
                  color: cs.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_stats!.apiRequestCount > 0) _buildApiHealthBar(),
          const SizedBox(height: 24),
          _buildStatHeader('Device Logs'),
          const SizedBox(height: 12),
          _buildDeviceLogsSummary(),
          const SizedBox(height: 24),
          _buildCleanupButton(),
        ],
      ),
    );
  }

  Widget _buildApiHealthBar() {
    final cs = Theme.of(context).colorScheme;
    final total = _stats!.apiRequestCount;
    final errors = _stats!.apiErrorCount;
    final successRate = total > 0 ? ((total - errors) / total * 100) : 100.0;
    final isHealthy = successRate >= 95;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.outlineVariant.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurfaceVariant.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isHealthy
                    ? Icons.check_circle_outline_rounded
                    : Icons.warning_amber_rounded,
                size: 18,
                color: isHealthy ? cs.primary : cs.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Success Rate: ${successRate.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: successRate / 100,
              backgroundColor: cs.error.withValues(alpha: 0.15),
              color: isHealthy ? cs.primary : cs.secondary,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceLogsSummary() {
    final cs = Theme.of(context).colorScheme;
    final local = _logger.localLogs;
    final errorCount = local
        .where((l) => l.level == LogLevel.error || l.level == LogLevel.fatal)
        .length;
    final warnCount = local.where((l) => l.level == LogLevel.warn).length;
    final infoCount = local.where((l) => l.level == LogLevel.info).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.outlineVariant.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurfaceVariant.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          _buildDeviceLogRow('Buffered', local.length, cs.onSurface),
          const SizedBox(height: 8),
          _buildDeviceLogRow('Errors', errorCount, cs.error),
          const SizedBox(height: 8),
          _buildDeviceLogRow('Warnings', warnCount, cs.secondary),
          const SizedBox(height: 8),
          _buildDeviceLogRow('Info', infoCount, cs.secondary),
        ],
      ),
    );
  }

  Widget _buildDeviceLogRow(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCleanupButton() {
    return OutlinedButton.icon(
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cleanup Old Logs'),
            content: const Text(
              'This will delete all server logs older than 30 days.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await _service.cleanupOldLogs();
          _loadLogs();
          _loadStats();
          if (mounted) AppAlert.success(context, 'Old logs cleaned up');
        }
      },
      icon: const Icon(Icons.delete_sweep_outlined),
      label: const Text('Cleanup Logs Older Than 30 Days'),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────

  Widget _buildStatHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 48,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip<T>(
    String label,
    String? currentLabel,
    List<T> values,
    List<String> labels,
    ValueChanged<T?> onChanged,
  ) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () async {
        final result = await showModalBottomSheet<T>(
          context: context,
          backgroundColor: cs.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(
                  values.length,
                  (i) => ListTile(
                    title: Text(labels[i]),
                    trailing:
                        (currentLabel == null && values[i] == null) ||
                            currentLabel == labels[i] ||
                            (values[i] != null &&
                                currentLabel ==
                                    (values[i] as dynamic)?.toString())
                        ? Icon(Icons.check_rounded, color: cs.primary)
                        : null,
                    onTap: () => Navigator.pop(context, values[i]),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
        if (result != null || true) {
          // Allow selecting null (All) — the bottom sheet always returns
          // the tapped value via Navigator.pop
        }
        // We handle the callback in the onTap of each ListTile above,
        // but since the sheet was dismissed we call it here too:
        // Actually the result is from the pop, so let's just use it:
        onChanged(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: currentLabel != null
              ? cs.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: currentLabel != null
                ? cs.primary.withValues(alpha: 0.3)
                : cs.onSurfaceVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                currentLabel ?? label,
                style: TextStyle(
                  fontSize: 13,
                  color: currentLabel != null
                      ? cs.onSurface
                      : cs.onSurfaceVariant,
                  fontWeight: currentLabel != null
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconAction(IconData icon, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: cs.onSurfaceVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(icon, size: 18, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Server log tile
// ══════════════════════════════════════════════════════════════════════════════

class _ServerLogTile extends StatelessWidget {
  final LogEntry log;
  const _ServerLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.onSurfaceVariant.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _LevelBadge(level: log.level),
                  const SizedBox(width: 6),
                  _TypeBadge(type: log.type),
                  if (log.statusCode != null) ...[
                    const SizedBox(width: 6),
                    _StatusCodeBadge(statusCode: log.statusCode!),
                  ],
                  const Spacer(),
                  Text(
                    DateFormat('HH:mm:ss').format(log.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'SF Mono',
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (log.method != null && log.path != null)
                Row(
                  children: [
                    _HttpMethodChip(method: log.method!),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        log.path!,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'SF Mono',
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (log.message != null &&
                  (log.method == null || log.path == null))
                Text(
                  log.message!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (log.error != null) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    log.error!,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.error,
                      fontFamily: 'SF Mono',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (log.duration != null || log.userName != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (log.duration != null) ...[
                      Icon(
                        Icons.timer_outlined,
                        size: 13,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${log.duration!.toStringAsFixed(0)}ms',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    if (log.duration != null && log.userName != null)
                      const SizedBox(width: 12),
                    if (log.userName != null) ...[
                      Icon(
                        Icons.person_outline,
                        size: 13,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        log.userName!,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _LevelBadge(level: log.level),
                  const SizedBox(width: 8),
                  _TypeBadge(type: log.type),
                  if (log.statusCode != null) ...[
                    const SizedBox(width: 8),
                    _StatusCodeBadge(statusCode: log.statusCode!),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              _detailField(
                'Time',
                DateFormat('yyyy-MM-dd HH:mm:ss').format(log.createdAt),
                cs,
              ),
              if (log.method != null) _detailField('Method', log.method!, cs),
              if (log.path != null) _detailField('Path', log.path!, cs),
              if (log.duration != null)
                _detailField(
                  'Duration',
                  '${log.duration!.toStringAsFixed(2)}ms',
                  cs,
                ),
              if (log.userName != null) _detailField('User', log.userName!, cs),
              if (log.userEmail != null)
                _detailField('Email', log.userEmail!, cs),
              if (log.ip != null) _detailField('IP', log.ip!, cs),
              if (log.userAgent != null)
                _detailField('User Agent', log.userAgent!, cs),
              if (log.message != null)
                _detailField('Message', log.message!, cs),
              if (log.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Error',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    log.error!,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'SF Mono',
                      color: cs.error,
                    ),
                  ),
                ),
              ],
              if (log.stackTrace != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Stack Trace',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    log.stackTrace!,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'SF Mono',
                      height: 1.5,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
              if (log.metadata != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Metadata',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    log.metadata!.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join('\n'),
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'SF Mono',
                      height: 1.5,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailField(String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(fontSize: 13, color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Local (device) log tile
// ══════════════════════════════════════════════════════════════════════════════

class _LocalLogTile extends StatelessWidget {
  final LocalLogEntry entry;
  const _LocalLogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasDetails =
        entry.error != null ||
        entry.stackTrace != null ||
        entry.metadata != null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: hasDetails ? () => _showDetails(context) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cs.onSurfaceVariant.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: _levelColor(entry.level, cs),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _categoryColor(
                              entry.category,
                              cs,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            entry.category.value,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _categoryColor(entry.category, cs),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('HH:mm:ss.SSS').format(entry.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'SF Mono',
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.message,
                      style: TextStyle(fontSize: 12, color: cs.onSurface),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.error != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.error!,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'SF Mono',
                          color: cs.error,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (hasDetails) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _LevelBadge(level: entry.level.value),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _categoryColor(
                        entry.category,
                        cs,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry.category.value,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _categoryColor(entry.category, cs),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                entry.message,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              if (entry.error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    entry.error!,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'SF Mono',
                      color: cs.error,
                    ),
                  ),
                ),
              ],
              if (entry.stackTrace != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      entry.stackTrace!,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'SF Mono',
                        height: 1.5,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
              if (entry.metadata != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    entry.metadata!.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join('\n'),
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'SF Mono',
                      height: 1.5,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Color _levelColor(LogLevel level, ColorScheme cs) {
    switch (level) {
      case LogLevel.debug:
        return cs.onSurfaceVariant;
      case LogLevel.info:
        return cs.secondary;
      case LogLevel.warn:
        return cs.secondary;
      case LogLevel.error:
        return cs.error;
      case LogLevel.fatal:
        return cs.error;
    }
  }

  static Color _categoryColor(LogCategory cat, ColorScheme cs) {
    switch (cat) {
      case LogCategory.api:
        return cs.secondary;
      case LogCategory.auth:
        return cs.primary;
      case LogCategory.navigation:
        return cs.onSurfaceVariant;
      case LogCategory.ui:
        return cs.secondary;
      case LogCategory.lifecycle:
        return cs.onSurfaceVariant;
      case LogCategory.storage:
        return cs.onSurfaceVariant;
      case LogCategory.network:
        return cs.secondary;
      case LogCategory.system:
        return cs.onSurface;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared badge widgets
// ══════════════════════════════════════════════════════════════════════════════

class _LevelBadge extends StatelessWidget {
  final String level;
  const _LevelBadge({required this.level});

  Color _getColor(ColorScheme cs) {
    switch (level) {
      case 'FATAL':
        return cs.error;
      case 'ERROR':
        return cs.error;
      case 'WARN':
        return cs.secondary;
      case 'INFO':
        return cs.secondary;
      default:
        return cs.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        level,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  String get _label {
    switch (type) {
      case 'API_REQUEST':
        return 'API';
      case 'API_ERROR':
        return 'API ERR';
      case 'FRONTEND_ERROR':
        return 'CLIENT';
      case 'SYSTEM':
        return 'SYS';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: cs.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _StatusCodeBadge extends StatelessWidget {
  final int statusCode;
  const _StatusCodeBadge({required this.statusCode});

  Color _getColor(ColorScheme cs) {
    if (statusCode >= 500) return cs.error;
    if (statusCode >= 400) return cs.secondary;
    if (statusCode >= 300) return cs.secondary;
    return cs.primary;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        statusCode.toString(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFamily: 'SF Mono',
          color: color,
        ),
      ),
    );
  }
}

class _HttpMethodChip extends StatelessWidget {
  final String method;
  const _HttpMethodChip({required this.method});

  Color _getColor(ColorScheme cs) {
    switch (method.toUpperCase()) {
      case 'GET':
        return cs.primary;
      case 'POST':
        return cs.secondary;
      case 'PATCH':
      case 'PUT':
        return cs.secondary;
      case 'DELETE':
        return cs.error;
      default:
        return cs.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        method,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFamily: 'SF Mono',
          color: color,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurfaceVariant.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../../batch/models/batch_model.dart';
import '../../batch/services/batch_service.dart';
import '../../coaching/models/coaching_model.dart';
import 'assessment_tab_screen.dart';

/// Coaching-level assessment screen shown in the bottom nav for non-admin users.
/// Lists the user's batches and taps through to the batch-level assessment tab.
class CoachingAssessmentScreen extends StatefulWidget {
  final CoachingModel coaching;
  final UserModel user;

  const CoachingAssessmentScreen({
    super.key,
    required this.coaching,
    required this.user,
  });

  @override
  State<CoachingAssessmentScreen> createState() =>
      _CoachingAssessmentScreenState();
}

class _CoachingAssessmentScreenState extends State<CoachingAssessmentScreen> {
  final BatchService _batchService = BatchService();
  List<BatchModel> _batches = [];
  bool _loading = true;
  StreamSubscription? _sub;

  bool get _isTeacher => widget.coaching.myRole == 'TEACHER';

  @override
  void initState() {
    super.initState();
    _sub = _batchService
        .watchMyBatches(widget.coaching.id)
        .listen(
          (list) {
            if (mounted) {
              setState(() {
                _batches = list;
                _loading = false;
              });
            }
          },
          onError: (_) {
            if (mounted) setState(() => _loading = false);
          },
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _openBatchAssessments(BatchModel batch) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(batch.name)),
          body: AssessmentTabScreen(
            coachingId: widget.coaching.id,
            batchId: batch.id,
            isTeacher: _isTeacher,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessments'),
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const _BatchListShimmer()
          : _batches.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.quiz_outlined,
                    size: 56,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No batches yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Join a batch to see assessments',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _batches.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final batch = _batches[i];
                return _BatchAssessmentCard(
                  batch: batch,
                  onTap: () => _openBatchAssessments(batch),
                );
              },
            ),
    );
  }
}

class _BatchAssessmentCard extends StatelessWidget {
  final BatchModel batch;
  final VoidCallback onTap;

  const _BatchAssessmentCard({required this.batch, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.quiz_rounded,
                  size: 22,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (batch.subject != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        batch.subject!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatchListShimmer extends StatelessWidget {
  const _BatchListShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => ShimmerWrap(
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

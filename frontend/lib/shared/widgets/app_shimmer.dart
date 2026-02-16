import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

// ════════════════════════════════════════════════════════════════════════
//  SHARED SHIMMER PRIMITIVES
// ════════════════════════════════════════════════════════════════════════

/// Base shimmer wrapper — all shimmers use this for consistent styling.
class ShimmerWrap extends StatelessWidget {
  final Widget child;
  const ShimmerWrap({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    // Blend towards grey so shimmer is visible on any surface color
    final baseColor = Color.lerp(surface, Colors.grey, 0.25)!;
    final highlightColor = Color.lerp(surface, Colors.white, 0.15)!;
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: child,
    );
  }
}

/// A rounded rectangle shimmer placeholder.
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A circle shimmer placeholder (for avatars).
class ShimmerCircle extends StatelessWidget {
  final double size;
  const ShimmerCircle({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  SCREEN-SPECIFIC SHIMMER LAYOUTS
// ════════════════════════════════════════════════════════════════════════

/// Home screen: mimics coaching cover cards.
class HomeShimmer extends StatelessWidget {
  const HomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Section header
            const ShimmerBox(width: 140, height: 16),
            const SizedBox(height: 16),
            // Coaching cards
            for (int i = 0; i < 3; i++) ...[
              const _CoachingCardShimmer(),
              if (i < 2) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _CoachingCardShimmer extends StatelessWidget {
  const _CoachingCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image
          ShimmerBox(height: 120, radius: 12),
          SizedBox(height: 12),
          // Title + subtitle
          ShimmerBox(width: 200, height: 18),
          SizedBox(height: 8),
          ShimmerBox(width: 140, height: 14),
          SizedBox(height: 12),
          // Stat row
          Row(
            children: [
              ShimmerBox(width: 60, height: 24, radius: 8),
              SizedBox(width: 8),
              ShimmerBox(width: 60, height: 24, radius: 8),
              SizedBox(width: 8),
              ShimmerBox(width: 60, height: 24, radius: 8),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dashboard: mimics header + stat chips + sections.
class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            // Stat chips row
            const Row(
              children: [
                Expanded(child: ShimmerBox(height: 52, radius: 12)),
                SizedBox(width: 8),
                Expanded(child: ShimmerBox(height: 52, radius: 12)),
                SizedBox(width: 8),
                Expanded(child: ShimmerBox(height: 52, radius: 12)),
              ],
            ),
            const SizedBox(height: 24),
            // Quick actions
            const ShimmerBox(width: 130, height: 16),
            const SizedBox(height: 12),
            const Row(
              children: [
                Expanded(child: ShimmerBox(height: 72, radius: 12)),
                SizedBox(width: 8),
                Expanded(child: ShimmerBox(height: 72, radius: 12)),
              ],
            ),
            const SizedBox(height: 24),
            // Pending invitations
            const ShimmerBox(width: 160, height: 16),
            const SizedBox(height: 12),
            const ShimmerBox(height: 80, radius: 12),
            const SizedBox(height: 24),
            // Recent notes
            const ShimmerBox(width: 130, height: 16),
            const SizedBox(height: 12),
            for (int i = 0; i < 3; i++) ...[
              const _NoteCardShimmer(),
              if (i < 2) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoteCardShimmer extends StatelessWidget {
  const _NoteCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          ShimmerBox(width: 40, height: 40, radius: 8),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 160, height: 14),
                SizedBox(height: 6),
                ShimmerBox(width: 100, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Members screen: mimics list of member tiles.
class MembersShimmer extends StatelessWidget {
  const MembersShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (int i = 0; i < 8; i++) ...[
              const _MemberTileShimmer(),
              if (i < 7) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemberTileShimmer extends StatelessWidget {
  const _MemberTileShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          ShimmerCircle(size: 44),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 140, height: 14),
                SizedBox(height: 6),
                ShimmerBox(width: 90, height: 12),
              ],
            ),
          ),
          ShimmerBox(width: 56, height: 24, radius: 8),
        ],
      ),
    );
  }
}

/// Batches list: mimics batch cards.
class BatchListShimmer extends StatelessWidget {
  const BatchListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (int i = 0; i < 4; i++) ...[
              const _BatchCardShimmer(),
              if (i < 3) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _BatchCardShimmer extends StatelessWidget {
  const _BatchCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerBox(width: 40, height: 40, radius: 10),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 150, height: 16),
                    SizedBox(height: 6),
                    ShimmerBox(width: 90, height: 12),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              ShimmerBox(width: 70, height: 22, radius: 8),
              SizedBox(width: 8),
              ShimmerBox(width: 70, height: 22, radius: 8),
              SizedBox(width: 8),
              ShimmerBox(width: 70, height: 22, radius: 8),
            ],
          ),
        ],
      ),
    );
  }
}

/// Batch detail: mimics tabs + content.
class BatchDetailShimmer extends StatelessWidget {
  const BatchDetailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Batch header
            const ShimmerBox(width: 200, height: 20),
            const SizedBox(height: 8),
            const ShimmerBox(width: 120, height: 14),
            const SizedBox(height: 20),
            // Tab row
            const Row(
              children: [
                ShimmerBox(width: 80, height: 32, radius: 8),
                SizedBox(width: 8),
                ShimmerBox(width: 80, height: 32, radius: 8),
                SizedBox(width: 8),
                ShimmerBox(width: 80, height: 32, radius: 8),
              ],
            ),
            const SizedBox(height: 20),
            // Content cards
            for (int i = 0; i < 4; i++) ...[
              const _NoteCardShimmer(),
              if (i < 3) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// Profile screen shimmer.
class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar
            const ShimmerCircle(size: 80),
            const SizedBox(height: 16),
            const ShimmerBox(width: 160, height: 20),
            const SizedBox(height: 8),
            const ShimmerBox(width: 200, height: 14),
            const SizedBox(height: 32),
            // Setting tiles
            for (int i = 0; i < 6; i++) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    ShimmerCircle(size: 36),
                    SizedBox(width: 12),
                    ShimmerBox(width: 140, height: 14),
                  ],
                ),
              ),
              if (i < 5) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// Notifications list shimmer.
class NotificationsShimmer extends StatelessWidget {
  const NotificationsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (int i = 0; i < 6; i++) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerCircle(size: 36),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 180, height: 14),
                          SizedBox(height: 6),
                          ShimmerBox(height: 12),
                          SizedBox(height: 4),
                          ShimmerBox(width: 100, height: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < 5) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// Invitations list shimmer.
class InvitationsShimmer extends StatelessWidget {
  const InvitationsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (int i = 0; i < 4; i++) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ShimmerCircle(size: 44),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShimmerBox(width: 160, height: 14),
                              SizedBox(height: 6),
                              ShimmerBox(width: 100, height: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: ShimmerBox(height: 36, radius: 10)),
                        SizedBox(width: 8),
                        Expanded(child: ShimmerBox(height: 36, radius: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              if (i < 3) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sessions list shimmer.
class SessionsShimmer extends StatelessWidget {
  const SessionsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (int i = 0; i < 5; i++) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    ShimmerBox(width: 36, height: 36, radius: 8),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 180, height: 14),
                          SizedBox(height: 6),
                          ShimmerBox(width: 120, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < 4) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// Coaching profile shimmer.
class CoachingProfileShimmer extends StatelessWidget {
  const CoachingProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Column(
        children: [
          // Cover image
          const ShimmerBox(height: 180, radius: 0),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBox(width: 200, height: 22),
                const SizedBox(height: 8),
                const ShimmerBox(width: 280, height: 14),
                const SizedBox(height: 24),
                // Info rows
                for (int i = 0; i < 5; i++) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: const Row(
                      children: [
                        ShimmerCircle(size: 32),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShimmerBox(width: 100, height: 12),
                              SizedBox(height: 4),
                              ShimmerBox(width: 180, height: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < 4) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Add batch members shimmer.
class AddMembersShimmer extends StatelessWidget {
  const AddMembersShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const MembersShimmer();
  }
}

/// Generic list shimmer — use when no specific shimmer exists.
class GenericListShimmer extends StatelessWidget {
  final int count;
  const GenericListShimmer({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (int i = 0; i < count; i++) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    ShimmerCircle(size: 40),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 160, height: 14),
                          SizedBox(height: 6),
                          ShimmerBox(width: 100, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < count - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

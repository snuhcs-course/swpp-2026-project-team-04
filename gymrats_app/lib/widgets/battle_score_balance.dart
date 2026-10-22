import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Only valid, accepted scores determine the share. An empty match is neutral.
class BattleScoreBalance extends StatelessWidget {
  const BattleScoreBalance({
    super.key,
    required this.mine,
    required this.theirs,
  });

  final int mine, theirs;
  double get myShare => mine + theirs == 0 ? .5 : mine / (mine + theirs);

  @override
  Widget build(BuildContext context) {
    final percent = (myShare * 100).round();
    final difference = (mine - theirs).abs();
    final status = mine + theirs == 0
        ? '첫 점수 대기'
        : difference == 0
        ? '동률'
        : difference == 1
        ? '1회 차 · 박빙'
        : '${mine > theirs ? '나' : '상대'} $difference회 앞섬';
    return Semantics(
      label: '점수 비율, 나 $mine회, 상대 $theirs회, $status',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '나 $percent%',
                style: const TextStyle(color: AppColors.accent, fontSize: 12),
              ),
              Expanded(
                child: Text(
                  status,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                '상대 ${100 - percent}%',
                style: const TextStyle(color: AppColors.opponent, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 16,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.opponent),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: myShare),
                    duration: const Duration(milliseconds: 220),
                    builder: (_, share, _) => Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        key: const Key('myScoreShare'),
                        widthFactor: share,
                        heightFactor: 1,
                        child: const ColoredBox(color: AppColors.accent),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 2,
                      color: AppColors.background.withValues(alpha: .6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

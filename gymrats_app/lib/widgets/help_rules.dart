import '../models/battle_rules.dart';
import '../models/exercise_type.dart';
import '../models/tutorial_page.dart';
import '../viewmodels/tutorial_viewmodel.dart';

/// The words of one tutorial page: a one-line title and a line or two.
class HelpPage {
  const HelpPage({required this.title, required this.body});

  final String title;
  final String body;
}

/// Everything the tutorial says, in one place (team chat 2026-11-14: one
/// picture and one or two lines a page, the game rules only).
///
/// The numbers are the game's, from [battleRules] and [battleDuration];
/// change them there and the pages follow.
abstract final class HelpRules {
  static int get totalSeconds => battleDuration.inSeconds;
  static int get feverSeconds => battleRules.feverLength.inSeconds;
  static int get feverMultiplier => battleRules.feverMultiplier;
  static int get excellent => battleRules.excellentPoints;
  static int get good => battleRules.goodPoints;
  static int get average => battleRules.averagePoints;
  static int get koLead => battleRules.koLead;

  /// An excellent rep in fever, as the fever page shows it.
  static int get feverExcellent => excellent * feverMultiplier;

  /// The pages in the order the tutorial shows them.
  static List<TutorialPage> get order =>
      TutorialViewModel.pagesFor(battleRules);

  /// The words of every page, in [order].
  static List<HelpPage> get pages => [for (final page in order) of(page)];

  /// The exercise as the tabs and the page count name it.
  static String exerciseName(ExerciseType exercise) => switch (exercise) {
    ExerciseType.pushUp => '푸시업',
    ExerciseType.squat => '스쿼트',
  };

  /// The words of [page].
  static HelpPage of(TutorialPage page) {
    final squat = page.exercise == ExerciseType.squat;
    return switch (page.step) {
      TutorialStep.intro => HelpPage(
        title: squat ? '스쿼트로 1:1 대결해요' : '푸시업으로 1:1 대결해요',
        body: squat
            ? '$totalSeconds초 대결이에요. Average는 없어요.'
            : '다른 사람이나 RepBot과 $totalSeconds초 동안 겨뤄요.',
      ),
      TutorialStep.setup =>
        squat
            ? const HelpPage(
                title: '휴대폰을 보고 서서 준비해요',
                body: '몸 전체가 보이면 준비 완료예요.',
              )
            : const HelpPage(
                title: '초록 선 안에 몸을 맞춰요',
                body: '선 안에 들어오면 준비 완료예요.',
              ),
      TutorialStep.battle => HelpPage(
        title: '점수로 겨루는 대결이에요',
        body: squat ? '한 번 앉을 때마다 체력 바가 밀려요.' : '한 번 할 때마다 체력 바가 밀려요.',
      ),
      TutorialStep.excellent => HelpPage(
        title: squat ? '깊게 앉으면 Excellent' : '깊게 내려가면 Excellent',
        body: squat
            ? '엉덩이를 충분히 낮추면 $excellent점.'
            : '가슴을 바닥 가까이까지 내리면 $excellent점.',
      ),
      TutorialStep.good => HelpPage(
        title: '바른 자세면 Good',
        body: squat ? '기준 깊이까지 앉으면 $good점.' : '팔꿈치를 충분히 굽히면 $good점.',
      ),
      TutorialStep.average => HelpPage(
        title: '조금 얕으면 Average',
        body: '살짝 덜 내려가도 $average점은 받아요.',
      ),
      TutorialStep.fail => HelpPage(
        title: squat ? '얕게 앉으면 Fail' : '자세가 무너지면 Fail',
        body: squat ? '기준선보다 얕게 앉으면 0점이에요.' : '너무 얕거나 흐트러지면 0점이에요.',
      ),
      TutorialStep.fever => HelpPage(
        title: '마지막 $feverSeconds초는 피버 타임',
        body: '모든 점수가 $feverMultiplier배로 들어와요.',
      ),
      TutorialStep.ko => HelpPage(
        title: '$koLead점 앞서면 KO 승리',
        body: '체력 바를 끝까지 밀면 바로 끝나요.',
      ),
      TutorialStep.report => const HelpPage(
        title: '끝나면 리포트를 받아요',
        body: "'자세 피드백 보기'에서 내 자세를 확인해요.",
      ),
    };
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/auth_form.dart';

Future<void> _show(
  WidgetTester tester,
  Widget child, {
  bool still = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: still),
          child: Scaffold(
            body: Center(child: SizedBox(width: 320, child: child)),
          ),
        ),
      ),
    ),
  );
}

bool _announced(WidgetTester tester, Finder inside) => tester
    .widgetList<Semantics>(
      find.ancestor(of: inside, matching: find.byType(Semantics)),
    )
    .any((s) => s.properties.liveRegion ?? false);

void main() {
  group('keepWordsWhole', () {
    const j = '⁠';
    test('joins the letters of each word, never across a space', () {
      expect(keepWordsWhole('실패했어요.'), '실$j패$j했$j어$j요$j.');
      expect(
        keepWordsWhole('Google로 로그인하는 중…'),
        'G${j}o${j}o${j}g${j}l${j}e$j로 로$j그$j인$j하$j는 중$j…',
      );
      expect(keepWordsWhole('a  b\nc'), 'a  b\nc');
      expect(keepWordsWhole(''), '');
    });

    test('takes nothing away: without the joiners it is the same text', () {
      for (final text in ['Google 로그인에 실패했어요.', '대결 화면에 보이는 이름, 12자 이하']) {
        expect(keepWordsWhole(text).replaceAll('⁠', ''), text);
      }
    });

    test('keeps a letter made of several code points whole', () {
      // Decomposed 한 (ㅎ + ㅏ + ㄴ): one letter, no joiner inside it.
      const han = '한';
      expect(keepWordsWhole('$han글'), '$han$j글');
    });
  });

  testWidgets('AuthWords: finders and screen readers get the sentence as '
      'written; only the drawing has the joiners', (tester) async {
    final semantics = tester.ensureSemantics();
    await _show(tester, const AuthWords('Google 로그인에 실패했어요.'));
    expect(find.text('Google 로그인에 실패했어요.'), findsOneWidget);
    expect(find.bySemanticsLabel('Google 로그인에 실패했어요.'), findsOneWidget);
    final drawn = tester.widget<RichText>(
      find.descendant(
        of: find.byType(AuthWords),
        matching: find.byType(RichText),
      ),
    );
    expect(drawn.text.toPlainText(), keepWordsWhole('Google 로그인에 실패했어요.'));
    semantics.dispose();
  });

  test('with the joiners a narrow line breaks at a space, where the plain '
      'sentence breaks inside a word', () {
    const sentence = 'Google 로그인에 실패했어요.';

    /// The character before each line start after the first.
    List<String> breaksOf(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: const TextStyle(fontSize: 20)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 150);
      final starts = {
        for (var i = 0; i < text.length; i++)
          painter.getLineBoundary(TextPosition(offset: i)).start,
      }..remove(0);
      painter.dispose();
      return [for (final start in starts) text[start - 1]];
    }

    final kept = breaksOf(keepWordsWhole(sentence));
    expect(kept, isNotEmpty);
    expect(kept, everyElement(' '));
    expect(breaksOf(sentence), contains(isNot(' ')));
  });

  group('authLines', () {
    // Every letter and space 10 wide.
    double widthOf(String line) => line.length * 10.0;
    String plain(String drawn) => drawn.replaceAll('⁠', '');

    test('a line that fits: the words kept whole, no break added', () {
      final drawn = authLines('아이디로 로그인', maxWidth: 200, widthOf: widthOf);
      expect(drawn, keepWordsWhole('아이디로 로그인'));
    });

    test('two lines: the break at the space that balances them', () {
      final drawn = authLines(
        'Google로 로그인하는 중…',
        maxWidth: 140,
        widthOf: widthOf,
      );
      expect(plain(drawn), 'Google로\n로그인하는 중…');
      expect(
        drawn,
        '${keepWordsWhole('Google로')}\n${keepWordsWhole('로그인하는 중…')}',
      );
      expect(
        plain(authLines('Google 로그인에 실패했어요.', maxWidth: 120, widthOf: widthOf)),
        'Google 로그인에\n실패했어요.',
      );
    });

    test('three lines or more, one word, or no width: words kept whole and '
        'the text wraps by itself', () {
      for (final (text, width) in [
        ('가 나 다 라 마 바', 30.0),
        ('계정을만드는중', 30.0),
        ('Google로 로그인하는 중…', double.infinity),
      ]) {
        expect(
          authLines(text, maxWidth: width, widthOf: widthOf),
          keepWordsWhole(text),
        );
      }
    });
  });

  group('splitFirstSentence', () {
    test('the first sentence and the rest', () {
      expect(splitFirstSentence('Google 로그인에 실패했어요. 다시 시도해 주세요.'), (
        'Google 로그인에 실패했어요.',
        '다시 시도해 주세요.',
      ));
      expect(splitFirstSentence('지금은 Google 로그인을 쓸 수 없어요. 잠시 후 다시 시도해 주세요.'), (
        '지금은 Google 로그인을 쓸 수 없어요.',
        '잠시 후 다시 시도해 주세요.',
      ));
      expect(splitFirstSentence('정말요? 네!'), ('정말요?', '네!'));
    });

    test('one sentence has no rest', () {
      expect(splitFirstSentence(' 아이디를 입력해 주세요. '), ('아이디를 입력해 주세요.', null));
      expect(splitFirstSentence('인터넷 연결 없음'), ('인터넷 연결 없음', null));
    });
  });

  testWidgets('AuthErrorBox: an amber "!", the first sentence bold, the rest '
      'small and grey, announced', (tester) async {
    await _show(tester, const AuthErrorBox('하나. 둘 셋.'));
    final first = tester.widget<Text>(find.text('하나.'));
    final rest = tester.widget<Text>(find.text('둘 셋.'));
    expect(first.style!.fontWeight, FontWeight.w700);
    expect(first.style!.color, AppColors.ink);
    expect(rest.style!.color, AppColors.textSecondary);
    expect(rest.style!.fontSize, 13);
    expect(first.style!.fontSize, 14);
    expect(_announced(tester, find.text('하나.')), isTrue);
    final mark = tester.widget<Container>(
      find
          .ancestor(of: find.byType(AuthIcon), matching: find.byType(Container))
          .first,
    );
    expect((mark.decoration! as BoxDecoration).color, AppColors.warning);
  });

  testWidgets('AuthNotice and AuthFieldError are announced', (tester) async {
    await _show(
      tester,
      const Column(
        children: [AuthNotice('로그인을 취소했어요'), AuthFieldError('틀렸어요.')],
      ),
    );
    expect(_announced(tester, find.text('로그인을 취소했어요')), isTrue);
    expect(_announced(tester, find.text('틀렸어요.')), isTrue);
    expect(
      tester.widget<Text>(find.text('로그인을 취소했어요')).style!.color,
      AppColors.textSecondary,
    );
    expect(tester.widget<Text>(find.text('틀렸어요.')).style!.color, AppColors.ink);
  });

  testWidgets('AuthGoogleButton: the G and ink words; busy, a spinner and '
      'grey words that ignore taps', (tester) async {
    var taps = 0;
    await _show(
      tester,
      AuthGoogleButton(label: 'Google로 시작하기', onPressed: () => taps++),
    );
    expect(find.text('G'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Google로 시작하기')).style!.color,
      AppColors.ink,
    );
    expect(tester.getSize(find.byType(OutlinedButton)).height, 54);
    await tester.tap(find.byType(AuthGoogleButton));
    expect(taps, 1);

    await _show(
      tester,
      const AuthGoogleButton(label: '…하는 중', onPressed: null, busy: true),
    );
    expect(find.text('G'), findsNothing);
    expect(find.byType(AuthSpinner), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('…하는 중')).style!.color,
      AuthColors.busyText,
    );
  });

  testWidgets('AuthLimeButton: an arrow; busy, pale with a spinner and its '
      'busy words, and no taps', (tester) async {
    var taps = 0;
    await _show(tester, AuthLimeButton(label: '시작하기', onPressed: () => taps++));
    expect(find.byType(AuthIcon), findsOneWidget);
    expect(tester.getSize(find.byType(FilledButton)).height, 58);
    await tester.tap(find.text('시작하기'));
    expect(taps, 1);
    await _show(
      tester,
      AuthLimeButton(
        label: '시작하기',
        busy: true,
        busyLabel: '계정을 만드는 중…',
        onPressed: () => taps++,
      ),
    );
    expect(find.text('계정을 만드는 중…'), findsOneWidget);
    expect(find.byType(AuthSpinner), findsOneWidget);
    expect(find.byType(AuthIcon), findsNothing);
    await tester.tap(find.text('계정을 만드는 중…'));
    expect(taps, 1);
  });

  testWidgets('AuthSpinner turns, and stands still with animations off', (
    tester,
  ) async {
    await _show(tester, const AuthSpinner());
    final turns = tester.widget<RotationTransition>(
      find.descendant(
        of: find.byType(AuthSpinner),
        matching: find.byType(RotationTransition),
      ),
    );
    final before = turns.turns.value;
    await tester.pump(const Duration(milliseconds: 250));
    expect(turns.turns.value, closeTo(before + 0.25, 0.01));

    await _show(tester, const AuthSpinner(), still: true);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('AuthTextLink: underlined grey, lighter when off', (
    tester,
  ) async {
    await _show(tester, AuthTextLink(label: '아이디로 로그인', onPressed: () {}));
    final on = tester.widget<Text>(find.text('아이디로 로그인')).style!;
    expect(on.decoration, TextDecoration.underline);
    expect(on.color, AppColors.textSecondary);
    expect(tester.getSize(find.byType(TextButton)).height, 48);
    await _show(tester, const AuthTextLink(label: '아이디로 로그인', onPressed: null));
    expect(
      tester.widget<Text>(find.text('아이디로 로그인')).style!.color,
      AuthColors.busyLink,
    );
  });

  testWidgets('AuthRoundButton: a 40 or 44 circle with a 48 tap area', (
    tester,
  ) async {
    var taps = 0;
    await _show(
      tester,
      AuthRoundButton(
        glyph: AuthGlyph.close,
        tooltip: '닫기',
        size: AuthLayout.closeButton,
        icon: AuthLayout.closeIcon,
        onPressed: () => taps++,
      ),
    );
    expect(find.byTooltip('닫기'), findsOneWidget);
    expect(tester.getSize(find.byType(IconButton)).height, 48);
    await tester.tap(find.byTooltip('닫기'));
    expect(taps, 1);
  });

  testWidgets('AuthInputField: named for a screen reader, the design\'s '
      'text, a hidden password\'s spaced dots, and its trailing part', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final semantics = tester.ensureSemantics();
    await _show(
      tester,
      Column(
        children: [
          AuthInputField(
            controller: controller,
            label: '닉네임',
            trailing: const Text('0/12'),
          ),
          AuthInputField(
            controller: TextEditingController(),
            label: '비밀번호',
            obscure: true,
          ),
        ],
      ),
    );
    expect(find.bySemanticsLabel(RegExp('닉네임')), findsWidgets);
    expect(find.text('0/12'), findsOneWidget);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.first.style!.fontSize, 17);
    expect(fields.last.obscureText, isTrue);
    expect(fields.last.style!.letterSpacing, 3);
    expect(tester.getSize(find.byType(AuthInputField).first).height, 54);
    semantics.dispose();
  });

  testWidgets('AuthIcon draws every glyph', (tester) async {
    await _show(
      tester,
      Wrap(
        children: [
          for (final glyph in AuthGlyph.values) AuthIcon(glyph, size: 24),
        ],
      ),
    );
    expect(find.byType(AuthIcon), findsNWidgets(AuthGlyph.values.length));
    expect(tester.takeException(), isNull);
  });
}

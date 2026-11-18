import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/utils/korean_josa.dart';

void main() {
  group('hasFinalConsonant (setup_checker\'s rule)', () {
    test('a Hangul syllable with a final consonant', () {
      for (final word in const ['손', '발목', '스쿼트 20회 인정받기의 끝', '곰', '범']) {
        expect(hasFinalConsonant(word), isTrue, reason: word);
      }
    });

    test('a vowel ending, and anything that is not Hangul, has none', () {
      for (final word in const ['머리', '스쿼트', '찍', '', 'HIT', '20', '85%']) {
        expect(
          hasFinalConsonant(word),
          word == '찍' ? isTrue : isFalse,
          reason: word,
        );
      }
    });

    test('the first and last Hangul syllables', () {
      expect(hasFinalConsonant('가'), isFalse);
      expect(hasFinalConsonant('힣'), isTrue);
    });
  });

  group('the particles', () {
    test('each pair after a consonant and after a vowel', () {
      expect(
        [for (final josa in Josa.values) (josa.of('푸쉬업'), josa.of('스쿼트'))],
        const [
          ('이', '가'),
          ('은', '는'),
          ('을', '를'),
          ('과', '와'),
          ('이었', '였'),
          ('이야', '야'),
        ],
      );
    });

    test('after puts the word and its particle together', () {
      expect(Josa.eulReul.after('푸쉬업'), '푸쉬업을');
      expect(Josa.eulReul.after('스쿼트'), '스쿼트를');
      expect(Josa.gwaWa.after('물렁범'), '물렁범과');
      expect(Josa.gwaWa.after('곰탱이'), '곰탱이와');
      expect('‘폰 고정’${Josa.ieot.of('폰 고정')}어', '‘폰 고정’이었어');
      expect('‘더 앉기’${Josa.ieot.of('더 앉기')}어', '‘더 앉기’였어');
    });
  });
}

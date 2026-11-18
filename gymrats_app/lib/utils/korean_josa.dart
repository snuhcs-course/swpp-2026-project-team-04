/// Korean particles that change with the last syllable of the word they
/// follow: one form after a final consonant (받침), another after a vowel.
///
/// The rule is the one `setup_checker.dart` uses for 이 / 가: a Hangul
/// syllable whose final is not empty takes the first form; anything else
/// (a vowel ending, a digit, a letter or a sign) takes the second.
enum Josa {
  /// 손이 / 머리가.
  iGa('이', '가'),

  /// 스쿼트는 / 팔꿈치는; 깊이 부족은.
  eunNeun('은', '는'),

  /// 푸쉬업을 / 스쿼트를.
  eulReul('을', '를'),

  /// 물렁범과 / 곰탱이와.
  gwaWa('과', '와'),

  /// '폰 고정'이었어 / '더 앉기'였어.
  ieot('이었', '였'),

  /// '좌우 불균형'이야 / '자세 유지'야.
  iya('이야', '야');

  const Josa(this.afterConsonant, this.afterVowel);

  /// The form after a final consonant.
  final String afterConsonant;

  /// The form after a vowel (and after anything that is not Hangul).
  final String afterVowel;

  /// The particle for [word], e.g. `Josa.eulReul.of('스쿼트')` is '를'.
  String of(String word) =>
      hasFinalConsonant(word) ? afterConsonant : afterVowel;

  /// [word] with its particle, e.g. `Josa.eulReul.after('푸쉬업')` is
  /// '푸쉬업을'.
  String after(String word) => '$word${of(word)}';
}

/// Whether the last character of [word] is a Hangul syllable with a final
/// consonant. An empty word has none.
bool hasFinalConsonant(String word) {
  if (word.isEmpty) return false;
  const first = 0xAC00, last = 0xD7A3, finals = 28;
  final code = word.runes.last;
  return code >= first && code <= last && (code - first) % finals != 0;
}

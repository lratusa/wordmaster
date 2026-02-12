enum Language {
  en('en', 'English', '英语'),
  ja('ja', '日本語', '日语');

  final String code;
  final String nativeName;
  final String chineseName;

  const Language(this.code, this.nativeName, this.chineseName);

  static Language fromCode(String code) {
    return Language.values.firstWhere(
      (l) => l.code == code,
      orElse: () => Language.en,
    );
  }
}

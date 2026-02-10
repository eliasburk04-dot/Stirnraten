class MonetizationLimits {
  static const int freeMaxWordsPerList = 20;
  static const int premiumMaxWordsPerList = 100;
  static const int freeDailyAiGenerations = 3;

  static int maxWordsPerList({required bool isPremium}) {
    return isPremium ? premiumMaxWordsPerList : freeMaxWordsPerList;
  }
}


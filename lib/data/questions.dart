import 'dart:math';

// ============================================================================
// LÜGNER GAME - QUESTIONS DATABASE
// ============================================================================
// 
// HOW TO ADD NEW QUESTIONS:
// -------------------------
// Simply add a new Question object to the 'questions' list below.
// 
// FORMAT:
//   Question(
//     id: <unique number>,
//     question: "<Your question text>",
//     category: QuestionCategory.<category>,
//   ),
//
// RULES FOR GOOD QUESTIONS:
// - Questions should have NUMERICAL answers (amounts, hours, times, etc.)
// - Keep questions casual and fun - nothing too personal or offensive
// - Make sure the question could have a wide range of valid answers
// - Good categories: money, lifestyle, food, social, work, entertainment
//
// EXAMPLE:
//   Question(
//     id: 25,
//     question: "How many cups of coffee do you drink per week?",
//     category: QuestionCategory.lifestyle,
//   ),
//
// ============================================================================

/// Categories for organizing questions
enum QuestionCategory {
  money,      // Money and spending habits
  lifestyle,  // Daily routines and habits
  food,       // Food preferences and eating habits
  social,     // Social situations and relationships
  work,       // Work/school related
  entertainment, // Hobbies and entertainment
  dating,     // Dating and relationships
  travel,     // Travel experiences
  technology, // Tech and digital life
}

/// Model class for a question
class Question {
  final int id;
  final String question;
  final QuestionCategory category;

  const Question({
    required this.id,
    required this.question,
    required this.category,
  });

  /// Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'category': category.name,
    };
  }

  /// Create from Map (from Firebase)
  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'] as int,
      question: map['question'] as String,
      category: QuestionCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => QuestionCategory.lifestyle,
      ),
    );
  }
}

// ============================================================================
// QUESTIONS LIST - ADD YOUR QUESTIONS HERE!
// ============================================================================

final List<Question> questions = [
  // -------------------------------------------------------------------------
  // 💰 MONEY & FINANCE
  // -------------------------------------------------------------------------
  const Question(
    id: 1,
    question: "Wie viel Geld würdest du für ein erstes Date ausgeben? (in €)",
    category: QuestionCategory.money,
  ),
  const Question(
    id: 2,
    question: "Wie viel gibst du pro Woche für Lebensmittel aus? (in €)",
    category: QuestionCategory.money,
  ),
  const Question(
    id: 3,
    question: "Was ist das Maximum, das du für ein Konzertticket zahlen würdest? (in €)",
    category: QuestionCategory.money,
  ),
  const Question(
    id: 4,
    question: "Wie viel Geld sparst du pro Monat? (in €)",
    category: QuestionCategory.money,
  ),
  const Question(
    id: 5,
    question: "Was ist das Meiste, das du je für ein einzelnes Kleidungsstück ausgegeben hast? (in €)",
    category: QuestionCategory.money,
  ),

  // -------------------------------------------------------------------------
  // 🌟 LIFESTYLE
  // -------------------------------------------------------------------------
  const Question(
    id: 6,
    question: "Wie viele Stunden schläfst du durchschnittlich pro Nacht?",
    category: QuestionCategory.lifestyle,
  ),
  const Question(
    id: 7,
    question: "Wie oft pro Woche machst du Sport?",
    category: QuestionCategory.lifestyle,
  ),
  const Question(
    id: 8,
    question: "Wie viele Stunden Bildschirmzeit hast du pro Tag?",
    category: QuestionCategory.lifestyle,
  ),
  const Question(
    id: 10,
    question: "Wie viele Minuten brauchst du morgens, um dich fertig zu machen?",
    category: QuestionCategory.lifestyle,
  ),

  // -------------------------------------------------------------------------
  // 🍕 FOOD & DRINKS
  // -------------------------------------------------------------------------
  const Question(
    id: 13,
    question: "Wie viele Gläser Wasser trinkst du pro Tag?",
    category: QuestionCategory.food,
  ),
  const Question(
    id: 15,
    question: "Wie viele Stücke Pizza kannst du auf einmal essen?",
    category: QuestionCategory.food,
  ),

  // -------------------------------------------------------------------------
  // 👥 SOCIAL
  // -------------------------------------------------------------------------
  const Question(
    id: 16,
    question: "Wie viele enge Freunde hast du?",
    category: QuestionCategory.social,
  ),
  const Question(
    id: 17,
    question: "Auf wie vielen Partys warst du dieses Jahr?",
    category: QuestionCategory.social,
  ),
  const Question(
    id: 19,
    question: "Wie viele Leute würdest du zu deiner Geburtstagsparty einladen?",
    category: QuestionCategory.social,
  ),

  // -------------------------------------------------------------------------
  // 💼 WORK & SCHOOL
  // -------------------------------------------------------------------------
  const Question(
    id: 21,
    question: "Wie viele Stunden pro Tag verbringst du mit Arbeit/Studium?",
    category: QuestionCategory.work,
  ),
  const Question(
    id: 22,
    question: "Wie viele Krankheitstage hattest du dieses Jahr?",
    category: QuestionCategory.work,
  ),

  // -------------------------------------------------------------------------
  // 🎮 ENTERTAINMENT
  // -------------------------------------------------------------------------
  const Question(
    id: 25,
    question: "Wie viele Stunden pro Woche spielst du Videospiele?",
    category: QuestionCategory.entertainment,
  ),
  const Question(
    id: 27,
    question: "Wie viele Bücher liest du pro Jahr?",
    category: QuestionCategory.entertainment,
  ),
  const Question(
    id: 28,
    question: "Wie viele Filme hast du im letzten Monat gesehen?",
    category: QuestionCategory.entertainment,
  ),
  const Question(
    id: 29,
    question: "Wie viele Stunden pro Tag verbringst du auf Social Media?",
    category: QuestionCategory.entertainment,
  ),
  const Question(
    id: 30,
    question: "Wie viele Songs sind in deiner Lieblings-Playlist?",
    category: QuestionCategory.entertainment,
  ),

  // -------------------------------------------------------------------------
  // ❤️ DATING
  // -------------------------------------------------------------------------
  const Question(
    id: 31,
    question: "Wie viele Dates hattest du im letzten Jahr?",
    category: QuestionCategory.dating,
  ),
  const Question(
    id: 32,
    question: "Wie attraktiv findest du dein letztes Date auf einer Skala von 1–10?",
    category: QuestionCategory.dating,
  ),
  const Question(
    id: 33,
    question: "Wie gut bist du im Kommunizieren deiner Gefühle (1–10)?",
    category: QuestionCategory.dating,
  ),
  const Question(
    id: 34,
    question: "Wie viele Beziehungen hattest du bisher?",
    category: QuestionCategory.dating,
  ),
  const Question(
    id: 35,
    question: "Wie viele Monate dauerte deine längste Beziehung?",
    category: QuestionCategory.dating,
  ),
  const Question(
    id: 36,
    question: "Nach wie vielen Dates ist ein Kuss angemessen?",
    category: QuestionCategory.dating,
  ),
  const Question(
    id: 37,
    question: "Wie viele Dating-Apps hast du aktuell installiert?",
    category: QuestionCategory.dating,
  ),
  const Question(
    id: 38,
    question: "Wie viele Körbe hast du im letzten Jahr verteilt?",
    category: QuestionCategory.dating,
  ),
  const Question(
    id: 39,
    question: "Wie viele Jahre Altersunterschied sind in einer Beziehung maximal okay?",
    category: QuestionCategory.dating,
  ),

  // -------------------------------------------------------------------------
  // ✈️ TRAVEL
  // -------------------------------------------------------------------------
  const Question(
    id: 40,
    question: "In wie vielen Ländern warst du schon?",
    category: QuestionCategory.travel,
  ),
  const Question(
    id: 41,
    question: "Wie viele Tage dauerte dein längster Urlaub am Stück?",
    category: QuestionCategory.travel,
  ),
  const Question(
    id: 42,
    question: "Wie viele Stunden dauerte dein längster Flug?",
    category: QuestionCategory.travel,
  ),
  const Question(
    id: 43,
    question: "Wie viele Sprachen sprichst du (auch nur ein bisschen)?",
    category: QuestionCategory.travel,
  ),
  const Question(
    id: 44,
    question: "Wie viele Kilometer bist du maximal für einen Urlaub gefahren/geflogen?",
    category: QuestionCategory.travel,
  ),
  const Question(
    id: 45,
    question: "Wie viele Hotels hast du in deinem Leben schon besucht?",
    category: QuestionCategory.travel,
  ),
  const Question(
    id: 46,
    question: "Wie viele Koffer nimmst du normalerweise für eine Woche Urlaub mit?",
    category: QuestionCategory.travel,
  ),
  const Question(
    id: 47,
    question: "Wie viel Geld gibst du durchschnittlich pro Tag im Urlaub aus? (in €)",
    category: QuestionCategory.travel,
  ),
  const Question(
    id: 48,
    question: "Wie viele Souvenirs kaufst du durchschnittlich pro Reise?",
    category: QuestionCategory.travel,
  ),
  const Question(
    id: 49,
    question: "Wie viele Monate im Voraus planst du deinen Urlaub meistens?",
    category: QuestionCategory.travel,
  ),

  // -------------------------------------------------------------------------
  // 📱 TECHNOLOGY
  // -------------------------------------------------------------------------
  const Question(
    id: 50,
    question: "Wie viele Fotos hast du aktuell auf deinem Handy?",
    category: QuestionCategory.technology,
  ),
  const Question(
    id: 51,
    question: "Wie viele Apps hast du installiert?",
    category: QuestionCategory.technology,
  ),
  const Question(
    id: 52,
    question: "Wie viele ungelesene E-Mails hast du gerade?",
    category: QuestionCategory.technology,
  ),
  const Question(
    id: 53,
    question: "Wie viel Prozent Akku hast du gerade noch?",
    category: QuestionCategory.technology,
  ),
  const Question(
    id: 54,
    question: "Wie viele Jahre alt ist dein aktuelles Handy?",
    category: QuestionCategory.technology,
  ),
  const Question(
    id: 55,
    question: "Wie viele verschiedene Handynummern hattest du schon?",
    category: QuestionCategory.technology,
  ),
  const Question(
    id: 56,
    question: "Wie viele Stunden verbringst du täglich am Laptop/PC?",
    category: QuestionCategory.technology,
  ),
  const Question(
    id: 57,
    question: "Wie viele Abos (Netflix, Spotify, etc.) bezahlst du aktuell?",
    category: QuestionCategory.technology,
  ),
  const Question(
    id: 58,
    question: "Wie viele Tabs hast du gerade in deinem Browser offen?",
    category: QuestionCategory.technology,
  ),
  const Question(
    id: 59,
    question: "Wie viele Ladegeräte besitzt du insgesamt?",
    category: QuestionCategory.technology,
  ),
];

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/// Get all questions from a specific category
List<Question> getQuestionsByCategory(QuestionCategory category) {
  return questions.where((q) => q.category == category).toList();
}

/// Get a random question from the list
Question getRandomQuestion() {
  questions.shuffle();
  return questions.first;
}

/// Get two different random questions (one for normal players, one for liar)
/// Returns a map with 'normal' and 'liar' questions
/// Both questions will be from the SAME category to make it fair but challenging
Map<String, Question> getQuestionPair() {
  // 1. Pick a random category
  const categories = QuestionCategory.values;
  final randomCategory = categories[Random().nextInt(categories.length)];
  
  // 2. Get all questions from that category
  final categoryQuestions = getQuestionsByCategory(randomCategory);
  
  // Safety check: if category has less than 2 questions, fallback to random
  if (categoryQuestions.length < 2) {
    final shuffled = List<Question>.from(questions)..shuffle();
    return {
      'normal': shuffled[0],
      'liar': shuffled[1],
    };
  }

  // 3. Shuffle and pick two different questions from that category
  categoryQuestions.shuffle();
  
  return {
    'normal': categoryQuestions[0],
    'liar': categoryQuestions[1],
  };
}

/// Get questions count
int get questionsCount => questions.length;

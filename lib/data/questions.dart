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
    question: "How much money would you spend on a first date? (in €)",
    category: QuestionCategory.money,
  ),
  const Question(
    id: 2,
    question: "How much do you spend on groceries per week? (in €)",
    category: QuestionCategory.money,
  ),
  const Question(
    id: 3,
    question: "What's the maximum you'd pay for a concert ticket? (in €)",
    category: QuestionCategory.money,
  ),
  const Question(
    id: 4,
    question: "How much money do you save per month? (in €)",
    category: QuestionCategory.money,
  ),
  const Question(
    id: 5,
    question: "What's the most you've ever spent on a single clothing item? (in €)",
    category: QuestionCategory.money,
  ),

  // -------------------------------------------------------------------------
  // 🌟 LIFESTYLE
  // -------------------------------------------------------------------------
  const Question(
    id: 6,
    question: "How many hours do you sleep per night on average?",
    category: QuestionCategory.lifestyle,
  ),
  const Question(
    id: 7,
    question: "How many times per week do you exercise?",
    category: QuestionCategory.lifestyle,
  ),
  const Question(
    id: 8,
    question: "How many hours of screen time do you have per day?",
    category: QuestionCategory.lifestyle,
  ),
  const Question(
    id: 9,
    question: "How many alarms do you set in the morning?",
    category: QuestionCategory.lifestyle,
  ),
  const Question(
    id: 10,
    question: "How many minutes does it take you to get ready in the morning?",
    category: QuestionCategory.lifestyle,
  ),

  // -------------------------------------------------------------------------
  // 🍕 FOOD & DRINKS
  // -------------------------------------------------------------------------
  const Question(
    id: 11,
    question: "How many cups of coffee/tea do you drink per day?",
    category: QuestionCategory.food,
  ),
  const Question(
    id: 12,
    question: "How many times per week do you eat fast food?",
    category: QuestionCategory.food,
  ),
  const Question(
    id: 13,
    question: "How many glasses of water do you drink per day?",
    category: QuestionCategory.food,
  ),
  const Question(
    id: 14,
    question: "How many times per month do you order food delivery?",
    category: QuestionCategory.food,
  ),
  const Question(
    id: 15,
    question: "How many slices of pizza can you eat in one sitting?",
    category: QuestionCategory.food,
  ),

  // -------------------------------------------------------------------------
  // 👥 SOCIAL
  // -------------------------------------------------------------------------
  const Question(
    id: 16,
    question: "How many close friends do you have?",
    category: QuestionCategory.social,
  ),
  const Question(
    id: 17,
    question: "How many parties have you been to this year?",
    category: QuestionCategory.social,
  ),
  const Question(
    id: 18,
    question: "How many times per week do you text your best friend?",
    category: QuestionCategory.social,
  ),
  const Question(
    id: 19,
    question: "How many people would you invite to your birthday party?",
    category: QuestionCategory.social,
  ),
  const Question(
    id: 20,
    question: "How many minutes late do you usually arrive to meetings?",
    category: QuestionCategory.social,
  ),

  // -------------------------------------------------------------------------
  // 💼 WORK & SCHOOL
  // -------------------------------------------------------------------------
  const Question(
    id: 21,
    question: "How many hours per day do you spend on work/studies?",
    category: QuestionCategory.work,
  ),
  const Question(
    id: 22,
    question: "How many sick days have you taken this year?",
    category: QuestionCategory.work,
  ),
  const Question(
    id: 23,
    question: "How many emails do you receive per day on average?",
    category: QuestionCategory.work,
  ),
  const Question(
    id: 24,
    question: "How many meetings do you have per week?",
    category: QuestionCategory.work,
  ),

  // -------------------------------------------------------------------------
  // 🎮 ENTERTAINMENT
  // -------------------------------------------------------------------------
  const Question(
    id: 25,
    question: "How many hours per week do you spend playing video games?",
    category: QuestionCategory.entertainment,
  ),
  const Question(
    id: 26,
    question: "How many TV series are you currently watching?",
    category: QuestionCategory.entertainment,
  ),
  const Question(
    id: 27,
    question: "How many books do you read per year?",
    category: QuestionCategory.entertainment,
  ),
  const Question(
    id: 28,
    question: "How many movies have you watched in the last month?",
    category: QuestionCategory.entertainment,
  ),
  const Question(
    id: 29,
    question: "How many hours per day do you spend on social media?",
    category: QuestionCategory.entertainment,
  ),
  const Question(
    id: 30,
    question: "How many songs are in your favorite playlist?",
    category: QuestionCategory.entertainment,
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
Map<String, Question> getQuestionPair() {
  final shuffled = List<Question>.from(questions)..shuffle();
  return {
    'normal': shuffled[0],
    'liar': shuffled[1],
  };
}

/// Get questions count
int get questionsCount => questions.length;

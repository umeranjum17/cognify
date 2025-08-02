import 'dart:math';

/// Daily Quote Model
class DailyQuote {
  final String quote;
  final String author;
  final String category;
  final String? source;

  DailyQuote({
    required this.quote,
    required this.author,
    required this.category,
    this.source,
  });

  factory DailyQuote.fromJson(Map<String, dynamic> json) => DailyQuote(
    quote: json['quote'] ?? '',
    author: json['author'] ?? '',
    category: json['category'] ?? 'wisdom',
    source: json['source'],
  );

  Map<String, dynamic> toJson() => {
    'quote': quote,
    'author': author,
    'category': category,
    if (source != null) 'source': source,
  };
}

/// Daily Quotes Service - Provides daily wisdom quotes locally
class DailyQuotesService {
  static const Duration _cacheTimeout = Duration(hours: 6);
  
  DateTime? _lastRefresh;
  DailyQuote? _cachedQuote;
  bool _isRefreshing = false;

  // Fallback quotes database (similar to legacy server)
  static const List<Map<String, dynamic>> _fallbackQuotes = [
    {
      "quote": "The only way to do great work is to love what you do.",
      "author": "Steve Jobs",
      "category": "motivation"
    },
    {
      "quote": "Innovation distinguishes between a leader and a follower.",
      "author": "Steve Jobs",
      "category": "innovation"
    },
    {
      "quote": "Your time is limited, don't waste it living someone else's life.",
      "author": "Steve Jobs",
      "category": "life"
    },
    {
      "quote": "Stay hungry, stay foolish.",
      "author": "Steve Jobs",
      "category": "motivation"
    },
    {
      "quote": "The future belongs to those who believe in the beauty of their dreams.",
      "author": "Eleanor Roosevelt",
      "category": "dreams"
    },
    {
      "quote": "It is during our darkest moments that we must focus to see the light.",
      "author": "Aristotle",
      "category": "perseverance"
    },
    {
      "quote": "Success is not final, failure is not fatal: it is the courage to continue that counts.",
      "author": "Winston Churchill",
      "category": "success"
    },
    {
      "quote": "The way to get started is to quit talking and begin doing.",
      "author": "Walt Disney",
      "category": "action"
    },
    {
      "quote": "Don't be afraid to give up the good to go for the great.",
      "author": "John D. Rockefeller",
      "category": "excellence"
    },
    {
      "quote": "If you really look closely, most overnight successes took a long time.",
      "author": "Steve Jobs",
      "category": "success"
    },
    {
      "quote": "The only true wisdom is in knowing you know nothing.",
      "author": "Socrates",
      "category": "wisdom"
    },
    {
      "quote": "An unexamined life is not worth living.",
      "author": "Socrates",
      "category": "philosophy"
    },
    {
      "quote": "We are what we repeatedly do. Excellence, then, is not an act, but a habit.",
      "author": "Aristotle",
      "category": "excellence"
    },
    {
      "quote": "The only impossible journey is the one you never begin.",
      "author": "Tony Robbins",
      "category": "journey"
    },
    {
      "quote": "In the middle of difficulty lies opportunity.",
      "author": "Albert Einstein",
      "category": "opportunity"
    },
    {
      "quote": "Life is what happens to you while you're busy making other plans.",
      "author": "John Lennon",
      "category": "life"
    },
    {
      "quote": "The purpose of our lives is to be happy.",
      "author": "Dalai Lama",
      "category": "happiness"
    },
    {
      "quote": "Life is really simple, but we insist on making it complicated.",
      "author": "Confucius",
      "category": "simplicity"
    },
    {
      "quote": "Yesterday is history, tomorrow is a mystery, today is a gift.",
      "author": "Eleanor Roosevelt",
      "category": "present"
    },
    {
      "quote": "Be yourself; everyone else is already taken.",
      "author": "Oscar Wilde",
      "category": "authenticity"
    },
    {
      "quote": "The best way to predict the future is to invent it.",
      "author": "Alan Kay",
      "category": "innovation"
    },
    {
      "quote": "Code is like humor. When you have to explain it, it's bad.",
      "author": "Cory House",
      "category": "programming"
    },
    {
      "quote": "First, solve the problem. Then, write the code.",
      "author": "John Johnson",
      "category": "problem_solving"
    },
    {
      "quote": "Experience is the name everyone gives to their mistakes.",
      "author": "Oscar Wilde",
      "category": "learning"
    },
    {
      "quote": "In order to be irreplaceable, one must always be different.",
      "author": "Coco Chanel",
      "category": "innovation"
    },
    {
      "quote": "The computer was born to solve problems that did not exist before.",
      "author": "Bill Gates",
      "category": "technology"
    },
    {
      "quote": "The most damaging phrase in the language is 'We've always done it this way.'",
      "author": "Grace Hopper",
      "category": "innovation"
    },
    {
      "quote": "Any fool can write code that a computer can understand. Good programmers write code that humans can understand.",
      "author": "Martin Fowler",
      "category": "programming"
    },
    {
      "quote": "The best error message is the one that never shows up.",
      "author": "Thomas Fuchs",
      "category": "programming"
    },
    {
      "quote": "It's not a bug – it's an undocumented feature.",
      "author": "Anonymous",
      "category": "humor"
    },
    {
      "quote": "The only way to learn a new programming language is by writing programs in it.",
      "author": "Dennis Ritchie",
      "category": "learning"
    },
    {
      "quote": "Sometimes it pays to stay in bed on Monday, rather than spending the rest of the week debugging Monday's code.",
      "author": "Dan Salomon",
      "category": "programming"
    },
    {
      "quote": "Talk is cheap. Show me the code.",
      "author": "Linus Torvalds",
      "category": "programming"
    },
    {
      "quote": "The most important single aspect of software development is to be clear about what you are trying to build.",
      "author": "Bjarne Stroustrup",
      "category": "programming"
    },
    {
      "quote": "Good code is its own best documentation.",
      "author": "Steve McConnell",
      "category": "programming"
    },
    {
      "quote": "The best thing about a boolean is even if you are wrong, you are only off by a bit.",
      "author": "Anonymous",
      "category": "humor"
    },
    {
      "quote": "Without requirements or design, programming is the art of adding bugs to an empty text file.",
      "author": "Louis Srygley",
      "category": "programming"
    },
    {
      "quote": "Before software can be reusable it first has to be usable.",
      "author": "Ralph Johnson",
      "category": "programming"
    },
    {
      "quote": "The best way to get a project done faster is to start sooner.",
      "author": "Jim Highsmith",
      "category": "productivity"
    },
    {
      "quote": "Even the best planning is not so omniscient as to get it right the first time.",
      "author": "Fred Brooks",
      "category": "planning"
    },
    {
      "quote": "The only way to do great work is to love what you do.",
      "author": "Steve Jobs",
      "category": "motivation"
    },
    {
      "quote": "Innovation distinguishes between a leader and a follower.",
      "author": "Steve Jobs",
      "category": "innovation"
    },
    {
      "quote": "Your time is limited, don't waste it living someone else's life.",
      "author": "Steve Jobs",
      "category": "life"
    },
    {
      "quote": "Stay hungry, stay foolish.",
      "author": "Steve Jobs",
      "category": "motivation"
    },
    {
      "quote": "The future belongs to those who believe in the beauty of their dreams.",
      "author": "Eleanor Roosevelt",
      "category": "dreams"
    },
    {
      "quote": "It is during our darkest moments that we must focus to see the light.",
      "author": "Aristotle",
      "category": "perseverance"
    },
    {
      "quote": "Success is not final, failure is not fatal: it is the courage to continue that counts.",
      "author": "Winston Churchill",
      "category": "success"
    },
    {
      "quote": "The way to get started is to quit talking and begin doing.",
      "author": "Walt Disney",
      "category": "action"
    },
    {
      "quote": "Don't be afraid to give up the good to go for the great.",
      "author": "John D. Rockefeller",
      "category": "excellence"
    },
    {
      "quote": "If you really look closely, most overnight successes took a long time.",
      "author": "Steve Jobs",
      "category": "success"
    },
    {
      "quote": "The only true wisdom is in knowing you know nothing.",
      "author": "Socrates",
      "category": "wisdom"
    },
    {
      "quote": "An unexamined life is not worth living.",
      "author": "Socrates",
      "category": "philosophy"
    },
    {
      "quote": "We are what we repeatedly do. Excellence, then, is not an act, but a habit.",
      "author": "Aristotle",
      "category": "excellence"
    },
    {
      "quote": "The only impossible journey is the one you never begin.",
      "author": "Tony Robbins",
      "category": "journey"
    },
    {
      "quote": "In the middle of difficulty lies opportunity.",
      "author": "Albert Einstein",
      "category": "opportunity"
    },
    {
      "quote": "Life is what happens to you while you're busy making other plans.",
      "author": "John Lennon",
      "category": "life"
    },
    {
      "quote": "The purpose of our lives is to be happy.",
      "author": "Dalai Lama",
      "category": "happiness"
    },
    {
      "quote": "Life is really simple, but we insist on making it complicated.",
      "author": "Confucius",
      "category": "simplicity"
    },
    {
      "quote": "Yesterday is history, tomorrow is a mystery, today is a gift.",
      "author": "Eleanor Roosevelt",
      "category": "present"
    },
    {
      "quote": "Be yourself; everyone else is already taken.",
      "author": "Oscar Wilde",
      "category": "authenticity"
    },
  ];

  /// Get daily quote with caching
  Future<DailyQuote> getDailyQuote({bool forceRefresh = false}) async {
    // Return cached quote if available and not forcing refresh
    if (!forceRefresh && _cachedQuote != null && _lastRefresh != null) {
      final cacheAge = DateTime.now().difference(_lastRefresh!);
      if (cacheAge < _cacheTimeout) {
        print('📦 Returning cached daily quote');
        return _cachedQuote!;
      }
    }

    // Prevent concurrent refreshes
    if (_isRefreshing) {
      print('⏳ Daily quote refresh in progress, waiting...');
      while (_isRefreshing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _cachedQuote ?? _getRandomFallbackQuote();
    }

    return _refreshQuote();
  }

  /// Refresh daily quote
  Future<DailyQuote> _refreshQuote() async {
    _isRefreshing = true;
    
    try {
      print('🔄 Selecting daily quote from local database...');
      
      // Use local quotes database
      final quote = _getRandomFallbackQuote();
      
      _cachedQuote = quote;
      _lastRefresh = DateTime.now();
      
      print('✅ Selected daily quote: "${quote.quote}" - ${quote.author}');
      return quote;
      
    } catch (error) {
      print('❌ Daily quote refresh failed: $error');
      return _cachedQuote ?? _getRandomFallbackQuote();
    } finally {
      _isRefreshing = false;
    }
  }

  /// Get random quote from fallback database
  DailyQuote _getRandomFallbackQuote() {
    final random = Random();
    final randomIndex = random.nextInt(_fallbackQuotes.length);
    final quoteData = _fallbackQuotes[randomIndex];
    
    return DailyQuote.fromJson(quoteData);
  }

  /// Clear cache and force refresh
  void clearCache() {
    _cachedQuote = null;
    _lastRefresh = null;
    print('🗑️ Daily quote cache cleared');
  }

  /// Get cache stats
  Map<String, dynamic> getCacheStats() {
    return {
      'hasCache': _cachedQuote != null,
      'lastRefresh': _lastRefresh?.toIso8601String(),
      'cacheAge': _lastRefresh != null 
          ? DateTime.now().difference(_lastRefresh!).inMinutes 
          : null,
      'isRefreshing': _isRefreshing,
      'totalQuotes': _fallbackQuotes.length,
    };
  }
} 
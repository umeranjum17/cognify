// Daily quotes service stub
class Quote {
  final String quote;
  final String author;
  final String category;

  Quote({required this.quote, required this.author, required this.category});
}

class DailyQuotesService {
  Future<Quote> getDailyQuote() async {
    return Quote(
      quote: 'Stay curious, keep learning.',
      author: 'Anonymous',
      category: 'Motivation',
    );
  }
}

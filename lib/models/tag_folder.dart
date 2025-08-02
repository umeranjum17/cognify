import 'note.dart';

class TagFolder {
  final String tag;
  final List<Note> notes;
  final int count;

  TagFolder({required this.tag, required this.notes, required this.count});
}

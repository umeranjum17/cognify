import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import 'conversation.dart';

class EditorTab {
  final String id;
  final String title;
  final DateTime createdAt;
  final Conversation? conversation;
  final bool hasUnsavedChanges;
  final bool isActive;

  const EditorTab({
    required this.id,
    required this.title,
    required this.createdAt,
    this.conversation,
    this.hasUnsavedChanges = false,
    this.isActive = false,
  });

  EditorTab copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    Conversation? conversation,
    bool? hasUnsavedChanges,
    bool? isActive,
  }) {
    return EditorTab(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      conversation: conversation ?? this.conversation,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      isActive: isActive ?? this.isActive,
    );
  }

  static EditorTab createNew({String? title}) {
    return EditorTab(
      id: const Uuid().v4(),
      title: title ?? 'New Chat',
      createdAt: DateTime.now(),
    );
  }

  static EditorTab fromConversation(Conversation conversation) {
    return EditorTab(
      id: conversation.id,
      title: conversation.title,
      createdAt: conversation.createdAt,
      conversation: conversation,
    );
  }
}

class TabManager {
  final List<EditorTab> _tabs = [];
  int _activeTabIndex = 0;

  List<EditorTab> get tabs => List.unmodifiable(_tabs);
  EditorTab? get activeTab => _tabs.isNotEmpty ? _tabs[_activeTabIndex] : null;
  int get activeTabIndex => _activeTabIndex;
  bool get isEmpty => _tabs.isEmpty;

  void addTab(EditorTab tab) {
    final updatedTab = tab.copyWith(isActive: false);
    _tabs.add(updatedTab);
    _setActiveTab(_tabs.length - 1);
  }

  void removeTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    
    _tabs.removeAt(index);
    
    if (_tabs.isEmpty) {
      _activeTabIndex = 0;
    } else if (index <= _activeTabIndex) {
      _activeTabIndex = math.max(0, _activeTabIndex - 1);
    }
    
    _updateActiveStates();
  }

  void setActiveTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      _setActiveTab(index);
    }
  }

  void _setActiveTab(int index) {
    _activeTabIndex = index;
    _updateActiveStates();
  }

  void _updateActiveStates() {
    for (int i = 0; i < _tabs.length; i++) {
      _tabs[i] = _tabs[i].copyWith(isActive: i == _activeTabIndex);
    }
  }

  void updateTab(int index, EditorTab tab) {
    if (index >= 0 && index < _tabs.length) {
      _tabs[index] = tab.copyWith(isActive: index == _activeTabIndex);
    }
  }

  EditorTab? getTab(int index) {
    return index >= 0 && index < _tabs.length ? _tabs[index] : null;
  }
}
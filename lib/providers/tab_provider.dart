import 'package:flutter/material.dart';
import '../models/editor_tab.dart';
import '../models/conversation.dart';
import '../models/message.dart' as msg;
import '../services/conversation_service.dart';

class TabProvider extends ChangeNotifier {
  final TabManager _tabManager = TabManager();
  final ConversationService _conversationService = ConversationService();

  List<EditorTab> get tabs => _tabManager.tabs;
  EditorTab? get activeTab => _tabManager.activeTab;
  int get activeTabIndex => _tabManager.activeTabIndex;
  bool get isEmpty => _tabManager.isEmpty;

  void createNewTab({String? title}) {
    // Limit to maximum 3 tabs
    if (_tabManager.tabs.length >= 3) {
      return;
    }
    
    final newTab = EditorTab.createNew(title: title ?? 'New Chat');
    _tabManager.addTab(newTab);
    notifyListeners();
  }

  void closeTab(int index) {
    // If this is the last tab, remove it and immediately create a new one
    if (_tabManager.tabs.length <= 1) {
      _tabManager.removeTab(index);
      // Always start a fresh chat replacement
      final newTab = EditorTab.createNew(title: 'New Chat');
      _tabManager.addTab(newTab);
      notifyListeners();
      return;
    }

    _tabManager.removeTab(index);
    notifyListeners();
  }

  void switchToTab(int index) {
    _tabManager.setActiveTab(index);
    notifyListeners();
  }

  Future<void> loadConversationInTab(String conversationId) async {
    // Limit to maximum 3 tabs
    if (_tabManager.tabs.length >= 3) {
      return;
    }
    
    final conversationData = await _conversationService.loadConversation(conversationId);
    if (conversationData != null) {
      // Load messages as the Message type from message.dart (used by ConversationService)
      final messages = (conversationData['messages'] as List?)
          ?.map((m) => msg.Message.fromJson(m))
          .toList() ?? <msg.Message>[];
      
      // Create conversation with empty messages list since we'll store the actual messages separately
      final conversation = Conversation(
        id: conversationData['id'],
        title: conversationData['title'] ?? 'Untitled',
        createdAt: DateTime.parse(conversationData['createdAt']),
        updatedAt: DateTime.parse(conversationData['updatedAt']),
        messages: [], // Empty list for now, EditorScreen will handle actual messages
        metadata: conversationData['metadata'],
      );

      final tab = EditorTab.fromConversation(conversation);
      _tabManager.addTab(tab);
      notifyListeners();
    }
  }

  void updateActiveTabConversation({
    String? title,
    List<msg.Message>? messages,
    Map<String, dynamic>? metadata,
  }) {
    final activeTab = _tabManager.activeTab;
    if (activeTab == null) return;

    final currentConversation = activeTab.conversation;
    final updatedConversation = currentConversation?.copyWith(
      title: title ?? currentConversation.title,
      messages: [], // EditorScreen handles actual messages
      metadata: metadata ?? currentConversation.metadata,
      updatedAt: DateTime.now(),
    ) ?? Conversation(
      id: activeTab.id,
      title: title ?? activeTab.title,
      createdAt: activeTab.createdAt,
      updatedAt: DateTime.now(),
      messages: [], // EditorScreen handles actual messages
      metadata: metadata,
    );

    final updatedTab = activeTab.copyWith(
      title: title ?? activeTab.title,
      conversation: updatedConversation,
      hasUnsavedChanges: true,
    );

    _tabManager.updateTab(_tabManager.activeTabIndex, updatedTab);
    notifyListeners();
  }

  /// Update only the active tab's title without touching the underlying
  /// conversation object. Useful for showing a short snippet in the tab
  /// while keeping a longer/more descriptive conversation title elsewhere.
  void updateActiveTabTitle(String title) {
    final activeTab = _tabManager.activeTab;
    if (activeTab == null) return;

    final updatedTab = activeTab.copyWith(title: title);
    _tabManager.updateTab(_tabManager.activeTabIndex, updatedTab);
    notifyListeners();
  }

  Future<void> saveActiveTab() async {
    final activeTab = _tabManager.activeTab;
    if (activeTab?.conversation == null) return;

    final conversation = activeTab!.conversation!;
    // For now, let the EditorScreen handle saving its own messages
    // This method is here for future use when we need to save tab-specific data
    
    final updatedTab = activeTab.copyWith(hasUnsavedChanges: false);
    _tabManager.updateTab(_tabManager.activeTabIndex, updatedTab);
    notifyListeners();
  }

  Future<void> initializeWithFirstTab() async {
    if (!isEmpty) return;

    // Always start with a fresh blank tab on first load. We intentionally
    // avoid auto-opening the most recent conversation to prevent previously
    // saved messages from reappearing after app restarts.
    createNewTab();
  }
}

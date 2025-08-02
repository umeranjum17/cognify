import 'package:flutter/material.dart';

import '../services/unified_api_service.dart';
import '../theme/app_theme.dart';

class EntityConnection {
  final EntityNode from;
  final EntityNode to;
  final double strength;

  EntityConnection({
    required this.from,
    required this.to,
    required this.strength,
  });
}

// Entity details modal
class EntityDetailsModal extends StatelessWidget {
  final EntityNode entity;
  final List<EntityConnection> connections;

  const EntityDetailsModal({
    super.key,
    required this.entity,
    required this.connections,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.psychology,
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entity.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Wrap(
                      spacing: 4,
                      children: entity.types.map((type) => Chip(
                        label: Text(type, style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                        )),
                        backgroundColor: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.08),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Statistics
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  theme,
                  'Mentions',
                  entity.frequency.toString(),
                  Icons.chat,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  theme,
                  'Conversations',
                  entity.conversations.length.toString(),
                  Icons.forum,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  theme,
                  'Connections',
                  connections.length.toString(),
                  Icons.link,
                ),
              ),
            ],
          ),

          if (connections.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Connected Entities',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: connections.length,
                itemBuilder: (context, index) {
                  final connection = connections[index];
                  final connectedEntity = connection.from == entity
                      ? connection.to
                      : connection.from;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.2),
                      child: Text(
                        connectedEntity.name.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(connectedEntity.name),
                    subtitle: Text(connectedEntity.type),
                    trailing: Text(
                      '${connection.strength.toInt()} shared',
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(ThemeData theme, String label, String value, IconData icon) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: isDark ? AppColors.darkAccent : AppColors.lightAccent),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// Data models for personal knowledge graph
class EntityNode {
  final String name;
  final List<String> types;
  int frequency;
  final List<String> conversations;

  EntityNode({
    required this.name,
    required this.types,
    required this.frequency,
    required this.conversations,
  });

  // Getter for legacy code expecting a single type
  String get type => types.isNotEmpty ? types.first : '';
}

class KnowledgeGraphTab extends StatefulWidget {
  const KnowledgeGraphTab({super.key});

  @override
  State<KnowledgeGraphTab> createState() => _KnowledgeGraphTabState();
}

class _KnowledgeGraphTabState extends State<KnowledgeGraphTab> {
  List<EntityNode> _entities = [];
  List<EntityConnection> _connections = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'People',
    'Organizations',
    'Technologies',
    'Concepts',
    'Projects',
    'Locations'
  ];

  List<EntityNode> get _filteredEntities {
    var filtered = _entities;

    // Filter by category (match any type)
    if (_selectedCategory != 'All') {
      filtered = filtered.where((entity) => entity.types.contains(_selectedCategory)).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((entity) =>
        entity.name.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.psychology,
                color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              ),
              const SizedBox(width: 8),
              Text(
                'Personal Knowledge Graph',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (!_isLoading)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadEntities,
                  tooltip: 'Refresh knowledge graph',
                ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _entities.isEmpty
                  ? _buildEmptyState(theme)
                  : _buildEntitiesView(theme),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadEntities();
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.psychology,
            size: 64,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No knowledge graph yet',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start conversations to build your personal knowledge graph',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEntitiesView(ThemeData theme) {
    return Column(
      children: [
        // Stats and search
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Stats row
              Row(
                children: [
                  _buildStatChip(
                    theme,
                    'Entities',
                    _entities.length.toString(),
                    Icons.account_tree,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    theme,
                    'Connections',
                    _connections.length.toString(),
                    Icons.link,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    theme,
                    'Categories',
                    _entities.map((e) => e.type).toSet().length.toString(),
                    Icons.category,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Search bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search entities...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
                  ),
                  filled: true,
                  fillColor: theme.cardColor,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ],
          ),
        ),

        // Category Filter
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isSelected = category == _selectedCategory;
              final count = category == 'All'
                  ? _entities.length
                  : _entities.where((e) => e.type == category).length;

              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(category),
                      if (count > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.8)
                                : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            count.toString(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? theme.primaryColor
                                  : theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                  backgroundColor: theme.cardColor,
                  selectedColor: (theme.brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.2),
                  checkmarkColor: theme.brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent,
                ),
              );
            },
          ),
        ),

        // Entities grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _filteredEntities.length,
            itemBuilder: (context, index) {
              final entity = _filteredEntities[index];
              return _buildEntityCard(entity, theme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEntityCard(EntityNode entity, ThemeData theme) {
    final color = _getEntityColor(entity.type);
    final connections = _connections.where((conn) =>
      conn.from == entity || conn.to == entity
    ).length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showEntityDetails(entity),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 4,
                children: entity.types.map((type) {
                  final tColor = _getEntityColor(type);
                  return Chip(
                    label: Text(type, style: theme.textTheme.bodySmall?.copyWith(
                      color: tColor,
                      fontWeight: FontWeight.w600,
                    )),
                    backgroundColor: tColor.withValues(alpha: 0.08),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                entity.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entity.frequency}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        'mentions',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        connections.toString(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                      Text(
                        'connections',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(ThemeData theme, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.textTheme.bodySmall?.color),
          const SizedBox(width: 4),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<EntityNode>> _extractEntitiesFromConversations(List conversations) async {
    final Map<String, EntityNode> entityMap = {};

    print('🧠 Knowledge Graph: Processing ${conversations.length} conversations');

    for (final conversation in conversations) {
      final conversationId = conversation['id'] as String? ?? '';
      final messages = conversation['messages'] as List? ?? [];

      print('🧠 Processing conversation: $conversationId with ${messages.length} messages');

      for (final message in messages) {
        String messageContent = '';

        // Handle different content formats
        final content = message['content'];
        if (content is String) {
          messageContent = content;
        } else if (content is List) {
          // Extract text from content array
          messageContent = content
              .where((part) => part is Map && part['type'] == 'text')
              .map((part) => part['text'] as String? ?? '')
              .join(' ');
        }

        if (messageContent.isNotEmpty) {
          // Enhanced entity extraction
          final entities = _extractEntitiesFromText(messageContent);

          for (final entity in entities) {
            // Normalize entity name to fix casing duplicates
            final normalizedName = _normalizeEntityName(entity.name);
            final key = '${normalizedName}_${entity.type}';

            if (entityMap.containsKey(key)) {
              entityMap[key]!.frequency++;
              if (!entityMap[key]!.conversations.contains(conversationId)) {
                entityMap[key]!.conversations.add(conversationId);
              }
            } else {
              // Create entity with normalized name
              final normalizedEntity = EntityNode(
                name: normalizedName,
                types: [entity.type],
                frequency: entity.frequency,
                conversations: [],
              );
              entityMap[key] = normalizedEntity;
              normalizedEntity.conversations.add(conversationId);
            }
          }
        }
      }
    }

    final entities = entityMap.values.toList()
      ..sort((a, b) => b.frequency.compareTo(a.frequency));

    print('🧠 Knowledge Graph: Extracted ${entities.length} unique entities');
    for (final entity in entities.take(5)) {
      print('🧠 Entity: ${entity.name} (${entity.type}) - frequency: ${entity.frequency}');
    }

    return entities;
  }

  // Stub for legacy extraction, returns empty list
  List<EntityNode> _extractEntitiesFromText(String text) {
    // Entity extraction is now handled by backend API.
    return [];
  }

  // Regex-based entity extraction removed. Entities will be loaded from backend API.

  List<EntityConnection> _generateConnections(List<EntityNode> entities) {
    final connections = <EntityConnection>[];

    // Generate connections based on co-occurrence in conversations
    for (int i = 0; i < entities.length; i++) {
      for (int j = i + 1; j < entities.length; j++) {
        final entity1 = entities[i];
        final entity2 = entities[j];

        final sharedConversations = entity1.conversations
            .where((conv) => entity2.conversations.contains(conv))
            .length;

        if (sharedConversations > 0) {
          connections.add(EntityConnection(
            from: entity1,
            to: entity2,
            strength: sharedConversations.toDouble(),
          ));
        }
      }
    }

    return connections..sort((a, b) => b.strength.compareTo(a.strength));
  }

  Color _getEntityColor(String type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (type) {
      case 'People': return Colors.blue;
      case 'Organizations': return Colors.green;
      case 'Technologies': return isDark ? AppColors.darkAccent : AppColors.lightAccent;
      case 'Concepts': return Colors.purple;
      case 'Projects': return Colors.red;
      case 'Locations': return Colors.teal;
      default: return Colors.grey;
    }
  }

  IconData _getEntityIcon(String type) {
    switch (type) {
      case 'People': return Icons.person;
      case 'Organizations': return Icons.business;
      case 'Technologies': return Icons.computer;
      case 'Concepts': return Icons.lightbulb;
      case 'Projects': return Icons.work;
      case 'Locations': return Icons.location_on;
      default: return Icons.category;
    }
  }

  Future<void> _loadEntities() async {
    setState(() => _isLoading = true);

    try {
      final apiService = UnifiedApiService();
      final rawEntities = await apiService.getKnowledgeGraphEntities();

      final entities = rawEntities.map<EntityNode>((e) {
        // The backend entity structure: { id, type, data, metadata }
        final data = e['data'] ?? {};
        return EntityNode(
          name: data['name'] ?? '',
          types: data['types'] != null ? List<String>.from(data['types']) : [],
          frequency: data['frequency'] ?? 1,
          conversations: data['conversations'] != null ? List<String>.from(data['conversations']) : [],
        );
      }).toList();

      setState(() {
        _entities = entities;
        _connections = _generateConnections(_entities);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading entities: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Normalize entity names to fix casing duplicates
  String _normalizeEntityName(String name) {
    // Convert to title case for consistency
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  void _showEntityDetails(EntityNode entity) {
    final connections = _connections.where((conn) =>
      conn.from == entity || conn.to == entity
    ).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => EntityDetailsModal(
        entity: entity,
        connections: connections,
      ),
    );
  }
}

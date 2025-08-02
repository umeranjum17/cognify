import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/enhanced_roadmap_models.dart' as enhanced;
import '../models/roadmap_models.dart';
import '../services/roadmap_service.dart';
import '../theme/app_theme.dart';
import '../widgets/flat_enhanced_roadmap_widget.dart';

class RoadmapLearningTab extends StatefulWidget {
  const RoadmapLearningTab({super.key});

  @override
  State<RoadmapLearningTab> createState() => _RoadmapLearningTabState();
}

class _RoadmapLearningTabState extends State<RoadmapLearningTab> {
  enhanced.LearningRole _selectedRole = enhanced.LearningRole.frontend;
  List<enhanced.LearningRole> _availableRoles = [];
  bool _isLoadingRoles = true;
  final RoadmapService _roadmapService = RoadmapService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Role selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.account_tree,
                color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRoleSelector(theme),
              ),
            ],
          ),
        ),

        // Flat enhanced roadmap (clean design)
        Expanded(
          child: FlatEnhancedRoadmapWidget(
            role: _selectedRole,
            onTopicSelected: _handleTopicSelected,
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAvailableRoles();
  }

  Widget _buildRoleSelector(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoadingRoles) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRole.id,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
          ),
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          dropdownColor: theme.cardColor,
          isDense: true,
          onChanged: (String? newRoleId) {
            if (newRoleId != null) {
              _selectRoleById(newRoleId);
            }
          },
          items: _availableRoles.map((enhanced.LearningRole role) {
            return DropdownMenuItem<String>(
              value: role.id,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getRoleIconByName(role.displayName),
                    size: 16,
                    color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      role.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  IconData _getRoleIcon(LearningRole role) {
    switch (role) {
      case LearningRole.frontend:
        return Icons.web;
      case LearningRole.backend:
        return Icons.dns;
      case LearningRole.fullstack:
        return Icons.layers;
      case LearningRole.android:
        return Icons.phone_android;
      case LearningRole.flutter:
        return Icons.flutter_dash;
      case LearningRole.reactNative:
        return Icons.phone_iphone;
      case LearningRole.devops:
        return Icons.cloud;
      case LearningRole.docker:
        return Icons.developer_board;
      case LearningRole.kubernetes:
        return Icons.hub;
      case LearningRole.terraform:
        return Icons.build;
      case LearningRole.dataScience:
        return Icons.analytics;
      case LearningRole.aiDataScientist:
        return Icons.psychology;
      case LearningRole.aiEngineer:
        return Icons.auto_awesome;
      case LearningRole.dataAnalyst:
        return Icons.bar_chart;
      case LearningRole.mlops:
        return Icons.model_training;
      case LearningRole.javascript:
        return Icons.code;
      case LearningRole.typescript:
        return Icons.code;
      case LearningRole.python:
        return Icons.code;
      case LearningRole.java:
        return Icons.code;
      case LearningRole.golang:
        return Icons.code;
      case LearningRole.rust:
        return Icons.code;
      case LearningRole.cpp:
        return Icons.code;
      case LearningRole.react:
        return Icons.web;
      case LearningRole.angular:
        return Icons.web;
      case LearningRole.vue:
        return Icons.web;
      case LearningRole.nodejs:
        return Icons.dns;
      case LearningRole.springBoot:
        return Icons.dns;
      case LearningRole.aspnetCore:
        return Icons.dns;
      case LearningRole.mongodb:
        return Icons.storage;
      case LearningRole.postgresql:
        return Icons.storage;
      case LearningRole.redis:
        return Icons.memory;
      case LearningRole.systemDesign:
        return Icons.architecture;
      case LearningRole.softwareArchitect:
        return Icons.account_tree;
      case LearningRole.apiDesign:
        return Icons.api;
      case LearningRole.designSystem:
        return Icons.design_services;
      case LearningRole.uxDesign:
        return Icons.design_services;
      case LearningRole.productManager:
        return Icons.business;
      case LearningRole.engineeringManager:
        return Icons.engineering;
      case LearningRole.gamedev:
        return Icons.sports_esports;
      case LearningRole.blockchain:
        return Icons.link;
      case LearningRole.cyberSecurity:
        return Icons.security;
      case LearningRole.technicalWriter:
        return Icons.edit;
      case LearningRole.devrel:
        return Icons.people;
      case LearningRole.promptEngineering:
        return Icons.psychology;
      case LearningRole.codeReview:
        return Icons.rate_review;
      case LearningRole.computerScience:
        return Icons.computer;
      case LearningRole.dataStructuresAlgorithms:
        return Icons.account_tree;
      case LearningRole.linux:
        return Icons.terminal;
      case LearningRole.graphql:
        return Icons.api;
    }
  }

  IconData _getRoleIconByName(String roleName) {
    switch (roleName.toLowerCase()) {
      case 'frontend':
        return Icons.web;
      case 'backend':
        return Icons.dns;
      case 'full stack':
      case 'fullstack':
        return Icons.layers;
      case 'devops':
        return Icons.settings;
      case 'ai engineer':
      case 'ai and data scientist':
      case 'data analyst':
      case 'mlops':
        return Icons.psychology;
      case 'android':
        return Icons.android;
      case 'ios':
        return Icons.phone_iphone;
      case 'flutter':
        return Icons.flutter_dash;
      case 'react native':
        return Icons.mobile_friendly;
      case 'javascript':
        return Icons.code;
      case 'typescript':
        return Icons.code;
      case 'python':
        return Icons.code;
      case 'java':
        return Icons.code;
      case 'go roadmap':
      case 'golang':
        return Icons.code;
      case 'rust':
        return Icons.code;
      case 'c++':
        return Icons.code;
      case 'react':
        return Icons.web;
      case 'vue':
        return Icons.web;
      case 'node.js':
        return Icons.dns;
      case 'spring boot':
        return Icons.dns;
      case 'mongodb':
      case 'postgresql':
      case 'redis':
        return Icons.storage;
      case 'docker':
      case 'kubernetes':
      case 'terraform':
        return Icons.cloud;
      case 'system design':
        return Icons.architecture;
      case 'software architect':
        return Icons.architecture;
      case 'design system':
        return Icons.design_services;
      case 'ux design':
        return Icons.design_services;
      case 'product manager':
        return Icons.business;
      case 'engineering manager':
        return Icons.manage_accounts;
      case 'game developer':
        return Icons.games;
      case 'blockchain':
        return Icons.link;
      case 'cyber security':
        return Icons.security;
      case 'technical writer':
        return Icons.edit;
      case 'developer relations':
        return Icons.people;
      case 'prompt engineering':
        return Icons.psychology;
      case 'code review':
        return Icons.rate_review;
      case 'computer science':
        return Icons.computer;
      case 'data structures & algorithms':
        return Icons.account_tree;
      case 'linux':
        return Icons.terminal;
      case 'graphql':
        return Icons.api;
      case 'qa':
        return Icons.bug_report;
      default:
        return Icons.school;
    }
  }

  void _handleTopicSelected(String fullPath) {
    // fullPath is now "Role > Category > Topic"
    final roleId = _selectedRole.id;
    final roleName = _selectedRole.displayName;
    final contextInfo = Uri.encodeComponent('{"role":"$roleName","path":"$fullPath"}');
    final prompt = Uri.encodeComponent('Help me get more insights or help me learn about $fullPath.');
    context.push('/editor?prompt=$prompt&role=$roleId&context=$contextInfo');
  }

  Future<void> _loadAvailableRoles() async {
    try {
      // Use the enhanced roadmap service available roles
      final availableRoadmapIds = ['frontend', 'backend', 'ai-engineer', 'software-architect', 'engineering-manager'];
      final roles = availableRoadmapIds.map((id) => enhanced.LearningRole.fromId(id)).toList();

      setState(() {
        _availableRoles = roles;
        _isLoadingRoles = false;
      });
    } catch (e) {
      print('Error loading roadmap roles: $e');
      setState(() {
        _isLoadingRoles = false;
      });
    }
  }

  void _selectRoleById(String roleId) {
    print('🔄 [ROADMAP_TAB] Selecting role by ID: $roleId');

    final role = _availableRoles.firstWhere(
      (r) => r.id == roleId,
      orElse: () => _availableRoles.first,
    );

    print('🎯 [ROADMAP_TAB] Found role: ${role.displayName} (ID: ${role.id})');

    setState(() {
      _selectedRole = role;
    });

    print('✅ [ROADMAP_TAB] Role selection updated to: ${_selectedRole.displayName}');
  }
}
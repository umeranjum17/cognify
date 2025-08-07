// Feature flags for premium features using two-tier system:
// 1. VISIBLE flags control UI discoverability (show/hide entry points)
// 2. ENABLED flags control actual functionality (requires premium when enabled)
//
// Industry-standard approach:
// - VISIBLE=false: Feature completely hidden (internal/beta/kill switch)
// - VISIBLE=true, ENABLED=false: Shown as "Coming soon" teaser
// - VISIBLE=true, ENABLED=true: Fully functional (requires premium)
class FeatureFlags {
  // Search Agents (initial premium feature)
  static const bool SEARCH_AGENTS_VISIBLE = true;
  // SEARCH_AGENTS_ENABLED deprecated - runtime enablement now derives from entitlement via FeatureAccess

  // Future premium features (examples)
  static const bool KNOWLEDGE_GRAPH_VISIBLE = false;
  static const bool KNOWLEDGE_GRAPH_ENABLED = false;

  static const bool ADVANCED_EXPORTS_VISIBLE = false;
  static const bool ADVANCED_EXPORTS_ENABLED = false;

  static const bool BULK_OPERATIONS_VISIBLE = false;
  static const bool BULK_OPERATIONS_ENABLED = false;

  // Helper methods for consistent feature gating
  static bool canShowFeature(String featureName) {
    switch (featureName) {
      case 'search_agents':
        return SEARCH_AGENTS_VISIBLE;
      case 'knowledge_graph':
        return KNOWLEDGE_GRAPH_VISIBLE;
      case 'advanced_exports':
        return ADVANCED_EXPORTS_VISIBLE;
      case 'bulk_operations':
        return BULK_OPERATIONS_VISIBLE;
      default:
        return false;
    }
  }

  static bool canUseFeature(String featureName) {
    switch (featureName) {
      case 'search_agents':
        return SEARCH_AGENTS_VISIBLE; // Runtime enablement now handled by FeatureAccess
      case 'knowledge_graph':
        return KNOWLEDGE_GRAPH_VISIBLE && KNOWLEDGE_GRAPH_ENABLED;
      case 'advanced_exports':
        return ADVANCED_EXPORTS_VISIBLE && ADVANCED_EXPORTS_ENABLED;
      case 'bulk_operations':
        return BULK_OPERATIONS_VISIBLE && BULK_OPERATIONS_ENABLED;
      default:
        return false;
    }
  }
}

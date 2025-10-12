/// Provider priority system for model ordering
/// Famous providers are ordered first, with budget models grouped separately
class ProviderPriority {
  // Provider priority system - famous providers first
  static const Map<String, int> _providerPriority = {
    'openai': 1,
    'anthropic': 2,
    'claude': 2,
    'google': 3,
    'gemini': 3,
    'deepseek': 4,
    'meta': 5,
    'llama': 5,
    'mistral': 6,
    'mistralai': 6,
    'qwen': 7,
    'cohere': 8,
    'perplexity': 9,
    'x-ai': 10,
    'xai': 10,
    'grok': 10,
    'moonshot': 11,
    'z.ai': 12,
    'stealth': 13,
  };

  /// Get priority for a provider (lower number = higher priority)
  static int getPriority(String provider) {
    return _providerPriority[provider.toLowerCase()] ?? 999;
  }

  /// Check if a provider is considered famous (priority <= 7)
  static bool isFamousProvider(String provider) {
    return getPriority(provider) <= 7;
  }

  /// Check if a model is a budget model based on multiplier
  static bool isBudgetModel(Map<String, dynamic> model) {
    final estimate = model['requestEstimate'] as Map<String, dynamic>?;
    final num units = (estimate?['requestUnits'] as num?) ?? 1.0;
    
    // Budget = models with multiplier <= 0.3 OR explicitly free models
    final pricing = model['pricing'] as Map<String, dynamic>?;
    final bool explicitlyFree = pricing != null &&
        (pricing['input'] == 0 || pricing['input'] == 0.0) &&
        (pricing['output'] == 0 || pricing['output'] == 0.0);
    
    final bool isBudget = units <= 0.3 || explicitlyFree;
    
    // Debug logging
    print('🔍 isBudgetModel(${model['id']}): units=$units, explicitlyFree=$explicitlyFree, isBudget=$isBudget');
    print('   requestEstimate: $estimate');
    print('   pricing: $pricing');
    
    return isBudget;
  }

  /// Sort models by provider priority and budget status
  static int compareModels(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aProvider = (a['provider'] ?? '').toString().toLowerCase();
    final bProvider = (b['provider'] ?? '').toString().toLowerCase();
    
    // Check if models are budget models
    final aIsBudget = isBudgetModel(a);
    final bIsBudget = isBudgetModel(b);
    
    // Budget models go to the front (first)
    if (aIsBudget && !bIsBudget) return -1;
    if (!aIsBudget && bIsBudget) return 1;
    
    // If both are budget models, sort by provider priority (big providers first)
    if (aIsBudget && bIsBudget) {
      final aPriority = getPriority(aProvider);
      final bPriority = getPriority(bProvider);
      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }
      // If same priority, sort by name
      return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
    }
    
    // For non-budget models, sort by provider priority first
    final aPriority = getPriority(aProvider);
    final bPriority = getPriority(bProvider);
    
    if (aPriority != bPriority) {
      return aPriority.compareTo(bPriority);
    }
    
    // If same provider priority, sort by name
    return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
  }

  /// Sort providers by priority
  static int compareProviders(String a, String b) {
    // Special handling for Budget section - always goes FIRST
    if (a == 'Budget' && b != 'Budget') return -1;
    if (a != 'Budget' && b == 'Budget') return 1;
    if (a == 'Budget' && b == 'Budget') return 0;
    
    // Get provider priority
    final aPriority = getPriority(a);
    final bPriority = getPriority(b);
    
    // First sort by priority
    if (aPriority != bPriority) {
      return aPriority.compareTo(bPriority);
    }
    
    // If same priority, sort alphabetically
    return a.compareTo(b);
  }
}


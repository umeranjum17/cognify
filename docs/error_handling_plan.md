# Error Handling Plan: Type Safety & Model Switch Recommendations

## Overview
This document outlines the comprehensive plan to fix type casting errors and implement user-friendly error handling with model switch recommendations in the Cognify Flutter app.

## Current Issues
1. **Runtime Type Errors**: `type '_Map<dynamic, dynamic>' is not a subtype of type 'Map<String, dynamic>?'`
2. **429 Rate Limit Errors**: Users get cryptic error messages instead of helpful guidance
3. **Unsafe Type Casting**: Throughout agent system and UI components

## Solution Architecture

### 1. JSON Normalization Utilities ✅ COMPLETED
- **File**: `lib/utils/json_utils.dart`
- **Functions**: `deepStringKeyMap()`, `deepNormalize()`
- **Purpose**: Convert dynamic maps to string-keyed maps safely

### 2. Model Switch Recommendation Modal Widget
- **File**: `lib/widgets/model_switch_recommendation_modal.dart`
- **Purpose**: Show user-friendly error modal with model suggestions

#### Modal Features:
```dart
class ModelSwitchRecommendationModal extends StatelessWidget {
  final String errorType;           // 'rate_limit', 'quota_exceeded', etc.
  final String currentModel;        // Currently selected model
  final List<String> suggestedModels; // Recommended alternatives
  final String errorMessage;        // User-friendly error description
  final Function(String) onModelSelected; // Callback for model selection
  final VoidCallback onDismiss;     // Callback for modal dismissal
}
```

#### Modal Design:
- **Header**: Warning icon + "Model Issue Detected"
- **Error Description**: User-friendly explanation of the problem
- **Current Model Display**: Show which model caused the issue
- **Suggested Models Section**: 
  - List of 2-3 recommended alternatives
  - Each with provider icon, name, and "Switch" button
  - Free/Paid indicators
  - Model capabilities (images, files, context length)
- **Actions**: "Try Again" and "Cancel" buttons
- **Styling**: Consistent with existing app theme

### 3. Enhanced Error Classification in AgentSystem
- **File**: `lib/services/agents/agent_system.dart`
- **Method**: `_classifyError()` (already exists, needs enhancement)

#### Current Classification:
```dart
Map<String, dynamic> _classifyError(dynamic error) {
  final errorString = error.toString().toLowerCase();
  
  if (errorString.contains('429') || errorString.contains('rate limit')) {
    return {
      'type': 'rate_limit',
      'category': 'user_actionable',
      'message': 'Rate limit exceeded. Please try switching to a different model.',
    };
  }
  // ... other classifications
}
```

#### Enhancement Required:
```dart
Map<String, dynamic> _classifyError(dynamic error, {String? currentModel}) {
  final errorString = error.toString().toLowerCase();
  
  if (errorString.contains('429') || errorString.contains('rate_limit')) {
    final suggestedModels = _getSuggestedModelsForRateLimit(currentModel);
    return {
      'type': 'rate_limit',
      'category': 'user_actionable',
      'message': 'Rate limit exceeded. Try switching to a different model.',
      'suggestedModels': suggestedModels,
      'showModal': true,
    };
  }
  
  if (errorString.contains('quota') || errorString.contains('insufficient')) {
    final suggestedModels = _getSuggestedModelsForQuota(currentModel);
    return {
      'type': 'quota_exceeded',
      'category': 'user_actionable',
      'message': 'Usage quota exceeded. Switch to a free model or upgrade.',
      'suggestedModels': suggestedModels,
      'showModal': true,
    };
  }
  
  // Add more error types...
}

List<String> _getSuggestedModelsForRateLimit(String? currentModel) {
  // Logic to suggest alternative models based on current model
  if (currentModel?.contains('gpt-4') == true) {
    return [
      'google/gemini-2.0-flash-exp:free',
      'deepseek/deepseek-r1:free',
      'mistralai/mistral-7b-instruct:free',
    ];
  }
  
  if (currentModel?.contains('gemini') == true) {
    return [
      'deepseek/deepseek-r1:free',
      'mistralai/mistral-7b-instruct:free',
      'anthropic/claude-3-haiku:beta',
    ];
  }
  
  // Default fallback suggestions
  return [
    'google/gemini-2.0-flash-exp:free',
    'deepseek/deepseek-chat:free',
    'mistralai/mistral-7b-instruct:free',
  ];
}
```

### 4. Error Event Handling in EditorScreen
- **File**: `lib/screens/editor_screen.dart`
- **Location**: Around line 2991 in the stream error handling

#### Current Error Handling:
```dart
case StreamEventType.error:
  // Stop vibration on error
  try {
    stopVibration();
  } catch (e) {
    // Handle error
  }
  throw Exception(event.error ?? 'Unknown streaming error');
```

#### Enhanced Error Handling:
```dart
case StreamEventType.error:
  // Stop vibration on error
  try {
    stopVibration();
  } catch (e) {
    // Handle vibration error silently
  }
  
  // Classify the error to determine if modal should be shown
  final errorClassification = _classifyStreamError(event.error, _getModelForCurrentMode());
  
  if (errorClassification['showModal'] == true) {
    _showModelSwitchModal(errorClassification);
  } else {
    // Show standard error snackbar
    throw Exception(event.error ?? 'Unknown streaming error');
  }
  break;
```

#### New Methods to Add:
```dart
Map<String, dynamic> _classifyStreamError(String? error, String currentModel) {
  if (error == null) return {'showModal': false};
  
  final errorLower = error.toLowerCase();
  
  if (errorLower.contains('429') || errorLower.contains('rate limit')) {
    return {
      'type': 'rate_limit',
      'showModal': true,
      'title': 'Rate Limit Reached',
      'message': 'The current model has reached its rate limit. Try switching to a different model to continue.',
      'suggestedModels': _getSuggestedModelsForError('rate_limit', currentModel),
    };
  }
  
  if (errorLower.contains('quota') || errorLower.contains('insufficient')) {
    return {
      'type': 'quota_exceeded',
      'showModal': true,
      'title': 'Usage Quota Exceeded',
      'message': 'You\'ve reached the usage limit for this model. Switch to a free model or upgrade your plan.',
      'suggestedModels': _getSuggestedModelsForError('quota', currentModel),
    };
  }
  
  return {'showModal': false};
}

void _showModelSwitchModal(Map<String, dynamic> errorClassification) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => ModelSwitchRecommendationModal(
      errorType: errorClassification['type'],
      title: errorClassification['title'],
      message: errorClassification['message'],
      currentModel: _getModelForCurrentMode(),
      suggestedModels: errorClassification['suggestedModels'] ?? [],
      onModelSelected: (modelId) {
        Navigator.of(context).pop();
        _switchToModel(modelId);
        _retryLastMessage();
      },
      onDismiss: () {
        Navigator.of(context).pop();
      },
      onTryAgain: () {
        Navigator.of(context).pop();
        _retryLastMessage();
      },
    ),
  );
}

List<String> _getSuggestedModelsForError(String errorType, String currentModel) {
  // Use ModelRegistry to get intelligent suggestions
  switch (errorType) {
    case 'rate_limit':
      return ModelRegistry.getFreeModels().take(3).toList();
    case 'quota':
      return ModelRegistry.getFreeModels().take(3).toList();
    default:
      return ModelRegistry.getAllModels().take(3).toList();
  }
}

void _switchToModel(String modelId) {
  setState(() {
    _selectedModel = modelId;
  });
  
  // Update mode config provider
  final provider = Provider.of<ModeConfigProvider>(context, listen: false);
  final currentConfig = provider.getConfigForMode(_currentMode);
  if (currentConfig != null) {
    provider.updateConfig(_currentMode, currentConfig.copyWith(model: modelId));
  }
  
  // Update LLM service
  LLMService().setCurrentModel(modelId);
  
  // Check new model capabilities
  _checkModelCapabilities();
  
  // Show success message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Switched to ${ModelRegistry.formatModelName(modelId)}'),
      backgroundColor: Theme.of(context).colorScheme.primary,
    ),
  );
}

void _retryLastMessage() {
  if (_messages.isNotEmpty) {
    final lastUserMessage = _messages.lastWhere(
      (msg) => msg.type == 'user',
      orElse: () => _messages.last,
    );
    _retryUserMessage(lastUserMessage);
  }
}
```

### 5. Type Safety Fixes

#### A. ExecutorEngine.executeTool()
- **File**: `lib/services/agents/executor_engine.dart`
- **Line**: Around 83
- **Fix**: Apply JSON normalization before creating ToolResult

```dart
// Before (unsafe):
final Map<String, dynamic> toolResult = result;

// After (safe):
final Map<String, dynamic> toolResult = JsonUtils.deepStringKeyMap(result);
```

#### B. PlannerAgent.createExecutionPlan()
- **File**: `lib/services/agents/planner_agent.dart`
- **Fix**: Normalize plan JSON and ToolSpec inputs

```dart
// Normalize plan JSON
final normalizedPlan = JsonUtils.deepStringKeyMap(planData);

// Normalize ToolSpec inputs
for (final tool in tools) {
  if (tool.input != null) {
    tool.input = JsonUtils.deepStringKeyMap(tool.input);
  }
}
```

#### C. AgentSystem._convertToolResultsToSources()
- **File**: `lib/services/agents/agent_system.dart`
- **Fix**: Normalize maps before type casting

```dart
// Normalize before casting
final normalizedSources = JsonUtils.deepNormalize(toolResults['sources']);
if (normalizedSources is List) {
  for (final sourceData in normalizedSources) {
    if (sourceData is Map) {
      final normalizedSourceMap = JsonUtils.deepStringKeyMap(sourceData);
      // Safe to use normalizedSourceMap now
    }
  }
}
```

#### D. WriterAgent result.output handling
- **File**: `lib/services/agents/writer_agent.dart`
- **Fix**: Normalize output before reading

```dart
// Before:
final output = result.output as Map<String, dynamic>?;

// After:
final output = result.output != null 
    ? JsonUtils.deepStringKeyMap(result.output) 
    : null;
```

#### E. EditorScreen event.metadata handling
- **File**: `lib/screens/editor_screen.dart`
- **Lines**: Around 820, 910, etc.
- **Fix**: Normalize metadata before accessing

```dart
// Before:
_currentPhase = event.metadata?['phase'];
final costBreakdown = event.metadata?['costBreakdown'] as Map<String, dynamic>?;

// After:
final normalizedMetadata = event.metadata != null 
    ? JsonUtils.deepStringKeyMap(event.metadata!) 
    : null;
_currentPhase = normalizedMetadata?['phase'];
final costBreakdown = normalizedMetadata?['costBreakdown'] as Map<String, dynamic>?;
```

### 6. Testing Strategy

#### Test Cases:
1. **Regular Chat Flow**: Verify no type cast errors during normal operation
2. **DeepSearch Flow**: Test with complex tool results and metadata
3. **Source Grounded Chat**: Test with file attachments and source data
4. **Rate Limit Simulation**: Trigger 429 errors and verify modal appears
5. **Model Switch Flow**: Test model switching from modal works correctly
6. **Error Recovery**: Verify retry functionality after model switch

#### Testing Approach:
```dart
// Unit tests for JSON normalization
test('deepStringKeyMap handles nested dynamic maps', () {
  final input = <dynamic, dynamic>{
    'key1': 'value1',
    123: 'numeric_key',
    'nested': <dynamic, dynamic>{
      'inner': 'value',
      456: 'another_numeric'
    }
  };
  
  final result = JsonUtils.deepStringKeyMap(input);
  expect(result['key1'], equals('value1'));
  expect(result['123'], equals('numeric_key'));
  expect(result['nested']['inner'], equals('value'));
  expect(result['nested']['456'], equals('another_numeric'));
});

// Integration tests for error handling
testWidgets('rate limit error shows model switch modal', (tester) async {
  // Simulate rate limit error
  // Verify modal appears
  // Test model switching
  // Verify retry functionality
});
```

## Implementation Priority

### Phase 1: Type Safety (Critical)
1. ✅ JSON normalization utilities
2. Apply normalization in ExecutorEngine
3. Apply normalization in PlannerAgent
4. Fix AgentSystem unsafe casts
5. Fix WriterAgent unsafe casts
6. Fix EditorScreen metadata handling

### Phase 2: Error Handling (High)
1. Create ModelSwitchRecommendationModal widget
2. Enhance AgentSystem error classification
3. Update EditorScreen error handling
4. Add model switching logic
5. Add retry functionality

### Phase 3: Testing & Polish (Medium)
1. Comprehensive testing of all flows
2. Error message refinement
3. UI/UX improvements
4. Performance optimization

## Expected Outcomes

### Before Fix:
- Runtime crashes with type cast errors
- Cryptic "Error: Exception" messages for users
- No guidance on how to resolve rate limit issues
- Poor user experience during API failures

### After Fix:
- No more type cast runtime errors
- User-friendly error dialogs with clear explanations
- Intelligent model suggestions based on error type
- Quick model switching with one-click retry
- Graceful error recovery and improved reliability

## Files to Modify

### New Files:
- `lib/widgets/model_switch_recommendation_modal.dart`

### Modified Files:
- ✅ `lib/utils/json_utils.dart` (completed)
- `lib/services/agents/executor_engine.dart`
- `lib/services/agents/planner_agent.dart`
- `lib/services/agents/agent_system.dart`
- `lib/services/agents/writer_agent.dart`
- `lib/screens/editor_screen.dart`

### Test Files:
- `test/utils/json_utils_test.dart`
- `test/widgets/model_switch_recommendation_modal_test.dart`
- `test/integration/error_handling_test.dart`

This plan ensures both technical reliability (fixing type cast errors) and excellent user experience (helpful error guidance) for the Cognify Flutter application.

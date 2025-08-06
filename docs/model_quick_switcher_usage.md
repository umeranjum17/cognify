# Model Quick Switcher - Usage Guide

## Overview

The Model Quick Switcher is a compact two-pane bottom sheet that allows users to quickly switch between AI models without leaving the chat interface. It provides a fast, provider-grouped model switcher that respects the current ChatMode and only shows models valid for the active mode.

## Features

- **Two-pane layout**: Left rail shows provider categories, right panel shows models for the selected provider
- **Mode awareness**: Only shows models applicable to the current ChatMode (chat vs deepSearch)
- **Provider normalization**: Groups models by normalized provider names (Gemini, OpenAI, Claude, etc.)
- **Free model detection**: Special "Free" category for all free models across providers
- **Search functionality**: Filter models within the selected provider
- **Capability badges**: Shows image (👁), file (🧩), and context length indicators
- **Price display**: Shows pricing information for each model
- **Immediate switching**: Taps immediately switch the model and dismiss the sheet

## Usage

### Basic Usage

```dart
import '../widgets/model_quick_switcher_modal.dart';

// Show the quick switcher
showModelQuickSwitcher(
  context: context,
  mode: ChatMode.chat, // or ChatMode.deepSearch
  selectedModel: 'gpt-4',
  onModelSelected: (modelId) {
    // Handle model selection
    setState(() {
      _selectedModel = modelId;
    });
    // Update LLM service
    LLMService().setCurrentModel(modelId);
  },
);
```

### Integration in Editor Screen

The Model Quick Switcher is integrated into the Editor Screen with a model chip above the input field:

```dart
// Model chip in editor screen
Widget _buildModelChip(ThemeData theme) {
  return GestureDetector(
    onTap: () => _showModelQuickSwitcher(),
    child: Container(
      // Model chip UI
    ),
  );
}

void _showModelQuickSwitcher() {
  showModelQuickSwitcher(
    context: context,
    mode: _currentMode,
    selectedModel: _selectedModel,
    onModelSelected: (modelId) {
      setState(() {
        _selectedModel = modelId;
      });
      _checkModelCapabilities();
    },
  );
}
```

## Provider Normalization

The quick switcher normalizes provider names for consistent grouping:

- `google` → `Gemini`
- `anthropic` → `Claude`
- `x-ai`, `xai` → `Grok`
- `meta` → `Llama`
- `mistral`, `mistralai` → `Mistral`
- `deepseek` → `DeepSeek`
- `openai` → `OpenAI`
- `qwen` → `Qwen`
- Others → TitleCase of original

## Free Model Detection

Models are considered free if:
1. `model["isFree"] == true`
2. `model["id"]` endsWith `":free"`
3. `model["id"]` is in the known free models set
4. Both input and output pricing are zero

## Capability Badges

The quick switcher shows capability badges for each model:
- **Text**: Always available (implicit)
- **Images** (👁): If modalities contains "image"
- **Files** (🧩): If modalities contains "file"
- **Context Length**: Shows in k tokens if available

## Price Display

Prices are displayed as:
- `Free`: For models with zero pricing
- `$X.XX/1M`: For models with single pricing
- `$X.XX/$Y.YY`: For models with different input/output pricing
- `Paid`: For models with unavailable pricing (-1 values)

## UI Layout

- **Height**: 85% of screen height
- **Left rail**: 120px width with provider icons and counts
- **Right panel**: Search field at top, scrollable model list
- **Model rows**: 44-56px height for touch targets
- **Search**: Filters within selected provider only

## Error Handling

- **Loading state**: Linear progress indicator with "Loading models..." text
- **Error state**: Error icon with retry button
- **Empty state**: "No models found" message when search yields no results

## Performance

- Uses `ListView.builder` for virtualization
- 60 FPS scrolling performance
- Debounced search (300ms)
- Cached model data from ModelService

## Accessibility

- Semantic labels for icons and rows
- Touch targets sized appropriately (44-56px)
- High contrast colors for light/dark themes
- Screen reader friendly navigation

## Future Enhancements

- Pin favorites per mode at the top
- Recent models section per mode
- Per-mode cost estimates
- Keyboard navigation and shortcuts on desktop
- Persist last selected provider across app launches 
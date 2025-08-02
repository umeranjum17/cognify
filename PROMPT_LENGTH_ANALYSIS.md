# Prompt Length Analysis Feature

## Overview

The Writer Agent now includes comprehensive prompt length analysis that helps you understand what's consuming the most tokens in your prompts. This feature provides detailed breakdowns in a fancy table format with visual indicators.

## Features

### 📊 Detailed Breakdown Table
- **Section-by-section analysis**: Breaks down each part of the prompt
- **Character count**: Shows exact character count for each section
- **Token estimation**: Estimates tokens (characters ÷ 4)
- **Percentage**: Shows what percentage of the total each section consumes
- **Visual bars**: ASCII bar charts to quickly identify the biggest consumers

### 🔥 Top Consumers Highlight
- **Ranked list**: Shows the top 3 sections consuming the most tokens
- **Medals**: Uses emojis (🥇🥈🥉) to highlight the biggest consumers
- **Percentages**: Shows exact percentage each top consumer represents

### 💡 Token Estimation & Accuracy
- **Estimated vs Actual**: Compares estimated tokens with actual API usage
- **Accuracy tracking**: Shows how accurate our estimation is
- **Improvement suggestions**: Provides tips when estimation accuracy is poor

### 💭 Optimization Recommendations
- **High usage warnings**: Alerts when token usage is excessive (>8000)
- **Moderate usage monitoring**: Suggests monitoring for optimization opportunities
- **Specific recommendations**: Provides actionable advice for reducing token usage

## Example Output

```
================================================================================
📊 PROMPT LENGTH BREAKDOWN ANALYSIS
================================================================================
Section                    Chars    Tokens   %      Bar
--------------------------------------------------------------------------------
Sources Section            15420    3855     45.2%   ████████████████████████████░░
Response Guidelines        12340    3085     36.2%   ████████████████████████░░░░░░
Tool Summary               4560     1140     10.7%   ██████████░░░░░░░░░░░░░░░░░░░░
Conversation Context       2340     585      5.5%    █████░░░░░░░░░░░░░░░░░░░░░░░░░
Reasoning Section          1200     300      2.4%    ██░░░░░░░░░░░░░░░░░░░░░░░░░░░░
--------------------------------------------------------------------------------
TOTAL                     34060    8515     100.0%  ██████████████████████████████
================================================================================

🔥 TOP PROMPT CONSUMERS:
🥇 Sources Section: 15420 chars (45.2%)
🥈 Response Guidelines: 12340 chars (36.2%)
🥉 Tool Summary: 4560 chars (10.7%)

💡 TOKEN ESTIMATION:
   📝 Estimated tokens: 8515
   📊 Actual tokens (if available): Will be logged after API call

💭 OPTIMIZATION RECOMMENDATIONS:
   ⚠️  High token usage detected! Consider:
      • Reducing conversation history length
      • Limiting number of sources processed
      • Shortening tool summaries
================================================================================
```

## How It Works

### Automatic Analysis
The analysis runs automatically whenever you call `createWritingPrompt()`. No additional setup required.

### Sections Analyzed
1. **Personality Instruction** - AI personality settings
2. **User Query** - The original user question
3. **Mode & Settings** - Mode, incognito, personality settings
4. **Language Instruction** - Language-specific instructions
5. **Conversation Context** - Previous conversation history
6. **Tool Summary** - Results from executed tools
7. **Sources Section** - Extracted and scraped content
8. **Images Section** - Available images for inclusion
9. **Reasoning Section** - DeepSearch mode reasoning instructions
10. **Response Guidelines** - Detailed response formatting rules

### Token Estimation
- **Formula**: Characters ÷ 4 (rough approximation)
- **Accuracy tracking**: Compares with actual API token usage
- **Improvement suggestions**: When accuracy is poor

## Usage

The analysis is automatically included in both streaming and non-streaming responses:

```dart
// Non-streaming
final response = await writerAgent.writeResponse(
  originalQuery: "What is Flutter?",
  toolResults: toolResults,
  mode: "chat",
  // ... other parameters
);

// Streaming
final stream = writerAgent.writeResponseStream(
  originalQuery: "What is Flutter?",
  toolResults: toolResults,
  mode: "chat",
  // ... other parameters
);
```

## Benefits

1. **Cost Optimization**: Identify what's consuming the most tokens
2. **Performance Monitoring**: Track token usage patterns
3. **Debugging**: Understand prompt composition issues
4. **Optimization**: Get specific recommendations for reducing costs
5. **Transparency**: See exactly what goes into each prompt

## Tips for Optimization

### High Token Usage (>8000 tokens)
- Reduce conversation history length
- Limit number of sources processed
- Shorten tool summaries
- Use chat mode instead of deepsearch when possible

### Moderate Token Usage (4000-8000 tokens)
- Monitor for optimization opportunities
- Consider if all sections are necessary
- Review source content length

### Low Token Usage (<4000 tokens)
- Generally good performance
- Consider if more context would improve responses 
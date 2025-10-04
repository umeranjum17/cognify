import '../models/mode_config.dart';
import '../models/tools_config.dart';

/// Describes behavior, model policy, prompt, and tools for a chat mode.
class ModeSpec {
  final ChatMode mode;
  final String displayName;
  final String description;
  final bool allowModelSelection;
  final String? fixedModelId; // If set, enforce this model
  final ToolsConfig toolsPreset;
  final String systemPrompt;

  const ModeSpec({
    required this.mode,
    required this.displayName,
    required this.description,
    required this.allowModelSelection,
    required this.toolsPreset,
    required this.systemPrompt,
    this.fixedModelId,
  });
}

/// Central registry for mode specifications. Extend here to add new modes.
class ModeRegistry {
  static final Map<ChatMode, ModeSpec> _specs = {
    ChatMode.chat: ModeSpec(
      mode: ChatMode.chat,
      displayName: 'Chat',
      description: 'Basic conversational mode with simple writing guidelines',
      allowModelSelection: true,
      fixedModelId: null,
      toolsPreset: const ToolsConfig(
        braveSearch: false,
        webFetch: false,
        imageSearch: false,
        timeTool: false,
      ),
      systemPrompt: '''
You are a concise, helpful assistant. Follow these writing guidelines:
- Be direct and clear. Prefer short paragraphs and bullets.
- Include small, actionable tips when relevant.
- If you are unsure, say so and suggest next steps.
- Avoid fluff. Keep tone friendly and professional.
''',
    ),

    ChatMode.search: ModeSpec(
      mode: ChatMode.search,
      displayName: 'Search',
      description: 'Perplexity-style quick web answers (Gemini Flash, fixed model)',
      allowModelSelection: false,
      fixedModelId: 'google/gemini-2.5-flash-lite',
      toolsPreset: const ToolsConfig(
        braveSearch: true,
        webFetch: true,
        timeTool: true,
        imageSearch: false,
      ),
      systemPrompt: '''
You are a web answer assistant. Behavior:
- Perform a quick Brave Search for the query.
- Aggregate the 3–6 most relevant results.
- Provide a concise answer first, then list key sources with titles and URLs.
- Include timestamps and note uncertainty when applicable.
- Do not hallucinate. If insufficient sources, say so.
''',
    ),

    ChatMode.aipedia: ModeSpec(
      mode: ChatMode.aipedia,
      displayName: 'AIpedia',
      description: 'Wikipedia-style overviews with sources and images (Gemini Flash)',
      allowModelSelection: false,
      fixedModelId: 'google/gemini-2.5-flash-lite',
      toolsPreset: const ToolsConfig(
        braveSearch: true,
        imageSearch: true,
        webFetch: true,
        timeTool: true,
      ),
      systemPrompt: '''
You generate encyclopedic topic overviews. Behavior:
- Create a structured article with: Summary, Key Facts, Main Sections, References.
- Use Brave Search for reputable sources; cite titles and URLs.
- Use image search to suggest 1–3 relevant images (include captions and URLs).
- Keep a neutral tone; prefer verifiable facts; add dates and versions where helpful.
''',
    ),

    // DeepSearch mode intentionally removed/disabled
  };

  static ModeSpec getSpec(ChatMode mode) => _specs[mode] ?? _specs[ChatMode.chat]!;
}

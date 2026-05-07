/// Registry of available AI models that the user can download and run on-device.
///
/// Each [AiModelInfo] entry describes a single quantized GGUF model hosted on
/// Hugging Face that the [AiRepository] knows how to fetch, verify, and load.
class AiModelInfo {
  const AiModelInfo({
    required this.id,
    required this.displayName,
    required this.family,
    required this.description,
    required this.downloadUrl,
    required this.sizeLabel,
    required this.templateType,
    this.parameterCount = '',
    this.contextSize = 2048,
  });

  /// Unique identifier used for folder naming and persistent selection.
  final String id;

  /// Human-readable name shown in the model picker UI.
  final String displayName;

  /// Model family (e.g. "Qwen", "Gemma", "Phi", "Llama", "Mistral").
  final String family;

  /// Short description (parameter count, quantization, use case).
  final String description;

  /// Direct GGUF download URL from Hugging Face.
  final String downloadUrl;

  /// Human-readable download size label (e.g. "490 MB", "1.2 GB").
  final String sizeLabel;

  /// Which prompt template to use: 'chatml' for Qwen, 'llama3', 'gemma', etc.
  final String templateType;

  /// Human-readable parameter count (e.g. "0.6B", "3B").
  final String parameterCount;

  /// Maximum context window size for this model.
  final int contextSize;

  /// Derived file name from the download URL.
  String get fileName => Uri.parse(downloadUrl).pathSegments.last;
}

/// All available models. The first entry is the default / recommended model.
class AiModelRegistry {
  AiModelRegistry._();

  /// Unique model family names used to group models in the UI.
  static List<String> get families {
    final seen = <String>{};
    final result = <String>[];
    for (final m in models) {
      if (seen.add(m.family)) result.add(m.family);
    }
    return result;
  }

  static const List<AiModelInfo> models = [
    // ═══════════════════════════════════════════════════════════
    // ── Qwen (Alibaba) ────────────────────────────────────────
    // ═══════════════════════════════════════════════════════════

    // ── Default / Base model ──
    AiModelInfo(
      id: 'qwen3-0.6b-q4',
      displayName: 'Qwen 3 0.6B',
      family: 'Qwen',
      parameterCount: '0.6B',
      description: 'Ultra-light · Fastest inference · Great for basic tasks',
      downloadUrl:
          'https://huggingface.co/unsloth/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_K_M.gguf',
      sizeLabel: '490 MB',
      templateType: 'chatml',
      contextSize: 4096,
    ),

    AiModelInfo(
      id: 'qwen3-1.7b-q4',
      displayName: 'Qwen 3 1.7B',
      family: 'Qwen',
      parameterCount: '1.7B',
      description: 'Balanced speed & quality · Good reasoning',
      downloadUrl:
          'https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q4_K_M.gguf',
      sizeLabel: '1.1 GB',
      templateType: 'chatml',
      contextSize: 4096,
    ),

    AiModelInfo(
      id: 'qwen3-4b-q4',
      displayName: 'Qwen 3 4B',
      family: 'Qwen',
      parameterCount: '4B',
      description: 'Strong reasoning · Best Qwen quality',
      downloadUrl:
          'https://huggingface.co/unsloth/Qwen3-4B-GGUF/resolve/main/Qwen3-4B-Q4_K_M.gguf',
      sizeLabel: '2.6 GB',
      templateType: 'chatml',
      contextSize: 4096,
    ),

    AiModelInfo(
      id: 'qwen2.5-0.5b-instruct-q4',
      displayName: 'Qwen 2.5 0.5B',
      family: 'Qwen',
      parameterCount: '0.5B',
      description: 'Tiny & snappy · Instruction-tuned',
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
      sizeLabel: '400 MB',
      templateType: 'chatml',
      contextSize: 2048,
    ),

    AiModelInfo(
      id: 'qwen2.5-1.5b-instruct-q4',
      displayName: 'Qwen 2.5 1.5B',
      family: 'Qwen',
      parameterCount: '1.5B',
      description: 'Better reasoning · Instruction-tuned',
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
      sizeLabel: '1.0 GB',
      templateType: 'chatml',
      contextSize: 4096,
    ),

    AiModelInfo(
      id: 'qwen2.5-3b-instruct-q4',
      displayName: 'Qwen 2.5 3B',
      family: 'Qwen',
      parameterCount: '3B',
      description: 'High quality answers · Instruction-tuned',
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf',
      sizeLabel: '1.9 GB',
      templateType: 'chatml',
      contextSize: 4096,
    ),

    // ═══════════════════════════════════════════════════════════
    // ── Google Gemma ──────────────────────────────────────────
    // ═══════════════════════════════════════════════════════════

    AiModelInfo(
      id: 'gemma-3-1b-it-q4',
      displayName: 'Gemma 3 1B',
      family: 'Gemma',
      parameterCount: '1B',
      description: 'Google\'s latest tiny model · Fast & capable',
      downloadUrl:
          'https://huggingface.co/unsloth/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf',
      sizeLabel: '750 MB',
      templateType: 'gemma',
      contextSize: 4096,
    ),

    AiModelInfo(
      id: 'gemma-3-4b-it-q4',
      displayName: 'Gemma 3 4B',
      family: 'Gemma',
      parameterCount: '4B',
      description: 'Google\'s mid-range · Excellent instruction following',
      downloadUrl:
          'https://huggingface.co/unsloth/gemma-3-4b-it-GGUF/resolve/main/gemma-3-4b-it-Q4_K_M.gguf',
      sizeLabel: '2.5 GB',
      templateType: 'gemma',
      contextSize: 4096,
    ),

    AiModelInfo(
      id: 'gemma-2-2b-it-q4',
      displayName: 'Gemma 2 2B',
      family: 'Gemma',
      parameterCount: '2B',
      description: 'Previous gen · Proven instruction-tuned model',
      downloadUrl:
          'https://huggingface.co/lmstudio-ai/gemma-2b-it-GGUF/resolve/main/gemma-2b-it-q4_k_m.gguf',
      sizeLabel: '1.4 GB',
      templateType: 'gemma',
      contextSize: 4096,
    ),

    // ═══════════════════════════════════════════════════════════
    // ── Meta Llama ────────────────────────────────────────────
    // ═══════════════════════════════════════════════════════════

    AiModelInfo(
      id: 'llama-3.2-1b-instruct-q4',
      displayName: 'Llama 3.2 1B',
      family: 'Llama',
      parameterCount: '1B',
      description: 'Meta\'s compact model · Multilingual',
      downloadUrl:
          'https://huggingface.co/unsloth/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      sizeLabel: '760 MB',
      templateType: 'llama3',
      contextSize: 4096,
    ),

    AiModelInfo(
      id: 'llama-3.2-3b-instruct-q4',
      displayName: 'Llama 3.2 3B',
      family: 'Llama',
      parameterCount: '3B',
      description: 'Meta\'s best compact · Strong reasoning',
      downloadUrl:
          'https://huggingface.co/unsloth/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
      sizeLabel: '2.0 GB',
      templateType: 'llama3',
      contextSize: 4096,
    ),

    // ═══════════════════════════════════════════════════════════
    // ── Microsoft Phi ────────────────────────────────────────
    // ═══════════════════════════════════════════════════════════

    AiModelInfo(
      id: 'phi-4-mini-instruct-q4',
      displayName: 'Phi 4 Mini',
      family: 'Phi',
      parameterCount: '3.8B',
      description: 'Microsoft\'s latest · Top-tier reasoning for its size',
      downloadUrl:
          'https://huggingface.co/unsloth/Phi-4-mini-instruct-GGUF/resolve/main/Phi-4-mini-instruct-Q4_K_M.gguf',
      sizeLabel: '2.4 GB',
      templateType: 'chatml',
      contextSize: 4096,
    ),

    AiModelInfo(
      id: 'phi-3.5-mini-instruct-q4',
      displayName: 'Phi 3.5 Mini',
      family: 'Phi',
      parameterCount: '3.8B',
      description: 'Microsoft · Strong coding & math skills',
      downloadUrl:
          'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf',
      sizeLabel: '2.3 GB',
      templateType: 'chatml',
      contextSize: 4096,
    ),

    // ═══════════════════════════════════════════════════════════
    // ── Mistral ──────────────────────────────────────────────
    // ═══════════════════════════════════════════════════════════

    AiModelInfo(
      id: 'mistral-7b-instruct-v0.3-q4',
      displayName: 'Mistral 7B v0.3',
      family: 'Mistral',
      parameterCount: '7B',
      description: 'Flagship open model · Excellent generalist',
      downloadUrl:
          'https://huggingface.co/MistralAI/Mistral-7B-Instruct-v0.3/resolve/main/Mistral-7B-Instruct-v0.3-Q4_K_M.gguf',
      sizeLabel: '4.1 GB',
      templateType: 'mistral',
      contextSize: 4096,
    ),

    // ═══════════════════════════════════════════════════════════
    // ── Hugging Face SmolLM ──────────────────────────────────
    // ═══════════════════════════════════════════════════════════

    AiModelInfo(
      id: 'smollm2-360m-instruct-q8',
      displayName: 'SmolLM2 360M',
      family: 'SmolLM',
      parameterCount: '360M',
      description: 'Tiniest model · Instant responses · Very basic',
      downloadUrl:
          'https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF/resolve/main/smollm2-360m-instruct-q8_0.gguf',
      sizeLabel: '385 MB',
      templateType: 'chatml',
      contextSize: 2048,
    ),

    AiModelInfo(
      id: 'smollm2-1.7b-instruct-q4',
      displayName: 'SmolLM2 1.7B',
      family: 'SmolLM',
      parameterCount: '1.7B',
      description: 'HuggingFace\'s efficient model · Good for chat',
      downloadUrl:
          'https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF/resolve/main/smollm2-1.7b-instruct-q4_k_m.gguf',
      sizeLabel: '1.0 GB',
      templateType: 'chatml',
      contextSize: 4096,
    ),

    // ═══════════════════════════════════════════════════════════
    // ── TinyLlama ────────────────────────────────────────────
    // ═══════════════════════════════════════════════════════════

    AiModelInfo(
      id: 'tinyllama-1.1b-chat-q4',
      displayName: 'TinyLlama 1.1B',
      family: 'TinyLlama',
      parameterCount: '1.1B',
      description: 'Community favorite · Lightweight chat model',
      downloadUrl:
          'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
      sizeLabel: '670 MB',
      templateType: 'chatml',
      contextSize: 2048,
    ),

    // ═══════════════════════════════════════════════════════════
    // ── StableLM (Stability AI) ──────────────────────────────
    // ═══════════════════════════════════════════════════════════

    AiModelInfo(
      id: 'stablelm-zephyr-3b-q4',
      displayName: 'StableLM Zephyr 3B',
      family: 'StableLM',
      parameterCount: '3B',
      description: 'Stability AI · Great at following instructions',
      downloadUrl:
          'https://huggingface.co/TheBloke/stablelm-zephyr-3b-GGUF/resolve/main/stablelm-zephyr-3b.Q4_K_M.gguf',
      sizeLabel: '1.8 GB',
      templateType: 'chatml',
      contextSize: 4096,
    ),

    // ═══════════════════════════════════════════════════════════
    // ── Deepseek ─────────────────────────────────────────────
    // ═══════════════════════════════════════════════════════════

    AiModelInfo(
      id: 'deepseek-r1-distill-qwen-1.5b-q4',
      displayName: 'DeepSeek R1 1.5B',
      family: 'DeepSeek',
      parameterCount: '1.5B',
      description: 'Reasoning specialist · Distilled from R1',
      downloadUrl:
          'https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf',
      sizeLabel: '1.1 GB',
      templateType: 'chatml',
      contextSize: 4096,
    ),
  ];

  /// The default model to auto-select on first launch.
  static AiModelInfo get defaultModel => models.first;

  /// Look up a model by its ID, falling back to the default.
  static AiModelInfo findById(String id) {
    return models.firstWhere(
      (m) => m.id == id,
      orElse: () => defaultModel,
    );
  }
}

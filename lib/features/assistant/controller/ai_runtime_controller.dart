import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repository/ai_model_registry.dart';
import '../repository/ai_repository.dart';

final aiRuntimeControllerProvider =
    NotifierProvider<AiRuntimeController, AiRuntimeState>(
  AiRuntimeController.new,
);

class AiRuntimeState {
  const AiRuntimeState({
    this.initialized = false,
    this.downloading = false,
    this.modelDownloaded = false,
    this.modelLoaded = false,
    this.progress = 0,
    this.status = 'Checking local AI model...',
    this.error,
    this.selectedModelId,
    this.downloadedModels = const {},
  });

  final bool initialized;
  final bool downloading;
  final bool modelDownloaded;
  final bool modelLoaded;
  final double progress;
  final String status;
  final String? error;
  /// ID of the currently selected model.
  final String? selectedModelId;
  /// Set of all model IDs that are currently downloaded.
  final Set<String> downloadedModels;

  AiModelInfo get selectedModel =>
      AiModelRegistry.findById(selectedModelId ?? AiModelRegistry.defaultModel.id);

  AiRuntimeState copyWith({
    bool? initialized,
    bool? downloading,
    bool? modelDownloaded,
    bool? modelLoaded,
    double? progress,
    String? status,
    String? error,
    String? selectedModelId,
    Set<String>? downloadedModels,
  }) {
    return AiRuntimeState(
      initialized: initialized ?? this.initialized,
      downloading: downloading ?? this.downloading,
      modelDownloaded: modelDownloaded ?? this.modelDownloaded,
      modelLoaded: modelLoaded ?? this.modelLoaded,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      error: error,
      selectedModelId: selectedModelId ?? this.selectedModelId,
      downloadedModels: downloadedModels ?? this.downloadedModels,
    );
  }
}

class AiRuntimeController extends Notifier<AiRuntimeState> {
  @override
  AiRuntimeState build() {
    return AiRuntimeState(
      selectedModelId: AiModelRegistry.defaultModel.id,
    );
  }

  Future<void> bootstrap() async {
    state = state.copyWith(status: 'Checking local AI model...', error: null);
    try {
      final repo = ref.read(aiRepositoryProvider);
      await repo.initialize();
      await refreshDownloadedModels();
      final downloaded = await repo.isModelDownloaded();

      if (!downloaded) {
        state = state.copyWith(
          initialized: true,
          modelDownloaded: false,
          modelLoaded: false,
          status: 'Download ${repo.modelName} to enable AI answers.',
        );
        return;
      }

      state = state.copyWith(
        initialized: true,
        modelDownloaded: true,
        status: 'Loading local model...',
      );

      await repo.loadModel();
      state = state.copyWith(
        initialized: true,
        modelDownloaded: true,
        modelLoaded: true,
        progress: 1,
        status: '${repo.modelName} loaded on device.',
      );
    } catch (error) {
      state = state.copyWith(
        initialized: true,
        modelDownloaded: false,
        modelLoaded: false,
        status: 'Could not prepare local model.',
        error: error.toString(),
      );
    }
  }

  Future<void> refreshDownloadedModels() async {
    final repo = ref.read(aiRepositoryProvider);
    final downloaded = <String>{};
    for (final model in AiModelRegistry.models) {
      if (await repo.isModelDownloaded(model.id)) {
        downloaded.add(model.id);
      }
    }
    state = state.copyWith(downloadedModels: downloaded);
  }

  Future<void> initialize() async {
    state = state.copyWith(status: 'Initializing RunAnywhere...', error: null);
    try {
      final repo = ref.read(aiRepositoryProvider);
      await repo.initialize();
      state = state.copyWith(
        initialized: true,
        modelDownloaded: repo.isModelLoaded,
        modelLoaded: repo.isModelLoaded,
        status: 'RunAnywhere initialized. Download and load the local model.',
      );
    } catch (error) {
      state = state.copyWith(
        status: 'RunAnywhere initialization failed.',
        error: error.toString(),
      );
    }
  }

  /// Switch the selected model. This invalidates any loaded model state.
  Future<void> selectModel(String modelId) async {
    final repo = ref.read(aiRepositoryProvider);
    final changed = repo.selectModel(modelId);
    if (!changed) return;

    state = state.copyWith(
      selectedModelId: modelId,
      modelDownloaded: false,
      modelLoaded: false,
      progress: 0,
      status: 'Switched to ${repo.modelName}.',
      error: null,
    );

    // Refresh downloaded models and check if this model is already downloaded
    try {
      await repo.initialize();
      await refreshDownloadedModels();
      final downloaded = await repo.isModelDownloaded();
      if (downloaded) {
        state = state.copyWith(
          initialized: true,
          modelDownloaded: true,
          status: '${repo.modelName} found. Tap Load to start.',
        );
      } else {
        state = state.copyWith(
          initialized: true,
          modelDownloaded: false,
          status: 'Download ${repo.modelName} (${repo.selectedModel.sizeLabel}) to enable AI answers.',
        );
      }
    } catch (error) {
      state = state.copyWith(
        initialized: true,
        status: 'Could not check model status.',
        error: error.toString(),
      );
    }
  }

  Future<void> downloadAndLoadModel() async {
    final repo = ref.read(aiRepositoryProvider);
    state = state.copyWith(
      downloading: true,
      progress: 0,
      status: 'Downloading ${repo.modelName}...',
      error: null,
    );
    try {
      await for (final progress in repo.downloadModel()) {
        state = state.copyWith(
          initialized: true,
          downloading: progress.state != DownloadProgressState.completed,
          modelDownloaded: progress.state == DownloadProgressState.completed || state.modelDownloaded,
          progress: progress.percentage.clamp(0, 1),
          status: progress.state == DownloadProgressState.completed
              ? 'Download complete. Loading model...'
              : 'Downloading model ${(progress.percentage * 100).toStringAsFixed(0)}%',
        );
      }
      await repo.loadModel();
      await refreshDownloadedModels();
      state = state.copyWith(
        initialized: true,
        downloading: false,
        modelDownloaded: true,
        modelLoaded: true,
        progress: 1,
        status: '${repo.modelName} loaded on device.',
      );
    } catch (error) {
      state = state.copyWith(
        initialized: true,
        downloading: false,
        modelDownloaded: await repo.isModelDownloaded(),
        modelLoaded: false,
        status: 'Model setup failed.',
        error: error.toString(),
      );
    }
  }

  Future<void> loadDownloadedModel() async {
    final repo = ref.read(aiRepositoryProvider);
    state = state.copyWith(status: 'Loading local model...', error: null);
    try {
      await repo.loadModel();
      state = state.copyWith(
        initialized: true,
        modelDownloaded: true,
        modelLoaded: true,
        progress: 1,
        status: '${repo.modelName} loaded on device.',
      );
    } catch (error) {
      state = state.copyWith(
        initialized: true,
        modelDownloaded: await repo.isModelDownloaded(),
        modelLoaded: false,
        status: 'Could not load local model.',
        error: error.toString(),
      );
    }
  }
}

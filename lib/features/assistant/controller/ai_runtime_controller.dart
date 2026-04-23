import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  final bool initialized;
  final bool downloading;
  final bool modelDownloaded;
  final bool modelLoaded;
  final double progress;
  final String status;
  final String? error;

  AiRuntimeState copyWith({
    bool? initialized,
    bool? downloading,
    bool? modelDownloaded,
    bool? modelLoaded,
    double? progress,
    String? status,
    String? error,
  }) {
    return AiRuntimeState(
      initialized: initialized ?? this.initialized,
      downloading: downloading ?? this.downloading,
      modelDownloaded: modelDownloaded ?? this.modelDownloaded,
      modelLoaded: modelLoaded ?? this.modelLoaded,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      error: error,
    );
  }
}

class AiRuntimeController extends Notifier<AiRuntimeState> {
  @override
  AiRuntimeState build() {
    return const AiRuntimeState();
  }

  Future<void> bootstrap() async {
    state = state.copyWith(status: 'Checking local AI model...', error: null);
    try {
      await ref.read(aiRepositoryProvider).initialize();
      final downloaded = await ref.read(aiRepositoryProvider).isModelDownloaded();

      if (!downloaded) {
        state = state.copyWith(
          initialized: true,
          modelDownloaded: false,
          modelLoaded: false,
          status: 'Download ${AiRepository.modelName} to enable AI answers.',
        );
        return;
      }

      state = state.copyWith(
        initialized: true,
        modelDownloaded: true,
        status: 'Loading local model...',
      );

      await ref.read(aiRepositoryProvider).loadModel();
      state = state.copyWith(
        initialized: true,
        modelDownloaded: true,
        modelLoaded: true,
        progress: 1,
        status: '${AiRepository.modelName} loaded on device.',
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

  Future<void> initialize() async {
    state = state.copyWith(status: 'Initializing RunAnywhere...', error: null);
    try {
      await ref.read(aiRepositoryProvider).initialize();
      state = state.copyWith(
        initialized: true,
        modelDownloaded: ref.read(aiRepositoryProvider).isModelLoaded,
        modelLoaded: ref.read(aiRepositoryProvider).isModelLoaded,
        status: 'RunAnywhere initialized. Download and load the local model.',
      );
    } catch (error) {
      state = state.copyWith(
        status: 'RunAnywhere initialization failed.',
        error: error.toString(),
      );
    }
  }

  Future<void> downloadAndLoadModel() async {
    state = state.copyWith(
      downloading: true,
      progress: 0,
      status: 'Downloading ${AiRepository.modelName}...',
      error: null,
    );
    try {
      await for (final progress in ref.read(aiRepositoryProvider).downloadModel()) {
        state = state.copyWith(
          initialized: true,
          downloading: !progress.state.isCompleted,
          progress: progress.percentage.clamp(0, 1),
          status: progress.state.isCompleted
              ? 'Download complete. Loading model...'
              : 'Downloading model ${(progress.percentage * 100).toStringAsFixed(0)}%',
        );
      }
      await ref.read(aiRepositoryProvider).loadModel();
      state = state.copyWith(
        initialized: true,
        downloading: false,
        modelDownloaded: true,
        modelLoaded: true,
        progress: 1,
        status: '${AiRepository.modelName} loaded on device.',
      );
    } catch (error) {
      state = state.copyWith(
        initialized: true,
        downloading: false,
        modelDownloaded: false,
        modelLoaded: false,
        status: 'Model setup failed.',
        error: error.toString(),
      );
    }
  }

  Future<void> loadDownloadedModel() async {
    state = state.copyWith(status: 'Loading local model...', error: null);
    try {
      await ref.read(aiRepositoryProvider).loadModel();
      state = state.copyWith(
        initialized: true,
        modelDownloaded: true,
        modelLoaded: true,
        progress: 1,
        status: '${AiRepository.modelName} loaded on device.',
      );
    } catch (error) {
      state = state.copyWith(
        initialized: true,
        modelDownloaded: false,
        modelLoaded: false,
        status: 'Could not load local model.',
        error: error.toString(),
      );
    }
  }
}

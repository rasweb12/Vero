import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/local_database_provider.dart';
import '../../../shared/utils/result.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/training_repository.dart';
import '../domain/exercise_library.dart';
import '../domain/training_models.dart';
import 'exercise_providers.dart';

final trainingControllerProvider =
    StateNotifierProvider<TrainingController, AsyncValue<TrainingData>>((ref) {
      final owner = ref.watch(
        authControllerProvider.select((session) => session.account?.id),
      );
      return TrainingController(
        TrainingRepository(
          ref.watch(localDatabaseProvider),
          owner ?? 'signed-out',
        ),
        loadCatalog: () => ref.read(exerciseCatalogProvider.future),
      );
    });

class TrainingController extends StateNotifier<AsyncValue<TrainingData>> {
  TrainingController(this.repository, {this.loadCatalog})
    : super(const AsyncLoading()) {
    ready = reload();
  }
  final TrainingRepository repository;
  final Future<List<Exercicio>> Function()? loadCatalog;
  late final Future<void> ready;
  Future<void> _pending = Future.value();

  Future<void> reload() async {
    final result = await repository.load();
    if (!mounted) return;
    state = result.fold(
      onFailure: (failure) => AsyncError(failure.message, StackTrace.current),
      onSuccess: AsyncData.new,
    );
  }

  // Serialize rapid taps and commit state only after the encrypted write succeeds.
  Future<Result<void>> _change(
    FutureOr<Result<TrainingData>> Function(TrainingData) update,
  ) {
    final operation = _pending.then((_) async {
      await ready;
      if (!mounted) {
        return const Failure<void>(AppFailure(message: 'Sessao encerrada.'));
      }
      final current = state.asData?.value;
      if (current == null) {
        return const Failure<void>(
          AppFailure(message: 'Aguarde o carregamento dos treinos.'),
        );
      }
      final proposed = await update(current);
      if (proposed case Failure<TrainingData>(:final failure)) {
        return Failure<void>(failure);
      }
      final updated = (proposed as Success<TrainingData>).value;
      final result = await repository.save(updated);
      if (result.isSuccess && mounted) state = AsyncData(updated);
      return result;
    });
    _pending = operation.then((_) {});
    return operation;
  }

  Future<Result<void>> saveRoutine(Treino routine) => _change((data) async {
    final List<Exercicio> catalog;
    try {
      catalog = await loadCatalog?.call() ?? exerciseLibrary;
    } on Object {
      return const Failure(
        AppFailure(
          message: 'Nao foi possivel abrir a biblioteca. Tente novamente.',
        ),
      );
    }
    if (routine.name.trim().isEmpty ||
        routine.name.length > 80 ||
        routine.exercises.isEmpty ||
        routine.restSeconds < 0 ||
        routine.restSeconds > 600 ||
        routine.exercises
                .map((exercise) => exercise.exerciseId)
                .toSet()
                .length !=
            routine.exercises.length ||
        routine.exercises.any(
          (exercise) =>
              ![
                ...catalog,
                ...data.customExercises,
              ].any((item) => item.id == exercise.exerciseId) ||
              exercise.sets.isEmpty ||
              exercise.sets.length > 20 ||
              exercise.sets.any(
                (set) =>
                    set.reps < 1 ||
                    set.reps > 999 ||
                    !set.weight.isFinite ||
                    set.weight < 0 ||
                    set.weight > 1000,
              ),
        )) {
      return const Failure(
        AppFailure(
          message: 'Confira o nome, os exercicios e as series do treino.',
        ),
      );
    }
    final routines = [...data.routines];
    final index = routines.indexWhere((value) => value.id == routine.id);
    if (index < 0) {
      routines.add(routine);
    } else {
      routines[index] = routine;
    }
    return Success(data.copyWith(routines: routines));
  });

  Future<Result<void>> deleteRoutine(String id) => _change(
    (data) => Success(
      data.copyWith(
        routines: data.routines.where((routine) => routine.id != id).toList(),
      ),
    ),
  );

  Future<Result<void>> start(String id) => _change((data) {
    if (data.active != null) {
      return const Failure(
        AppFailure(message: 'Voce ja tem um treino em andamento.'),
      );
    }
    final routine = data.routines.where((value) => value.id == id).firstOrNull;
    if (routine == null) {
      return const Failure(AppFailure(message: 'Treino nao encontrado.'));
    }
    return Success(
      data.copyWith(
        active: TrainingSession(
          id: newTrainingId(),
          routine: routine,
          startedAt: DateTime.now(),
        ),
      ),
    );
  });

  Future<Result<void>> adjustSet(
    int exerciseIndex,
    int setIndex, {
    int reps = 0,
    double weight = 0,
    bool? completed,
  }) => _change((data) {
    final active = data.active;
    if (active == null) {
      return const Failure(AppFailure(message: 'Nenhum treino em andamento.'));
    }
    final exercises = [...active.routine.exercises];
    if (exerciseIndex < 0 ||
        exerciseIndex >= exercises.length ||
        setIndex < 0 ||
        setIndex >= exercises[exerciseIndex].sets.length ||
        !weight.isFinite) {
      return const Failure(AppFailure(message: 'Serie invalida.'));
    }
    final exercise = exercises[exerciseIndex];
    final sets = [...exercise.sets];
    final previous = sets[setIndex];
    sets[setIndex] = previous.copyWith(
      reps: (previous.reps + reps).clamp(1, 999),
      weight: (previous.weight + weight).clamp(0, 1000).toDouble(),
      completed: completed,
    );
    exercises[exerciseIndex] = exercise.withSets(sets);
    final rest =
        completed == true &&
            !previous.completed &&
            active.routine.restSeconds > 0
        ? DateTime.now().add(Duration(seconds: active.routine.restSeconds))
        : active.restEndsAt;
    return Success(
      data.copyWith(
        active: TrainingSession(
          id: active.id,
          startedAt: active.startedAt,
          restEndsAt: rest,
          routine: Treino(
            id: active.routine.id,
            name: active.routine.name,
            exercises: exercises,
            restSeconds: active.routine.restSeconds,
          ),
        ),
      ),
    );
  });

  Future<Result<void>> clearRest() => _change((data) {
    final active = data.active;
    if (active == null) return Success(data);
    return Success(
      data.copyWith(
        active: TrainingSession(
          id: active.id,
          routine: active.routine,
          startedAt: active.startedAt,
        ),
      ),
    );
  });

  Future<Result<void>> finish() => _change((data) {
    final active = data.active;
    if (active == null || active.completedSets == 0) {
      return const Failure(
        AppFailure(message: 'Conclua pelo menos uma serie antes de finalizar.'),
      );
    }
    return Success(
      data.copyWith(
        clearActive: true,
        history: [
          ...data.history,
          TrainingSession(
            id: active.id,
            routine: active.routine,
            startedAt: active.startedAt,
            finishedAt: DateTime.now(),
          ),
        ],
      ),
    );
  });

  Future<Result<void>> discard() =>
      _change((data) => Success(data.copyWith(clearActive: true)));

  Future<Result<void>> saveCustomExercise(Exercicio exercise) => _change((
    data,
  ) {
    final name = exercise.name.trim();
    if (!RegExp(r'^custom-[a-z0-9-]{1,80}$').hasMatch(exercise.id) ||
        name.isEmpty ||
        name.length > 80 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(name) ||
        !exerciseMuscleGroups.contains(exercise.muscleGroup) ||
        !exerciseEquipmentTypes.contains(exercise.type)) {
      return const Failure(
        AppFailure(
          message: 'Confira o nome, o grupo muscular e o equipamento.',
        ),
      );
    }
    final catalog = [...exerciseLibrary, ...data.customExercises];
    if (catalog.any(
      (item) =>
          item.id == exercise.id ||
          (item.muscleGroup == exercise.muscleGroup &&
              item.type == exercise.type &&
              [item.name, ...item.aliases].any(
                (label) =>
                    normalizeExerciseText(label) == normalizeExerciseText(name),
              )),
    )) {
      return const Failure(
        AppFailure(message: 'Este exercicio ja esta na biblioteca.'),
      );
    }
    return Success(
      data.copyWith(
        customExercises: [
          ...data.customExercises,
          Exercicio(
            id: exercise.id,
            name: name,
            muscleGroup: exercise.muscleGroup,
            type: exercise.type,
          ),
        ],
      ),
    );
  });
}

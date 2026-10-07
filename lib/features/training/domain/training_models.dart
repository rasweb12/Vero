import 'dart:math';

String newTrainingId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${Random.secure().nextInt(1 << 32).toRadixString(36)}';

class Exercicio {
  const Exercicio({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.type,
    this.aliases = const [],
  });
  final String id;
  final String name;
  final String muscleGroup;
  final String type;
  final List<String> aliases;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscle_group': muscleGroup,
    'type': type,
    if (aliases.isNotEmpty) 'aliases': aliases,
  };

  factory Exercicio.fromJson(Map<String, dynamic> json) => Exercicio(
    id: json['id'] as String,
    name: json['name'] as String,
    muscleGroup: json['muscle_group'] as String,
    type: json['type'] as String,
    aliases: List<String>.unmodifiable(json['aliases'] as List? ?? const []),
  );
}

class Serie {
  const Serie({this.reps = 10, this.weight = 0, this.completed = false});
  final int reps;
  final double weight;
  final bool completed;

  Serie copyWith({int? reps, double? weight, bool? completed}) => Serie(
    reps: reps ?? this.reps,
    weight: weight ?? this.weight,
    completed: completed ?? this.completed,
  );
  Map<String, dynamic> toJson() => {
    'reps': reps,
    'weight': weight,
    'completed': completed,
  };
  factory Serie.fromJson(Map<String, dynamic> json) => Serie(
    reps: json['reps'] as int,
    weight: (json['weight'] as num).toDouble(),
    completed: json['completed'] as bool? ?? false,
  );
}

class ExercicioTreino {
  ExercicioTreino({required this.exerciseId, required List<Serie> sets})
    : sets = List.unmodifiable(sets);
  final String exerciseId;
  final List<Serie> sets;
  ExercicioTreino withSets(List<Serie> value) =>
      ExercicioTreino(exerciseId: exerciseId, sets: value);
  Map<String, dynamic> toJson() => {
    'exercise_id': exerciseId,
    'sets': sets.map((value) => value.toJson()).toList(),
  };
  factory ExercicioTreino.fromJson(Map<String, dynamic> json) =>
      ExercicioTreino(
        exerciseId: json['exercise_id'] as String,
        sets: (json['sets'] as List)
            .map((value) => Serie.fromJson(value as Map<String, dynamic>))
            .toList(),
      );
}

class Treino {
  Treino({
    required this.id,
    required this.name,
    required List<ExercicioTreino> exercises,
    this.restSeconds = 60,
  }) : exercises = List.unmodifiable(exercises);
  final String id;
  final String name;
  final List<ExercicioTreino> exercises;
  final int restSeconds;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rest_seconds': restSeconds,
    'exercises': exercises.map((value) => value.toJson()).toList(),
  };
  factory Treino.fromJson(Map<String, dynamic> json) => Treino(
    id: json['id'] as String,
    name: json['name'] as String,
    restSeconds: json['rest_seconds'] as int,
    exercises: (json['exercises'] as List)
        .map((value) => ExercicioTreino.fromJson(value as Map<String, dynamic>))
        .toList(),
  );
}

class TrainingSession {
  TrainingSession({
    required this.id,
    required this.routine,
    required this.startedAt,
    this.finishedAt,
    this.restEndsAt,
  });
  final String id;
  final Treino routine;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final DateTime? restEndsAt;
  int get completedSets => routine.exercises
      .expand((exercise) => exercise.sets)
      .where((set) => set.completed)
      .length;
  int get totalSets => routine.exercises.fold(
    0,
    (total, exercise) => total + exercise.sets.length,
  );
  double get volume => routine.exercises
      .expand((exercise) => exercise.sets)
      .where((set) => set.completed)
      .fold(0, (total, set) => total + set.reps * set.weight);
  Map<String, dynamic> toJson() => {
    'id': id,
    'routine': routine.toJson(),
    'started_at': startedAt.toUtc().toIso8601String(),
    'finished_at': finishedAt?.toUtc().toIso8601String(),
    'rest_ends_at': restEndsAt?.toUtc().toIso8601String(),
  };
  factory TrainingSession.fromJson(Map<String, dynamic> json) =>
      TrainingSession(
        id: json['id'] as String,
        routine: Treino.fromJson(json['routine'] as Map<String, dynamic>),
        startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
        finishedAt: json['finished_at'] == null
            ? null
            : DateTime.parse(json['finished_at'] as String).toLocal(),
        restEndsAt: json['rest_ends_at'] == null
            ? null
            : DateTime.parse(json['rest_ends_at'] as String).toLocal(),
      );
}

class TrainingData {
  TrainingData({
    List<Treino> routines = const [],
    List<TrainingSession> history = const [],
    List<Exercicio> customExercises = const [],
    this.active,
  }) : routines = List.unmodifiable(routines),
       history = List.unmodifiable(history),
       customExercises = List.unmodifiable(customExercises);
  final List<Treino> routines;
  final List<TrainingSession> history;
  final List<Exercicio> customExercises;
  final TrainingSession? active;

  TrainingData copyWith({
    List<Treino>? routines,
    List<TrainingSession>? history,
    List<Exercicio>? customExercises,
    TrainingSession? active,
    bool clearActive = false,
  }) => TrainingData(
    routines: routines ?? this.routines,
    history: history ?? this.history,
    customExercises: customExercises ?? this.customExercises,
    active: clearActive ? null : active ?? this.active,
  );

  Map<String, dynamic> toJson() => {
    'version': 2,
    'routines': routines.map((value) => value.toJson()).toList(),
    'history': history.map((value) => value.toJson()).toList(),
    'custom_exercises': customExercises.map((value) => value.toJson()).toList(),
    'active': active?.toJson(),
  };
  factory TrainingData.fromJson(Map<String, dynamic> json) {
    // Read existing workouts, but do not let older apps overwrite the new catalog.
    if (json['version'] != 1 && json['version'] != 2) {
      throw const FormatException('Unsupported training data version.');
    }
    return TrainingData(
      customExercises: (json['custom_exercises'] as List? ?? const [])
          .map((value) => Exercicio.fromJson(value as Map<String, dynamic>))
          .toList(),
      routines: (json['routines'] as List)
          .map((value) => Treino.fromJson(value as Map<String, dynamic>))
          .toList(),
      history: (json['history'] as List)
          .map(
            (value) => TrainingSession.fromJson(value as Map<String, dynamic>),
          )
          .toList(),
      active: json['active'] == null
          ? null
          : TrainingSession.fromJson(json['active'] as Map<String, dynamic>),
    );
  }

  int trainedDaysThisWeek(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return history
        .where(
          (session) =>
              session.completedSets > 0 &&
              session.finishedAt != null &&
              !session.finishedAt!.isBefore(monday) &&
              !session.finishedAt!.isAfter(now),
        )
        .map((session) {
          final date = session.finishedAt!;
          return DateTime(date.year, date.month, date.day);
        })
        .toSet()
        .length;
  }

  Treino? get nextRoutine {
    if (routines.isEmpty) return null;
    if (history.isEmpty) return routines.first;
    final index = routines.indexWhere(
      (routine) => routine.id == history.last.routine.id,
    );
    return routines[(index + 1) % routines.length];
  }

  List<TrainingSession> historyPage({int offset = 0, int limit = 20}) {
    if (offset < 0 || limit < 1) return const [];
    return history.reversed.skip(offset).take(limit).toList(growable: false);
  }
}

class PreviousSet {
  const PreviousSet(this.set, this.date);
  final Serie set;
  final DateTime date;
}

PreviousSet? previousSet(TrainingData data, String exerciseId, int setIndex) {
  final before = data.active?.startedAt ?? DateTime.now();
  final history =
      data.history
          .where(
            (session) =>
                session.finishedAt != null &&
                session.finishedAt!.isBefore(before),
          )
          .toList()
        ..sort((a, b) => b.finishedAt!.compareTo(a.finishedAt!));
  for (final session in history) {
    for (final exercise in session.routine.exercises) {
      if (exercise.exerciseId == exerciseId &&
          setIndex < exercise.sets.length &&
          exercise.sets[setIndex].completed) {
        return PreviousSet(exercise.sets[setIndex], session.finishedAt!);
      }
    }
  }
  return null;
}

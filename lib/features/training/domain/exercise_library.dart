import 'training_models.dart';

const exerciseMuscleGroups = [
  'Peito',
  'Costas',
  'Pernas',
  'Ombros',
  'Bracos',
  'Abdomen',
  'Corpo inteiro',
  'Outros',
];

const exerciseEquipmentTypes = [
  'Maquina',
  'Cabo',
  'Barra',
  'Halteres',
  'Peso corporal',
  'Elastico',
  'Kettlebell',
  'Outro',
];

const exerciseLibrary = [
  Exercicio(
    id: 'bench-press',
    name: 'Supino reto',
    muscleGroup: 'Peito',
    type: 'Barra',
  ),
  Exercicio(
    id: 'incline-dumbbell',
    name: 'Supino inclinado',
    muscleGroup: 'Peito',
    type: 'Halteres',
  ),
  Exercicio(
    id: 'push-up',
    name: 'Flexao de bracos',
    muscleGroup: 'Peito',
    type: 'Peso corporal',
  ),
  Exercicio(
    id: 'lat-pulldown',
    name: 'Puxada frontal',
    muscleGroup: 'Costas',
    type: 'Maquina',
  ),
  Exercicio(
    id: 'barbell-row',
    name: 'Remada curvada',
    muscleGroup: 'Costas',
    type: 'Barra',
  ),
  Exercicio(
    id: 'seated-row',
    name: 'Remada baixa',
    muscleGroup: 'Costas',
    type: 'Cabo',
  ),
  Exercicio(
    id: 'squat',
    name: 'Agachamento',
    muscleGroup: 'Pernas',
    type: 'Barra',
  ),
  Exercicio(
    id: 'leg-press',
    name: 'Leg press',
    muscleGroup: 'Pernas',
    type: 'Maquina',
  ),
  Exercicio(
    id: 'leg-extension',
    name: 'Cadeira extensora',
    muscleGroup: 'Pernas',
    type: 'Maquina',
  ),
  Exercicio(
    id: 'leg-curl',
    name: 'Mesa flexora',
    muscleGroup: 'Pernas',
    type: 'Maquina',
  ),
  Exercicio(
    id: 'rdl',
    name: 'Levantamento romeno',
    muscleGroup: 'Pernas',
    type: 'Barra',
  ),
  Exercicio(
    id: 'calf-raise',
    name: 'Elevacao de panturrilha',
    muscleGroup: 'Pernas',
    type: 'Maquina',
  ),
  Exercicio(
    id: 'shoulder-press',
    name: 'Desenvolvimento',
    muscleGroup: 'Ombros',
    type: 'Halteres',
  ),
  Exercicio(
    id: 'lateral-raise',
    name: 'Elevacao lateral',
    muscleGroup: 'Ombros',
    type: 'Halteres',
  ),
  Exercicio(
    id: 'biceps-curl',
    name: 'Rosca direta',
    muscleGroup: 'Bracos',
    type: 'Barra',
  ),
  Exercicio(
    id: 'hammer-curl',
    name: 'Rosca martelo',
    muscleGroup: 'Bracos',
    type: 'Halteres',
  ),
  Exercicio(
    id: 'triceps-pushdown',
    name: 'Triceps na polia',
    muscleGroup: 'Bracos',
    type: 'Cabo',
  ),
  Exercicio(
    id: 'crunch',
    name: 'Abdominal',
    muscleGroup: 'Abdomen',
    type: 'Peso corporal',
  ),
  Exercicio(
    id: 'pec-deck',
    name: 'Peck deck',
    muscleGroup: 'Peito',
    type: 'Maquina',
    aliases: ['Pec deck', 'Voador', 'Crucifixo na maquina'],
  ),
  Exercicio(
    id: 'dumbbell-fly',
    name: 'Crucifixo reto',
    muscleGroup: 'Peito',
    type: 'Halteres',
  ),
  Exercicio(
    id: 'incline-dumbbell-fly',
    name: 'Crucifixo inclinado',
    muscleGroup: 'Peito',
    type: 'Halteres',
  ),
  Exercicio(
    id: 'cable-crossover',
    name: 'Crossover',
    muscleGroup: 'Peito',
    type: 'Cabo',
    aliases: ['Crucifixo na polia'],
  ),
  Exercicio(
    id: 'incline-barbell-press',
    name: 'Supino inclinado com barra',
    muscleGroup: 'Peito',
    type: 'Barra',
  ),
  Exercicio(
    id: 'dumbbell-bench-press',
    name: 'Supino reto com halteres',
    muscleGroup: 'Peito',
    type: 'Halteres',
  ),
  Exercicio(
    id: 'decline-bench-press',
    name: 'Supino declinado',
    muscleGroup: 'Peito',
    type: 'Barra',
  ),
  Exercicio(
    id: 'machine-chest-press',
    name: 'Supino na maquina',
    muscleGroup: 'Peito',
    type: 'Maquina',
    aliases: ['Chest press'],
  ),
  Exercicio(
    id: 'smith-bench-press',
    name: 'Supino no Smith',
    muscleGroup: 'Peito',
    type: 'Maquina',
  ),
  Exercicio(
    id: 'pull-up',
    name: 'Barra fixa',
    muscleGroup: 'Costas',
    type: 'Peso corporal',
  ),
  Exercicio(
    id: 'neutral-lat-pulldown',
    name: 'Puxada neutra',
    muscleGroup: 'Costas',
    type: 'Cabo',
    aliases: ['Puxada com triangulo'],
  ),
  Exercicio(
    id: 'underhand-lat-pulldown',
    name: 'Puxada supinada',
    muscleGroup: 'Costas',
    type: 'Cabo',
  ),
  Exercicio(
    id: 'one-arm-dumbbell-row',
    name: 'Remada unilateral',
    muscleGroup: 'Costas',
    type: 'Halteres',
    aliases: ['Remada serrote'],
  ),
  Exercicio(
    id: 'machine-row',
    name: 'Remada na maquina',
    muscleGroup: 'Costas',
    type: 'Maquina',
  ),
  Exercicio(
    id: 't-bar-row',
    name: 'Remada cavalinho',
    muscleGroup: 'Costas',
    type: 'Barra',
  ),
  Exercicio(
    id: 'straight-arm-pulldown',
    name: 'Pulldown na polia',
    muscleGroup: 'Costas',
    type: 'Cabo',
    aliases: ['Pullover na polia'],
  ),
  Exercicio(
    id: 'dumbbell-pullover',
    name: 'Pullover com halter',
    muscleGroup: 'Costas',
    type: 'Halteres',
  ),
  Exercicio(
    id: 'smith-squat',
    name: 'Agachamento no Smith',
    muscleGroup: 'Pernas',
    type: 'Maquina',
  ),
  Exercicio(
    id: 'hack-squat',
    name: 'Agachamento hack',
    muscleGroup: 'Pernas',
    type: 'Maquina',
  ),
  Exercicio(
    id: 'goblet-squat',
    name: 'Agachamento goblet',
    muscleGroup: 'Pernas',
    type: 'Halteres',
  ),
  Exercicio(
    id: 'dumbbell-lunge',
    name: 'Afundo com halteres',
    muscleGroup: 'Pernas',
    type: 'Halteres',
    aliases: ['Passada com halteres'],
  ),
  Exercicio(
    id: 'bulgarian-split-squat',
    name: 'Agachamento bulgaro',
    muscleGroup: 'Pernas',
    type: 'Halteres',
  ),
  Exercicio(
    id: 'seated-leg-curl',
    name: 'Cadeira flexora',
    muscleGroup: 'Pernas',
    type: 'Maquina',
  ),
  Exercicio(
    id: 'hip-abduction',
    name: 'Cadeira abdutora',
    muscleGroup: 'Pernas',
    type: 'Maquina',
  ),
  Exercicio(
    id: 'hip-adduction',
    name: 'Cadeira adutora',
    muscleGroup: 'Pernas',
    type: 'Maquina',
  ),
  Exercicio(
    id: 'hip-thrust',
    name: 'Elevacao pelvica',
    muscleGroup: 'Pernas',
    type: 'Barra',
    aliases: ['Hip thrust'],
  ),
  Exercicio(
    id: 'cable-glute-kickback',
    name: 'Gluteo na polia',
    muscleGroup: 'Pernas',
    type: 'Cabo',
  ),
  Exercicio(
    id: 'barbell-deadlift',
    name: 'Levantamento terra',
    muscleGroup: 'Pernas',
    type: 'Barra',
  ),
  Exercicio(
    id: 'sumo-deadlift',
    name: 'Levantamento terra sumo',
    muscleGroup: 'Pernas',
    type: 'Barra',
  ),
  Exercicio(
    id: 'seated-calf-raise',
    name: 'Panturrilha sentada',
    muscleGroup: 'Pernas',
    type: 'Maquina',
  ),
  Exercicio(
    id: 'leg-press-calf-raise',
    name: 'Panturrilha no leg press',
    muscleGroup: 'Pernas',
    type: 'Maquina',
  ),
  Exercicio(
    id: 'machine-shoulder-press',
    name: 'Desenvolvimento na maquina',
    muscleGroup: 'Ombros',
    type: 'Maquina',
  ),
  Exercicio(
    id: 'barbell-shoulder-press',
    name: 'Desenvolvimento com barra',
    muscleGroup: 'Ombros',
    type: 'Barra',
  ),
  Exercicio(
    id: 'front-raise',
    name: 'Elevacao frontal',
    muscleGroup: 'Ombros',
    type: 'Halteres',
  ),
  Exercicio(
    id: 'cable-lateral-raise',
    name: 'Elevacao lateral na polia',
    muscleGroup: 'Ombros',
    type: 'Cabo',
  ),
  Exercicio(
    id: 'reverse-pec-deck',
    name: 'Peck deck invertido',
    muscleGroup: 'Ombros',
    type: 'Maquina',
    aliases: ['Voador invertido', 'Crucifixo inverso', 'Pec deck invertido'],
  ),
  Exercicio(
    id: 'face-pull',
    name: 'Face pull',
    muscleGroup: 'Ombros',
    type: 'Cabo',
  ),
  Exercicio(
    id: 'dumbbell-shrug',
    name: 'Encolhimento com halteres',
    muscleGroup: 'Ombros',
    type: 'Halteres',
  ),
  Exercicio(
    id: 'alternating-dumbbell-curl',
    name: 'Rosca alternada',
    muscleGroup: 'Bracos',
    type: 'Halteres',
  ),
  Exercicio(
    id: 'preacher-curl',
    name: 'Rosca Scott',
    muscleGroup: 'Bracos',
    type: 'Barra',
  ),
  Exercicio(
    id: 'incline-dumbbell-curl',
    name: 'Rosca inclinada',
    muscleGroup: 'Bracos',
    type: 'Halteres',
  ),
  Exercicio(
    id: 'concentration-curl',
    name: 'Rosca concentrada',
    muscleGroup: 'Bracos',
    type: 'Halteres',
  ),
  Exercicio(
    id: 'cable-biceps-curl',
    name: 'Rosca na polia',
    muscleGroup: 'Bracos',
    type: 'Cabo',
  ),
  Exercicio(
    id: 'rope-triceps-pushdown',
    name: 'Triceps corda',
    muscleGroup: 'Bracos',
    type: 'Cabo',
  ),
  Exercicio(
    id: 'skull-crusher',
    name: 'Triceps testa',
    muscleGroup: 'Bracos',
    type: 'Barra',
  ),
  Exercicio(
    id: 'overhead-dumbbell-triceps',
    name: 'Triceps frances',
    muscleGroup: 'Bracos',
    type: 'Halteres',
  ),
  Exercicio(
    id: 'triceps-dip',
    name: 'Triceps nas paralelas',
    muscleGroup: 'Bracos',
    type: 'Peso corporal',
  ),
  Exercicio(
    id: 'reverse-curl',
    name: 'Rosca inversa',
    muscleGroup: 'Bracos',
    type: 'Barra',
  ),
  Exercicio(
    id: 'reverse-crunch',
    name: 'Abdominal reverso',
    muscleGroup: 'Abdomen',
    type: 'Peso corporal',
  ),
  Exercicio(
    id: 'hanging-leg-raise',
    name: 'Elevacao de pernas',
    muscleGroup: 'Abdomen',
    type: 'Peso corporal',
  ),
  Exercicio(
    id: 'cable-crunch',
    name: 'Abdominal na polia',
    muscleGroup: 'Abdomen',
    type: 'Cabo',
  ),
  Exercicio(
    id: 'machine-crunch',
    name: 'Abdominal na maquina',
    muscleGroup: 'Abdomen',
    type: 'Maquina',
  ),
];

Exercicio exerciseById(
  String id, {
  Iterable<Exercicio> customExercises = const [],
}) =>
    [
      ...exerciseLibrary,
      ...customExercises,
    ].where((exercise) => exercise.id == id).firstOrNull ??
    Exercicio(
      id: id,
      name: 'Exercicio indisponivel',
      muscleGroup: 'Outros',
      type: 'Outro',
    );

String normalizeExerciseText(String value) {
  const accents = {
    '\u00e0': 'a',
    '\u00e1': 'a',
    '\u00e2': 'a',
    '\u00e3': 'a',
    '\u00e4': 'a',
    '\u00e8': 'e',
    '\u00e9': 'e',
    '\u00ea': 'e',
    '\u00eb': 'e',
    '\u00ec': 'i',
    '\u00ed': 'i',
    '\u00ee': 'i',
    '\u00ef': 'i',
    '\u00f2': 'o',
    '\u00f3': 'o',
    '\u00f4': 'o',
    '\u00f5': 'o',
    '\u00f6': 'o',
    '\u00f9': 'u',
    '\u00fa': 'u',
    '\u00fb': 'u',
    '\u00fc': 'u',
    '\u00e7': 'c',
  };
  var normalized = value.toLowerCase().trim();
  for (final entry in accents.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  return normalized.replaceAll(RegExp(r'\s+'), ' ');
}

bool exerciseMatchesQuery(Exercicio exercise, String query) {
  final text = normalizeExerciseText(
    [
      exercise.name,
      ...exercise.aliases,
      exercise.muscleGroup,
      exercise.type,
    ].join(' '),
  );
  return normalizeExerciseText(query).split(' ').every(text.contains);
}

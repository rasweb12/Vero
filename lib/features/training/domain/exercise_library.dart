import 'training_models.dart';

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
];

Exercicio exerciseById(String id) =>
    exerciseLibrary.firstWhere((exercise) => exercise.id == id);

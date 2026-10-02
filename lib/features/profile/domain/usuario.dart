class Usuario {
  const Usuario({
    required this.id,
    required this.email,
    required this.name,
    this.goalWeight,
    this.weeklyGoal = 3,
    this.reminders = false,
    this.pendingUpload = false,
  });

  final String id;
  final String email;
  final String name;
  final double? goalWeight;
  final int weeklyGoal;
  final bool reminders;
  final bool pendingUpload;

  Map<String, dynamic> toRemoteJson() => {
    'id': id,
    'name': name,
    'goal_weight': goalWeight,
    'weekly_goal': weeklyGoal,
    'reminders': reminders,
  };

  Map<String, dynamic> toLocalJson() => {
    ...toRemoteJson(),
    'email': email,
    'pending_upload': pendingUpload,
  };

  factory Usuario.fromJson(Map<String, dynamic> json, {String? email}) =>
      Usuario(
        id: json['id'] as String,
        email: email ?? json['email'] as String? ?? '',
        name: json['name'] as String? ?? '',
        goalWeight: (json['goal_weight'] as num?)?.toDouble(),
        weeklyGoal: (json['weekly_goal'] as num?)?.toInt() ?? 3,
        reminders: json['reminders'] as bool? ?? false,
        pendingUpload: json['pending_upload'] as bool? ?? false,
      );

  Usuario withPendingUpload(bool pending) => Usuario(
    id: id,
    email: email,
    name: name,
    goalWeight: goalWeight,
    weeklyGoal: weeklyGoal,
    reminders: reminders,
    pendingUpload: pending,
  );

  Usuario copyWith({
    String? name,
    double? goalWeight,
    bool clearGoalWeight = false,
    int? weeklyGoal,
    bool? reminders,
  }) => Usuario(
    id: id,
    email: email,
    name: name ?? this.name,
    goalWeight: clearGoalWeight ? null : goalWeight ?? this.goalWeight,
    weeklyGoal: weeklyGoal ?? this.weeklyGoal,
    reminders: reminders ?? this.reminders,
    pendingUpload: pendingUpload,
  );
}

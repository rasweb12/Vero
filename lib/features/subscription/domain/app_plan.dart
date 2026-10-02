enum AppPlan {
  free('Free', 'R\$ 0'),
  monthly('Premium mensal', 'R\$ 39,90/mes'),
  annual('Premium anual', 'R\$ 329,90/ano');

  const AppPlan(this.label, this.price);
  final String label;
  final String price;
  bool get isPremium => this != free;
  int? get photoLimit => isPremium ? null : 5;
  int? get measurementLimit => isPremium ? null : 5;
  int? get historyMonths => isPremium ? null : 3;
  bool get cloudBackup => isPremium;
  bool get reports => isPremium;
  bool get assistant => isPremium;
  bool get adaptiveReminders => this == annual;

  static AppPlan parse(String? value) =>
      values.firstWhere((plan) => plan.name == value, orElse: () => free);
}

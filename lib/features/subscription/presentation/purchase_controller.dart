import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/purchase_service.dart';
import '../domain/app_plan.dart';

class PurchaseState {
  const PurchaseState({
    this.loading = true,
    this.storeAvailable = false,
    this.revenueCatConfigured = false,
    this.products = const [],
    this.entitledPlan = AppPlan.free,
    this.managementUrl,
    this.message,
  });

  final bool loading;
  final bool storeAvailable;
  final bool revenueCatConfigured;
  final List<ProductDetailsView> products;
  final AppPlan entitledPlan;
  final String? managementUrl;
  final String? message;

  PurchaseState copyWith({
    bool? loading,
    bool? storeAvailable,
    bool? revenueCatConfigured,
    List<ProductDetailsView>? products,
    AppPlan? entitledPlan,
    String? managementUrl,
    String? message,
  }) => PurchaseState(
    loading: loading ?? this.loading,
    storeAvailable: storeAvailable ?? this.storeAvailable,
    revenueCatConfigured: revenueCatConfigured ?? this.revenueCatConfigured,
    products: products ?? this.products,
    entitledPlan: entitledPlan ?? this.entitledPlan,
    managementUrl: managementUrl ?? this.managementUrl,
    message: message ?? this.message,
  );
}

class ProductDetailsView {
  const ProductDetailsView({required this.id, required this.price});
  final String id;
  final String price;
}

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final service = PurchaseService();
  ref.onDispose(service.dispose);
  return service;
});

final purchaseControllerProvider =
    StateNotifierProvider<PurchaseController, PurchaseState>((ref) {
      final account = ref.watch(authControllerProvider).account;
      return PurchaseController(
        ref.watch(purchaseServiceProvider),
        account?.id,
      );
    });

class PurchaseController extends StateNotifier<PurchaseState> {
  PurchaseController(this.service, this.accountId)
    : super(const PurchaseState()) {
    ready = accountId == null ? Future.value() : initialize();
  }

  final PurchaseService service;
  final String? accountId;
  late final Future<void> ready;

  Future<void> initialize() async {
    final id = accountId;
    if (id == null) {
      if (mounted) state = state.copyWith(loading: false);
      return;
    }
    try {
      final snapshot = await service.initialize(id);
      if (!mounted) return;
      state = _fromSnapshot(snapshot);
    } on Exception catch (error) {
      if (mounted) {
        state = state.copyWith(
          loading: false,
          message: 'Nao foi possivel preparar as compras: $error',
        );
      }
    }
  }

  Future<void> buy(AppPlan plan) async {
    if (!state.revenueCatConfigured || state.loading) return;
    state = state.copyWith(loading: true, message: null);
    try {
      final snapshot = await service.purchase(plan);
      if (mounted) state = _fromSnapshot(snapshot);
    } on Exception {
      if (mounted) {
        state = state.copyWith(
          loading: false,
          message: 'A compra foi cancelada ou nao pode ser concluida.',
        );
      }
    }
  }

  Future<void> restore() async {
    if (!state.revenueCatConfigured || state.loading) return;
    state = state.copyWith(loading: true, message: null);
    try {
      final snapshot = await service.restore();
      if (mounted) state = _fromSnapshot(snapshot);
    } on Exception {
      if (mounted) {
        state = state.copyWith(
          loading: false,
          message: 'Nao foi possivel restaurar compras agora.',
        );
      }
    }
  }

  Future<void> refresh() async {
    if (!state.revenueCatConfigured || state.loading) return;
    try {
      final snapshot = await service.refresh();
      if (mounted) state = _fromSnapshot(snapshot);
    } on Exception {
      // Fail closed: keep the last verified state when refresh is unavailable.
    }
  }

  PurchaseState _fromSnapshot(PurchaseSnapshot snapshot) => PurchaseState(
    loading: false,
    storeAvailable: snapshot.storeAvailable,
    revenueCatConfigured: snapshot.revenueCatConfigured,
    products: snapshot.products
        .map(
          (product) => ProductDetailsView(id: product.id, price: product.price),
        )
        .toList(),
    entitledPlan: snapshot.entitledPlan,
    managementUrl: snapshot.managementUrl,
    message: snapshot.message,
  );
}

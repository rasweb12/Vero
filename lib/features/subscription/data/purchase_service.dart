import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

import '../../sync/domain/sync_models.dart';
import '../domain/app_plan.dart';

const premiumEntitlementId = 'premium';
const monthlyProductId = 'premium_mensal';
const annualProductId = 'premium_anual';

class PurchaseSnapshot {
  const PurchaseSnapshot({
    this.storeAvailable = false,
    this.revenueCatConfigured = false,
    this.products = const [],
    this.entitledPlan = AppPlan.free,
    this.managementUrl,
    this.message,
  });

  final bool storeAvailable;
  final bool revenueCatConfigured;
  final List<ProductDetails> products;
  final AppPlan entitledPlan;
  final String? managementUrl;
  final String? message;
}

class PurchaseService {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  String? _appUserId;

  Future<PurchaseSnapshot> initialize(String appUserId) async {
    _appUserId = appUserId;
    if (!Platform.isAndroid && !Platform.isIOS) {
      return const PurchaseSnapshot(
        message: 'Compras ficam disponiveis somente no Android e iOS.',
      );
    }
    final available = await InAppPurchase.instance.isAvailable();
    List<ProductDetails> products = const [];
    String? message;
    if (available) {
      final response = await InAppPurchase.instance.queryProductDetails({
        monthlyProductId,
        annualProductId,
      });
      products = response.productDetails;
      if (response.error != null || response.notFoundIDs.isNotEmpty) {
        message =
            'Configure os produtos nas lojas para exibir os precos reais.';
      }
    }

    _purchaseSubscription ??= InAppPurchase.instance.purchaseStream.listen(
      _completeExternalPurchases,
      onError: (_) {},
    );

    final key = Platform.isAndroid
        ? const String.fromEnvironment('REVENUECAT_ANDROID_API_KEY')
        : Platform.isIOS
        ? const String.fromEnvironment('REVENUECAT_IOS_API_KEY')
        : '';
    if (key.isEmpty) {
      return PurchaseSnapshot(
        storeAvailable: available,
        products: products,
        message: 'Configure a chave publica do RevenueCat para ativar compras.',
      );
    }

    try {
      if (await rc.Purchases.isConfigured) {
        await rc.Purchases.logIn(appUserId);
      } else {
        final configuration = rc.PurchasesConfiguration(key)
          ..appUserID = appUserId;
        await rc.Purchases.configure(configuration);
      }
      final info = await rc.Purchases.getCustomerInfo();
      return PurchaseSnapshot(
        storeAvailable: available,
        revenueCatConfigured: true,
        products: products,
        entitledPlan: _planFromInfo(info),
        managementUrl: info.managementURL,
        message: message,
      );
    } on Exception {
      return PurchaseSnapshot(
        storeAvailable: available,
        products: products,
        message: 'Nao foi possivel validar a assinatura agora.',
      );
    }
  }

  Future<PurchaseSnapshot> purchase(AppPlan plan) async {
    if (_appUserId == null) {
      throw StateError('Purchase service is not initialized.');
    }
    final key = plan == AppPlan.annual ? annualProductId : monthlyProductId;
    final products = await rc.Purchases.getProducts([key]);
    if (products.isEmpty) throw StateError('Product is not configured.');
    final result = await rc.Purchases.purchase(
      rc.PurchaseParams.storeProduct(products.first),
    );
    return _snapshotFromInfo(result.customerInfo);
  }

  Future<PurchaseSnapshot> restore() async {
    final info = await rc.Purchases.restorePurchases();
    return _snapshotFromInfo(info);
  }

  Future<PurchaseSnapshot> refresh() async {
    await rc.Purchases.invalidateCustomerInfoCache();
    final info = await rc.Purchases.getCustomerInfo();
    return _snapshotFromInfo(info);
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
  }

  PurchaseSnapshot _snapshotFromInfo(rc.CustomerInfo info) => PurchaseSnapshot(
    storeAvailable: true,
    revenueCatConfigured: true,
    entitledPlan: _planFromInfo(info),
    managementUrl: info.managementURL,
  );

  AppPlan _planFromInfo(rc.CustomerInfo info) {
    if (!info.entitlements.active.containsKey(premiumEntitlementId)) {
      return AppPlan.free;
    }
    return verifiedPlanFromEntitlements(info.activeSubscriptions);
  }

  Future<void> _completeExternalPurchases(List<PurchaseDetails> updates) async {
    // RevenueCat owns receipt validation and entitlement granting. This stream
    // is kept active for store transactions initiated outside this screen.
    for (final purchase in updates) {
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }
}

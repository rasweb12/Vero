import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/providers/local_database_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/purchase_service.dart';
import '../domain/app_plan.dart';
import 'plan_provider.dart';
import 'purchase_controller.dart';

class PlansPage extends ConsumerStatefulWidget {
  const PlansPage({super.key});

  @override
  ConsumerState<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends ConsumerState<PlansPage> {
  bool _saving = false;

  Future<void> _select(AppPlan plan) async {
    final id = ref.read(authControllerProvider).account?.id;
    if (_saving || id == null) return;
    setState(() => _saving = true);
    if (plan != AppPlan.free) {
      await ref.read(purchaseControllerProvider.notifier).buy(plan);
      if (!mounted) return;
      setState(() => _saving = false);
      final purchase = ref.read(purchaseControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            purchase.message ??
                (purchase.entitledPlan.isPremium
                    ? 'Assinatura validada.'
                    : 'A assinatura ainda nao foi validada.'),
          ),
        ),
      );
      return;
    }
    final result = await ref
        .read(localDatabaseProvider)
        .write('plan:$id', 'free');
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) ref.invalidate(planProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.fold(
            onFailure: (failure) => failure.message,
            onSuccess: (_) =>
                'Plano selecionado neste aparelho. Nenhuma cobranca foi realizada.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final purchase = ref.watch(purchaseControllerProvider);
    final current = purchase.entitledPlan;
    return Scaffold(
      appBar: AppBar(title: const Text('Planos')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'No seu ritmo',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text('Sem anuncios. Sem pressao.'),
                const SizedBox(height: 16),
                Text(
                  purchase.revenueCatConfigured
                      ? 'Sua assinatura e validada pela loja e pelo RevenueCat.'
                      : 'Configure as lojas e o RevenueCat para ativar compras reais.',
                ),
                if (purchase.message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    purchase.message!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                for (final plan in AppPlan.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    plan.label,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                ),
                                if (plan == current)
                                  Icon(
                                    Icons.check_circle,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _priceFor(plan, purchase),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (plan == AppPlan.annual)
                              const Text(
                                'Economia de aproximadamente 31% em relacao ao mensal.',
                              ),
                            const SizedBox(height: 16),
                            for (final benefit in _benefits(plan))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(benefit)),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed:
                                  _saving ||
                                      current == plan ||
                                      (plan.isPremium &&
                                          (!purchase.revenueCatConfigured ||
                                              purchase.loading))
                                  ? null
                                  : () => _select(plan),
                              child: Text(
                                current == plan
                                    ? 'Selecionado'
                                    : 'Selecionar plano',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (purchase.revenueCatConfigured) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: purchase.loading
                        ? null
                        : () => ref
                              .read(purchaseControllerProvider.notifier)
                              .restore(),
                    icon: const Icon(Icons.restore),
                    label: const Text('Restaurar compras'),
                  ),
                  if (purchase.managementUrl != null)
                    TextButton.icon(
                      onPressed: () =>
                          _manageSubscription(purchase.managementUrl!),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Renovar ou cancelar assinatura'),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _priceFor(AppPlan plan, PurchaseState purchase) {
    final product = purchase.products
        .where(
          (item) =>
              item.id ==
              switch (plan) {
                AppPlan.monthly => monthlyProductId,
                AppPlan.annual => annualProductId,
                AppPlan.free => '',
              },
        )
        .firstOrNull;
    return product?.price ?? plan.price;
  }

  Future<void> _manageSubscription(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel abrir a loja.')),
        );
      }
    }
  }

  List<String> _benefits(AppPlan plan) => switch (plan) {
    AppPlan.free => [
      'Treinos ilimitados',
      'Ate 5 tipos de medida e 5 fotos',
      'Historico de 3 meses',
    ],
    AppPlan.monthly => [
      'Medidas, fotos e historico ilimitados',
      'Backup e sincronizacao entre dispositivos',
      'Relatorios, PDF e assistente de progresso',
    ],
    AppPlan.annual => [
      'Todos os beneficios do Premium mensal',
      'Lembretes adaptados ao seu ritmo',
      'Novidades em primeira mao e perfil compartilhavel',
    ],
  };
}

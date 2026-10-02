import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/local_database_provider.dart';
import '../../../shared/utils/result.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../subscription/domain/app_plan.dart';
import '../../subscription/presentation/plan_provider.dart';
import '../data/measurement_repository.dart';
import '../domain/measurement_models.dart';

final measurementControllerProvider =
    StateNotifierProvider<MeasurementController, AsyncValue<MeasurementData>>((
      ref,
    ) {
      final owner = ref.watch(
        authControllerProvider.select((value) => value.account?.id),
      );
      return MeasurementController(
        MeasurementRepository(
          ref.watch(localDatabaseProvider),
          owner ?? 'signed-out',
        ),
        () => ref.read(effectivePlanProvider),
      );
    });

class MeasurementController extends StateNotifier<AsyncValue<MeasurementData>> {
  MeasurementController(this.repository, this.plan)
    : super(const AsyncLoading()) {
    ready = reload();
  }
  final MeasurementRepository repository;
  final AppPlan Function() plan;
  late final Future<void> ready;
  Future<void> _pending = Future.value();
  Future<void> reload() async {
    final result = await repository.load();
    if (mounted) {
      state = result.fold(
        onFailure: (failure) => AsyncError(failure.message, StackTrace.current),
        onSuccess: AsyncData.new,
      );
    }
  }

  Future<Result<void>> _change(
    Result<MeasurementData> Function(MeasurementData) update,
  ) {
    final operation = _pending.then((_) async {
      await ready;
      if (!mounted || state.asData == null) {
        return const Failure<void>(
          AppFailure(message: 'As medidas ainda nao estao disponiveis.'),
        );
      }
      final next = update(state.asData!.value);
      if (next case Failure<MeasurementData>(:final failure)) {
        return Failure<void>(failure);
      }
      final data = (next as Success<MeasurementData>).value;
      final saved = await repository.save(data);
      if (mounted && saved.isSuccess) state = AsyncData(data);
      return saved;
    });
    _pending = operation.then((_) {});
    return operation;
  }

  Future<Result<void>> selectMetrics(List<BodyMetric> metrics) => _change((
    data,
  ) {
    final limit = plan().measurementLimit;
    if (metrics.isEmpty || metrics.toSet().length != metrics.length) {
      return const Failure(
        AppFailure(message: 'Selecione pelo menos uma medida, sem repeticoes.'),
      );
    }
    if (limit != null && metrics.length > limit) {
      return const Failure(
        AppFailure(
          message: 'O plano Free permite acompanhar ate 5 tipos de medida.',
          code: 'plan_limit',
        ),
      );
    }
    return Success(MeasurementData(records: data.records, selected: metrics));
  });

  Future<Result<void>> saveRecord(RegistroMedida record) => _change((data) {
    final allowed = data.allowedMetrics(plan().measurementLimit);
    if (record.id.isEmpty ||
        record.values.isEmpty ||
        record.notes.length > 1000 ||
        record.date.isAfter(DateTime.now()) ||
        record.date.isBefore(DateTime(1900)) ||
        record.circumferences.containsKey(BodyMetric.weight) ||
        record.values.entries.any((entry) => !entry.key.accepts(entry.value))) {
      return const Failure(
        AppFailure(message: 'Confira a data e os valores do registro.'),
      );
    }
    if (record.values.keys.any((metric) => !allowed.contains(metric))) {
      return const Failure(
        AppFailure(
          message:
              'Escolha as medidas que deseja acompanhar antes de registrar.',
          code: 'plan_limit',
        ),
      );
    }
    return Success(
      MeasurementData(
        records: [
          ...data.records.where((item) => item.id != record.id),
          record,
        ],
        selected: data.selected,
      ),
    );
  });

  Future<Result<void>> deleteRecord(String id) => _change(
    (data) => Success(
      MeasurementData(
        records: data.records.where((record) => record.id != id).toList(),
        selected: data.selected,
      ),
    ),
  );
}

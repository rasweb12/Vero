import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/widgets/load_failure.dart';
import '../../subscription/presentation/plan_provider.dart';
import '../../training/presentation/training_widgets.dart';
import '../domain/progress_photo.dart';
import 'photo_controller.dart';

class PhotosPage extends ConsumerStatefulWidget {
  const PhotosPage({super.key});
  @override
  ConsumerState<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends ConsumerState<PhotosPage> {
  final _selected = <String>{};
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _busy = true);
      final result = await ref
          .read(photoControllerProvider.notifier)
          .recoverLostPhoto();
      if (!mounted) return;
      setState(() => _busy = false);
      showTrainingResult(context, result);
    });
  }

  Future<void> _add(ImageSource source) async {
    if (_busy) return;
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    setState(() => _busy = true);
    final result = await ref
        .read(photoControllerProvider.notifier)
        .pick(source, date);
    if (!mounted) return;
    setState(() => _busy = false);
    showTrainingResult(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(effectivePlanProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fotos de progresso'),
        actions: [
          IconButton(
            tooltip: 'Comparar fotos selecionadas',
            icon: const Icon(Icons.compare),
            onPressed: _selected.length != 2
                ? null
                : () {
                    final photos =
                        ref.read(photoControllerProvider).asData?.value ?? [];
                    final pair =
                        photos
                            .where((photo) => _selected.contains(photo.id))
                            .toList()
                          ..sort((a, b) => a.date.compareTo(b.date));
                    if (pair.length == 2) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PhotoComparisonPage(photos: pair),
                        ),
                      );
                    }
                  },
          ),
          PopupMenuButton<ImageSource>(
            enabled: !_busy,
            tooltip: 'Adicionar foto',
            icon: const Icon(Icons.add_a_photo_outlined),
            onSelected: _add,
            itemBuilder: (_) => const [
              PopupMenuItem(value: ImageSource.camera, child: Text('Camera')),
              PopupMenuItem(value: ImageSource.gallery, child: Text('Galeria')),
            ],
          ),
        ],
      ),
      body: ref
          .watch(photoControllerProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, trace) => LoadFailure(
              onRetry: () =>
                  ref.read(photoControllerProvider.notifier).reload(),
            ),
            data: (photos) => Column(
              children: [
                if (_busy) const LinearProgressIndicator(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Sua galeria privada')),
                      Text(
                        plan.photoLimit == null
                            ? '${photos.length} fotos'
                            : '${photos.length}/${plan.photoLimit} fotos',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: photos.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Cada fase merece seu registro. Adicione sua primeira foto.',
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = (constraints.maxWidth / 180)
                                .floor()
                                .clamp(2, 4);
                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 0.60,
                                  ),
                              itemCount: photos.length,
                              itemBuilder: (context, index) {
                                final photo = photos.reversed.elementAt(index);
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => PhotoComparisonPage(
                                              photos: [photo],
                                            ),
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: PrivatePhotoImage(
                                            id: photo.id,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      formatDate(photo.date),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Checkbox(
                                          semanticLabel:
                                              'Selecionar foto de ${formatDate(photo.date)} para comparar',
                                          value: _selected.contains(photo.id),
                                          onChanged:
                                              !_selected.contains(photo.id) &&
                                                  _selected.length >= 2
                                              ? null
                                              : (value) => setState(() {
                                                  if (value == true) {
                                                    _selected.add(photo.id);
                                                  } else {
                                                    _selected.remove(photo.id);
                                                  }
                                                }),
                                        ),
                                        IconButton(
                                          tooltip:
                                              'Excluir foto de ${formatDate(photo.date)}',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: _busy
                                              ? null
                                              : () async {
                                                  final confirmed =
                                                      await showDialog<bool>(
                                                        context: context,
                                                        builder: (context) => AlertDialog(
                                                          title: const Text(
                                                            'Excluir foto?',
                                                          ),
                                                          content: const Text(
                                                            'A copia privada sera removida deste aparelho.',
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    context,
                                                                    false,
                                                                  ),
                                                              child: const Text(
                                                                'Cancelar',
                                                              ),
                                                            ),
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    context,
                                                                    true,
                                                                  ),
                                                              child: const Text(
                                                                'Excluir',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                  if (confirmed != true ||
                                                      !context.mounted) {
                                                    return;
                                                  }
                                                  setState(() => _busy = true);
                                                  final result = await ref
                                                      .read(
                                                        photoControllerProvider
                                                            .notifier,
                                                      )
                                                      .remove(photo.id);
                                                  if (!context.mounted) return;
                                                  setState(() {
                                                    _busy = false;
                                                    _selected.remove(photo.id);
                                                  });
                                                  ref.invalidate(
                                                    photoBytesProvider(
                                                      photo.id,
                                                    ),
                                                  );
                                                  showTrainingResult(
                                                    context,
                                                    result,
                                                  );
                                                },
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
    );
  }
}

class PrivatePhotoImage extends ConsumerWidget {
  const PrivatePhotoImage({required this.id, super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(photoBytesProvider(id))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, trace) => Center(
          child: IconButton(
            tooltip: 'Tentar abrir foto novamente',
            onPressed: () => ref.invalidate(photoBytesProvider(id)),
            icon: const Icon(Icons.broken_image_outlined),
          ),
        ),
        data: (bytes) => Image.memory(
          bytes,
          fit: BoxFit.contain,
          gaplessPlayback: false,
          excludeFromSemantics: true,
          errorBuilder: (_, error, trace) =>
              const Center(child: Icon(Icons.broken_image_outlined)),
        ),
      );
}

class PhotoComparisonPage extends StatelessWidget {
  const PhotoComparisonPage({required this.photos, super.key});
  final List<ProgressPhoto> photos;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(photos.length == 1 ? 'Foto de progresso' : 'Antes e depois'),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, photo) in photos.indexed)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Text(
                        '${photos.length == 1
                            ? ''
                            : index == 0
                            ? 'Antes · '
                            : 'Depois · '}${formatDate(photo.date)}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Center(child: PrivatePhotoImage(id: photo.id)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

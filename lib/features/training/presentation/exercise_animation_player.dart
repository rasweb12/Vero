import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../shared/utils/result.dart';
import '../data/exercise_media_cache.dart';
import '../domain/exercise_media.dart';
import 'exercise_playback.dart';
import 'exercise_providers.dart';

final exerciseRouteObserver = RouteObserver<ModalRoute<void>>();

class ExerciseAnimationPlayer extends ConsumerStatefulWidget {
  const ExerciseAnimationPlayer({
    required this.media,
    required this.description,
    this.loader = loadExercisePlayback,
    super.key,
  });
  final ExerciseMedia? media;
  final String description;
  final ExercisePlaybackLoader loader;
  @override
  ConsumerState<ExerciseAnimationPlayer> createState() =>
      _ExerciseAnimationPlayerState();
}

class _ExerciseAnimationPlayerState
    extends ConsumerState<ExerciseAnimationPlayer>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  ExercisePlayback? _playback;
  ModalRoute<void>? _route;
  bool _loading = false;
  bool _error = false;
  bool _wantedPlay = true;
  bool _visible = true;
  bool _routeVisible = true;
  bool _foreground = true;
  bool _tickerEnabled = true;
  double _speed = 1;
  int _generation = 0;
  final _visibilityKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route != route) {
      exerciseRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) exerciseRouteObserver.subscribe(this, route);
      _routeVisible = route?.isCurrent ?? true;
    }
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (MediaQuery.disableAnimationsOf(context)) _wantedPlay = false;
    _sync();
  }

  @override
  void didUpdateWidget(covariant ExerciseAnimationPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media != widget.media) _load();
  }

  @override
  void didPushNext() {
    _routeVisible = false;
    _sync();
  }

  @override
  void didPopNext() {
    _routeVisible = true;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    _playback?.setPlaying(_playback?.failed != true && _wantedPlay && _visible && _routeVisible && _foreground && _tickerEnabled);
  }
  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final media = widget.media;
    final cache = ref.read(exerciseMediaCacheProvider);
    final generation = ++_generation;
    _playback?.removeListener(_changed);
    _playback?.dispose();
    _playback = null;
    _speed = 1;
    _error = false;
    _loading = widget.media != null;
    if (media == null) return;
    ExercisePlayback? playback;
    try {
      final source = await cache.resolve(media);
      if (!mounted || generation != _generation) return;
      if (source is! Success<ExerciseMediaSource>) {
        throw StateError('Media unavailable.');
      }
      playback = await widget.loader(media, source.value, this);
      if (!mounted || generation != _generation) {
        playback.dispose();
        return;
      }
      _playback = playback..addListener(_changed);
      _sync();
    } on Object {
      if (!mounted || generation != _generation) return;
      playback?.dispose();
      await cache.invalidate(media);
      if (!mounted || generation != _generation) return;
      _error = true;
    }
    if (mounted && generation == _generation) setState(() => _loading = false);
  }

  @override
  void dispose() {
    ++_generation;
    exerciseRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _playback?.removeListener(_changed);
    _playback?.dispose();
    _playback = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = _playback;
    final failed = _error || playback?.failed == true;
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: (info) {
        _visible = info.visibleFraction > 0;
        _sync();
      },
      child: Column(
        children: [
          Semantics(
            image: true,
            label: widget.description.isEmpty
                ? 'Demonstracao do exercicio'
                : widget.description,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Carregando animacao',
                        ),
                      )
                    : failed
                    ? _placeholder('Animacao indisponivel', retry: true)
                    : playback == null
                    ? _placeholder('Animacao em preparacao')
                    : RepaintBoundary(child: playback.buildFrame()),
              ),
            ),
          ),
          if (playback != null && !failed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  IconButton(
                    tooltip: _wantedPlay ? 'Pausar' : 'Reproduzir',
                    icon: Icon(_wantedPlay ? Icons.pause : Icons.play_arrow),
                    onPressed: () => setState(() {
                      _wantedPlay = !_wantedPlay;
                      _sync();
                    }),
                  ),
                  IconButton(
                    tooltip: 'Reiniciar',
                    icon: const Icon(Icons.replay),
                    onPressed: () {
                      if (widget.media?.type ==
                          ExerciseMediaType.animatedWebp) {
                        setState(() {
                          _load();
                        });
                      } else {
                        playback.restart();
                        _sync();
                      }
                    },
                  ),
                  if (playback.supportsSpeed)
                    SegmentedButton<double>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: .5, label: Text('0.5x')),
                        ButtonSegment(value: 1, label: Text('1x')),
                        ButtonSegment(value: 1.5, label: Text('1.5x')),
                      ],
                      selected: {_speed},
                      onSelectionChanged: (value) => setState(() {
                        _speed = value.single;
                        playback.setSpeed(_speed);
                      }),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(String message, {bool retry = false}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.ondemand_video_outlined, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (retry)
            IconButton(
              tooltip: 'Tentar novamente',
              onPressed: () => setState(() {
                _load();
              }),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
    ),
  );
}

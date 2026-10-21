import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Subtle, flickering film grain laid over a scene for a cinematic finish.
/// The texture is shifted to a random offset ~12 times a second, like real
/// grain changing frame to frame.
class FilmGrain extends StatefulWidget {
  const FilmGrain({super.key, this.opacity = 0.06});

  final double opacity;

  @override
  State<FilmGrain> createState() => _FilmGrainState();
}

class _FilmGrainState extends State<FilmGrain> {
  final _rng = math.Random();
  late final Timer _timer;
  Alignment _offset = Alignment.center;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 83), (_) {
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      setState(() => _offset = Alignment(_rng.nextDouble() * 2 - 1, _rng.nextDouble() * 2 - 1));
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Opacity(
      opacity: widget.opacity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/textures/grain.png'),
            repeat: ImageRepeat.repeat,
            alignment: _offset,
            scale: 1.6,
          ),
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

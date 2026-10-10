import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pulsing vertical bars in Floodini cyan. Decorative: it shows that the
/// microphone or the voice is active, not the actual audio level.
class VoiceWaveform extends StatefulWidget {
  const VoiceWaveform({
    super.key,
    this.bars = 24,
    this.height = 40,
    this.active = true,
  });

  final int bars;
  final double height;
  final bool active;

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(VoiceWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.bars; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: 4,
                  height:
                      widget.height *
                      (widget.active
                          ? 0.2 +
                                0.8 *
                                    (0.5 +
                                        0.5 *
                                            math.sin(
                                              _controller.value * 2 * math.pi +
                                                  i * 0.7,
                                            ))
                          : 0.15),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

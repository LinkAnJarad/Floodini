import 'package:flutter/material.dart';

/// The Floodini pixel-art mascot. Drawn without smoothing so the pixels stay
/// crisp at any size.
class FloodiniMascot extends StatelessWidget {
  const FloodiniMascot({super.key, this.height = 120});

  static const assetPath = 'assets/images/floodini_mascot.png';

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: height,
      filterQuality: FilterQuality.none,
      semanticLabel: 'Floodini mascot',
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.water_drop,
        size: height * 0.6,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Round mascot avatar for the app header and chat bubbles.
class FloodiniAvatar extends StatelessWidget {
  const FloodiniAvatar({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.1),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: FittedBox(child: FloodiniMascot(height: size)),
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Rounded receipt photo. Tapping (when [zoomable]) opens it full screen.
class ReceiptThumb extends StatelessWidget {
  const ReceiptThumb(this.bytes, {super.key, this.size = 48, this.zoomable = false});

  final Uint8List bytes;
  final double size;
  final bool zoomable;

  @override
  Widget build(BuildContext context) {
    final l = context.ledger;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: Container(
        width: size,
        height: size,
        color: l.subtleFill,
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: (size * 3).round(),
          errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: l.muted),
        ),
      ),
    );
    if (!zoomable) return image;
    return Semantics(
      button: true,
      label: 'View receipt photo',
      child: InkWell(
        borderRadius: BorderRadius.circular(size * 0.2),
        onTap: () => showReceiptViewer(context, bytes),
        child: image,
      ),
    );
  }
}

/// Full-screen, pinch-to-zoom receipt photo.
Future<void> showReceiptViewer(BuildContext context, Uint8List bytes) => showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: IconButton.filledTonal(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
        ],
      ),
    );

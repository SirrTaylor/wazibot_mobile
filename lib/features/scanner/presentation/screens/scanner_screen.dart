/// lib/features/scanner/presentation/screens/scanner_screen.dart
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_theme.dart';

/// Launched from Home → "Scan QR" quick action.
/// Scans any QR code and routes to the relevant screen
/// (customer phone → inbox, order URL, product, etc.)
class ScannerScreen extends StatefulWidget {
  final void Function(String value) onScanned;
  const ScannerScreen({super.key, required this.onScanned});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  bool _scanned = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    final value = barcode?.rawValue;
    if (value == null || value.isEmpty) return;
    _scanned = true;
    _ctrl.stop();
    widget.onScanned(value);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Web doesn't support camera scanning
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan QR')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_scanner,
                    size: 60,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('Camera not available on web',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'QR scanning requires the Android or iOS app.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: _torchOn ? WaziBotColors.primary : Colors.white,
            ),
            onPressed: () {
              _ctrl.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_outlined,
                color: Colors.white),
            onPressed: _ctrl.switchCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera feed
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
          ),

          // Overlay with scan window
          _ScanOverlay(),

          // Instructions
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Point camera at a QR code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.maxWidth * 0.65;
      final top = (constraints.maxHeight - size) / 2.5;
      final left = (constraints.maxWidth - size) / 2;

      return Stack(
        children: [
          // Dark overlay
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.6),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                    decoration: const BoxDecoration(
                        color: Colors.black,
                        backgroundBlendMode: BlendMode.dstOut)),
                Positioned(
                  top: top,
                  left: left,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Corner brackets
          Positioned(
            top: top - 2,
            left: left - 2,
            child: _ScanCorners(size: size + 4),
          ),
        ],
      );
    });
  }
}

class _ScanCorners extends StatelessWidget {
  final double size;
  const _ScanCorners({required this.size});

  @override
  Widget build(BuildContext context) {
    const cornerSize = 24.0;
    const strokeWidth = 3.0;
    const color = WaziBotColors.primary;

    return SizedBox(
      width: size,
      height: size,
      child: const Stack(
        children: [
          // Top-left
          Positioned(
            top: 0,
            left: 0,
            child: _Corner(
                top: true, left: true, size: cornerSize, width: strokeWidth, color: color),
          ),
          // Top-right
          Positioned(
            top: 0,
            right: 0,
            child: _Corner(
                top: true, left: false, size: cornerSize, width: strokeWidth, color: color),
          ),
          // Bottom-left
          Positioned(
            bottom: 0,
            left: 0,
            child: _Corner(
                top: false, left: true, size: cornerSize, width: strokeWidth, color: color),
          ),
          // Bottom-right
          Positioned(
            bottom: 0,
            right: 0,
            child: _Corner(
                top: false, left: false, size: cornerSize, width: strokeWidth, color: color),
          ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  final bool top;
  final bool left;
  final double size;
  final double width;
  final Color color;

  const _Corner({
    required this.top,
    required this.left,
    required this.size,
    required this.width,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
            top: top, left: left, width: width, color: color),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool top;
  final bool left;
  final double width;
  final Color color;

  _CornerPainter(
      {required this.top, required this.left, required this.width, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (top && left) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'dart:ui';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Full-screen camera scanner that returns the first decoded barcode as
/// a String via [Navigator.pop]. Returns `null` if the user backs out.
///
/// Usage:
/// ```dart
/// final code = await Navigator.of(context).push<String>(
///   MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
/// );
/// ```
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late final MobileScannerController _controller;
  // Single-shot guard — onDetect can fire several times for the same
  // barcode in quick succession; pop only the first.
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      // Default to back camera; user can flip via the AppBar button.
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;
    _handled = true;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(raw);
  }

  Widget _circleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon, color: Colors.white, size: 20),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: _circleButton(
          icon: LucideIcons.x,
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Scan Barcode'),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final torchOn = state.torchState == TorchState.on;
              return _circleButton(
                icon:
                    torchOn ? LucideIcons.flashlight : LucideIcons.flashlightOff,
                tooltip: torchOn ? 'Turn torch off' : 'Turn torch on',
                onPressed: () => _controller.toggleTorch(),
              );
            },
          ),
          _circleButton(
            icon: LucideIcons.switchCamera,
            tooltip: 'Flip camera',
            onPressed: () => _controller.switchCamera(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScannerErrorView(error: error),
            fit: BoxFit.cover,
          ),
          // Centered viewfinder — a single neutral-stroked rounded square
          // matches the airy/minimal style used elsewhere in the app.
          const IgnorePointer(child: _ViewfinderOverlay()),
        ],
      ),
    );
  }
}

class _ViewfinderOverlay extends StatelessWidget {
  const _ViewfinderOverlay();

  static const double _boxSize = 248;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _boxSize,
            height: _boxSize,
            child: CustomPaint(
              painter: _CornerBracketsPainter(),
              child: Center(
                child: Container(
                  width: _boxSize - 32,
                  height: 2,
                  color: AppColors.primaryAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Blurred dark instruction pill.
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.black.withValues(alpha: 0.45),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.scanLine,
                        color: AppColors.primaryAccent, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Hold a barcode inside the box',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints four gold L-shaped corner brackets on the viewfinder box.
class _CornerBracketsPainter extends CustomPainter {
  static const double _len = 28; // arm length
  static const double _r = 20; // corner radius

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, _r + _len)
        ..lineTo(0, _r)
        ..arcToPoint(const Offset(_r, 0), radius: const Radius.circular(_r))
        ..lineTo(_r + _len, 0),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(w - _r - _len, 0)
        ..lineTo(w - _r, 0)
        ..arcToPoint(Offset(w, _r), radius: const Radius.circular(_r))
        ..lineTo(w, _r + _len),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(w, h - _r - _len)
        ..lineTo(w, h - _r)
        ..arcToPoint(Offset(w - _r, h), radius: const Radius.circular(_r))
        ..lineTo(w - _r - _len, h),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(_r + _len, h)
        ..lineTo(_r, h)
        ..arcToPoint(Offset(0, h - _r), radius: const Radius.circular(_r))
        ..lineTo(0, h - _r - _len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Shown in place of the camera preview when the platform reports a
/// scanner error (no camera, permission denied, hardware fault, …).
class _ScannerErrorView extends StatelessWidget {
  const _ScannerErrorView({required this.error});

  final MobileScannerException error;

  String get _message {
    final code = error.errorCode;
    if (code == MobileScannerErrorCode.permissionDenied) {
      return 'Camera permission denied.\n'
          'Enable it in Settings to scan barcodes.';
    }
    if (code == MobileScannerErrorCode.unsupported) {
      return 'This device does not support barcode scanning.';
    }
    return 'Camera unavailable.\n${error.errorDetails?.message ?? ''}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }
}

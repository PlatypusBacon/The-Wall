import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'data/climbing_models.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'create_route.dart';
import 'data/route_database.dart';
import 'data/route_model.dart';

class RouteDetailScreen extends StatefulWidget {
  final ClimbingRoute route;

  /// Optional callback invoked when the user deletes this route.
  final VoidCallback? onDeleted;

  const RouteDetailScreen({
    super.key,
    required this.route,
    this.onDeleted,
  });

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _repaintKey = GlobalKey();

  Size? _displayedImageRect;
  Offset? _displayedImageOffset;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _computeImageLayout());
  }

  void _computeImageLayout() {
    final imageSize = widget.route.imageSize;
    final ctx = _stackKey.currentContext;
    if (imageSize == null || ctx == null) return;

    final box = ctx.findRenderObject() as RenderBox;
    final containerSize = box.size;

    final imgW = imageSize.width;
    final imgH = imageSize.height;
    final cntW = containerSize.width;
    final cntH = containerSize.height;

    final scale = (cntW / imgW) < (cntH / imgH)
        ? (cntW / imgW)
        : (cntH / imgH);

    final displayedW = imgW * scale;
    final displayedH = imgH * scale;

    setState(() {
      _displayedImageRect = Size(displayedW, displayedH);
      _displayedImageOffset = Offset(
        (cntW - displayedW) / 2,
        (cntH - displayedH) / 2,
      );
    });
  }
  // --- Duplicate ------ (i cant do the chatgpt thing)
  Future<void> _duplicateRoute() async {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final original = widget.route;

    final duplicate = SavedRoute(
      id: newId,
      name: '${original.name} (copy)',
      difficulty: original.difficulty,
      allHolds: original.allHolds.map((h) => h.copy()).toList(),
      selectedHolds: original.selectedHolds.map((h) => h.copy()).toList(),
      imagePath: original.imagePath,
      imageBytes: original.imageBytes,
      imageSize: original.imageSize,
      createdAt: DateTime.now(),
      isSequenceClimb: original.isSequenceClimb,
    );

    await RouteDatabase.instance.insertRoute(duplicate);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${original.name} (copy)" saved to library')),
      );
    }
  }
  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Route'),
        content: Text('Delete "${widget.route.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      widget.onDeleted?.call();
      Navigator.pop(context);
    }
  }

  // ── Export ────────────────────────────────────────────────────────────────

  Future<void> _shareImage() async {
    setState(() => _isExporting = true);

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Could not find render boundary');

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode image');

      final pngBytes = byteData.buffer.asUint8List();

      if (kIsWeb) {
        await Share.shareXFiles(
          [XFile.fromData(pngBytes, mimeType: 'image/png', name: '${widget.route.name}.png')],
          subject: widget.route.name,
        );
      } else {
        final dir = await getTemporaryDirectory();
        final safeName = widget.route.name
            .replaceAll(RegExp(r'[^\w\s-]'), '')
            .replaceAll(' ', '_');
        final file = File('${dir.path}/${safeName}_route.png');
        await file.writeAsBytes(pngBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          subject: widget.route.name,
          text: 'Climbing route: ${widget.route.name} — ${widget.route.difficulty}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _saveImageToDevice() async {
    setState(() => _isExporting = true);

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Could not find render boundary');

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode image');

      final pngBytes = byteData.buffer.asUint8List();

      if (!kIsWeb) {
        final PermissionStatus status = Platform.isAndroid
            ? await Permission.photos.request()
            : await Permission.storage.request();

        if (!status.isGranted) throw Exception('Permission denied');

        final result = await ImageGallerySaverPlus.saveImage(
          pngBytes,
          quality: 100,
          name: widget.route.name.replaceAll(' ', '_'),
        );

        if (result == null || result['isSuccess'] != true) {
          throw Exception('Save failed');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image saved to device')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    log('isSequenceClimb: ${route.isSequenceClimb}');

    return Scaffold(
      appBar: AppBar(
        title: Text(route.name),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          _isExporting
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.ios_share),
                  tooltip: 'Export / Print',
                  onPressed: _shareImage,
                ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete route',
            color: Colors.red[400],
            onPressed: _confirmDelete,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit route',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateRouteScreen(
                    existingRoute: route,
                    onRouteSaved: (updatedRoute) {
                      setState(() {
                        // replace route in parent storage
                      });
                    },
                  ),
                ),
              );

              if (mounted) setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Duplicate route',
            onPressed: _duplicateRoute,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RepaintBoundary(
              key: _repaintKey,
              child: SizedBox(
                width: double.infinity,
                height: 400,
                child: Stack(
                  key: _stackKey,
                  children: [
                    Positioned.fill(child: _buildImage(route)),
                    // Connector lines drawn below hold boxes but above the image
                    if (_displayedImageRect != null &&
                        _displayedImageOffset != null &&
                        route.isSequenceClimb)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _SequenceLinePainter(
                            holds: route.selectedHolds,
                            imageSize: route.imageSize!,
                            displayedSize: _displayedImageRect!,
                            displayedOffset: _displayedImageOffset!,
                          ),
                        ),
                      ),

                    // Hold boxes and numbers on top
                    if (_displayedImageRect != null &&
                        _displayedImageOffset != null)
                      ..._buildHoldMarkers(route),

                    // Route name watermark
                    Positioned(
                      bottom: 8,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${route.name}  •  ${route.difficulty}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        label: Text(route.difficulty),
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                      ),
                      Chip(label: Text('${route.selectedHolds.length} holds')),
                      if (route.isSequenceClimb)
                        Chip(
                          label: const Text('Sequence'),
                          backgroundColor: Colors.purple[100],
                          avatar: const Icon(Icons.format_list_numbered,
                              size: 16),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text('Route Details',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.calendar_today, 'Created',
                      _formatDate(route.createdAt)),
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.sports_handball, 'Total Holds',
                      '${route.selectedHolds.length}'),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                      Icons.bar_chart, 'Difficulty', route.difficulty),
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.percent, 'Avg Confidence',
                      _getAverageConfidence()),
                  const SizedBox(height: 24),

                  OutlinedButton.icon(
                    onPressed: _isExporting ? null : _saveImageToDevice,
                    icon: const Icon(Icons.download),
                    label: const Text(
                        'save annotated image to device for printing'),
                  ),
                  const SizedBox(height: 24),

                  if (route.isSequenceClimb) ...[
                    Text('Hold Sequence',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    // Holds are already sorted by selectionOrder when saved;
                    // enumerate them with their stored selectionOrder number.
                    ...route.selectedHolds
                        .asMap()
                        .entries
                        .map((e) => _buildSequenceRow(e.value)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hold overlay ──────────────────────────────────────────────────────────

  List<Widget> _buildHoldMarkers(ClimbingRoute route) {
    final imgSize = route.imageSize!;
    final dispSize = _displayedImageRect!;
    final offset = _displayedImageOffset!;
    final scale = dispSize.width / imgSize.width;

    return route.selectedHolds.map((hold) {
      final dispCX = hold.position.dx * scale + offset.dx;
      final dispCY = hold.position.dy * scale + offset.dy;
      final dispW = hold.width * scale;
      final dispH = hold.height * scale;
      final color = _roleColor(hold.role);

      // The sequence number to display: use selectionOrder when available,
      // otherwise fall back to list position + 1 for routes saved before
      // the selectionOrder feature was introduced.
      final selected = route.selectedHolds;
      final displayNumber = hold.selectionOrder ??
          (selected.indexOf(hold) + 1);

      return Positioned(
        left: dispCX - dispW / 2,
        top: dispCY - dispH / 2,
        width: dispW,
        height: dispH,
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.25),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: route.isSequenceClimb
                ? Text(
                    '$displayNumber',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      shadows: const [
                        Shadow(color: Colors.white, blurRadius: 2)
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      );
    }).toList();
  }

  // ── Sequence list ─────────────────────────────────────────────────────────

  /// Builds one row in the "Hold Sequence" list.
  /// Uses [hold.selectionOrder] as the displayed step number, falling back
  /// to list index + 1 for routes saved before the feature was introduced.
  Widget _buildSequenceRow(ClimbingHold hold) {
    final color = _roleColor(hold.role);
    final roleText = _roleText(hold.role);
    final displayNumber = hold.selectionOrder ??
        (widget.route.selectedHolds.indexOf(hold) + 1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Center(
              child: Text(
                '$displayNumber',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _roleIconWidget(hold.role, color, size: 16),
                    const SizedBox(width: 4),
                    Text(roleText,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ],
                ),
                Text(
                  'Position: (${hold.position.dx.toInt()}, ${hold.position.dy.toInt()})',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getConfidenceColor(hold.confidence),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${(hold.confidence * 100).toInt()}%',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildImage(ClimbingRoute route) {
    if (route.imageBytes != null) {
      return Image.memory(
        route.imageBytes!,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );
    }
    if (!kIsWeb &&
        route.imagePath.isNotEmpty &&
        !route.imagePath.startsWith('web_')) {
      return Image.file(
        File(route.imagePath),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() => Container(
        color: Colors.grey[300],
        child: Center(
            child: Text('Image not available',
                style: TextStyle(color: Colors.grey[600]))),
      );

  Color _roleColor(HoldRole role) {
    switch (role) {
      case HoldRole.start:
        return Colors.green;
      case HoldRole.finish:
        return Colors.red;
      case HoldRole.middle:
        return Colors.blue;
      case HoldRole.hand:
        return const Color.fromARGB(255, 33, 68, 243);
      case HoldRole.foot:
        return const Color.fromARGB(255, 159, 33, 243);
    }
  }

  String _roleText(HoldRole role) {
    switch (role) {
      case HoldRole.start:
        return 'Start';
      case HoldRole.finish:
        return 'Finish';
      case HoldRole.middle:
        return 'Hand/Foot';
      case HoldRole.hand:
        return 'Hand Only';
      case HoldRole.foot:
        return 'Foot Only';
    }
  }

  Widget _roleIconWidget(HoldRole role, Color color, {double size = 20}) {
    if (role == HoldRole.foot) {
      return Image.asset('assets/foot.png',
          width: size, height: size, color: color);
    }
    final IconData icon;
    switch (role) {
      case HoldRole.start:
        icon = Icons.play_circle_filled;
        break;
      case HoldRole.finish:
        icon = Icons.flag;
        break;
      case HoldRole.middle:
        icon = Icons.circle;
        break;
      case HoldRole.hand:
        icon = Icons.back_hand;
        break;
      default:
        icon = Icons.circle;
    }
    return Icon(icon, size: size, color: color);
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value),
      ],
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  String _getAverageConfidence() {
    if (widget.route.selectedHolds.isEmpty) return '0%';
    final avg = widget.route.selectedHolds
            .map((h) => h.confidence)
            .reduce((a, b) => a + b) /
        widget.route.selectedHolds.length;
    return '${(avg * 100).toInt()}%';
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }
}

// ── Sequence connector painter ────────────────────────────────────────────────

/// Draws dashed lines with arrowheads between hold centres in sequence order.
///
/// Rendered as a [CustomPaint] layer sitting between the wall image and the
/// hold-box widgets, so lines appear under the numbered boxes but above the
/// photo. Also included inside the [RepaintBoundary] so exports capture them.
class _SequenceLinePainter extends CustomPainter {
  final List<ClimbingHold> holds;
  final Size imageSize;
  final Size displayedSize;
  final Offset displayedOffset;

  const _SequenceLinePainter({
    required this.holds,
    required this.imageSize,
    required this.displayedSize,
    required this.displayedOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (holds.length < 2) return;

    final scale = displayedSize.width / imageSize.width;

    // Sort by selectionOrder; fall back to list index for legacy routes.
    final ordered = holds.toList()
      ..sort((a, b) {
        final ao = a.selectionOrder ?? holds.indexOf(a) + 1;
        final bo = b.selectionOrder ?? holds.indexOf(b) + 1;
        return ao.compareTo(bo);
      });

    // Convert image-space centre to display-space centre.
    Offset toDisplay(ClimbingHold h) => Offset(
          h.position.dx * scale + displayedOffset.dx,
          h.position.dy * scale + displayedOffset.dy,
        );

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.45)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < ordered.length - 1; i++) {
      final from = toDisplay(ordered[i]);
      final to = toDisplay(ordered[i + 1]);

      // Shorten each end so the line starts/ends at the hold box edge
      // rather than at the centre, keeping arrows clear of the number badge.
      final shortened = _shortenSegment(
        from, to,
        startGap: ordered[i].width * scale / 2 + 4,
        endGap: ordered[i + 1].width * scale / 2 + 4,
      );
      if (shortened == null) continue;

      final (p1, p2) = shortened;

      // Draw dashed shadow then dashed white line for contrast on any bg.
      _drawDashed(canvas, p1, p2, shadowPaint);
      _drawDashed(canvas, p1, p2, linePaint);

      // Arrowhead at the destination end.
      _drawArrowhead(canvas, p1, p2, shadowPaint, size: 10);
      _drawArrowhead(canvas, p1, p2, linePaint, size: 8);
    }
  }

  /// Returns shortened (start, end) points, or null if the holds overlap.
  (Offset, Offset)? _shortenSegment(
    Offset from,
    Offset to, {
    required double startGap,
    required double endGap,
  }) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len <= startGap + endGap) return null;

    final ux = dx / len;
    final uy = dy / len;

    return (
      Offset(from.dx + ux * startGap, from.dy + uy * startGap),
      Offset(to.dx - ux * endGap, to.dy - uy * endGap),
    );
  }

  void _drawDashed(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dashLen = 8.0;
    const gapLen = 5.0;

    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return;

    final ux = dx / len;
    final uy = dy / len;

    double travelled = 0;
    bool drawing = true;

    while (travelled < len) {
      final segLen = drawing ? dashLen : gapLen;
      final end = (travelled + segLen).clamp(0.0, len);
      if (drawing) {
        canvas.drawLine(
          Offset(from.dx + ux * travelled, from.dy + uy * travelled),
          Offset(from.dx + ux * end, from.dy + uy * end),
          paint,
        );
      }
      travelled += segLen;
      drawing = !drawing;
    }
  }

  void _drawArrowhead(Canvas canvas, Offset from, Offset to, Paint paint,
      {double size = 8}) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return;

    final ux = dx / len;
    final uy = dy / len;

    final wing1 = Offset(
      to.dx - ux * size - uy * (size * 0.5),
      to.dy - uy * size + ux * (size * 0.5),
    );
    final wing2 = Offset(
      to.dx - ux * size + uy * (size * 0.5),
      to.dy - uy * size - ux * (size * 0.5),
    );

    canvas.drawPath(
      Path()
        ..moveTo(to.dx, to.dy)
        ..lineTo(wing1.dx, wing1.dy)
        ..lineTo(wing2.dx, wing2.dy)
        ..close(),
      Paint()
        ..color = paint.color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _SequenceLinePainter old) =>
      old.holds != holds ||
      old.displayedSize != displayedSize ||
      old.displayedOffset != displayedOffset;
}
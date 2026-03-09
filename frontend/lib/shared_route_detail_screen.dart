import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'data/climbing_models.dart';
import 'data/auth_service.dart';
import 'data/route_database.dart';
import 'data/route_model.dart';
import 'data/comments_service.dart';

/// Reconstructs a [ClimbingRoute] from the raw map returned by
/// [FriendsService.getFriendsRoutes] and displays it read-only,
/// with a duplicate-to-library action and an inline comments section.
class SharedRouteDetailScreen extends StatefulWidget {
  final Map<String, dynamic> routeData;

  const SharedRouteDetailScreen({super.key, required this.routeData});

  @override
  State<SharedRouteDetailScreen> createState() =>
      _SharedRouteDetailScreenState();
}

class _SharedRouteDetailScreenState extends State<SharedRouteDetailScreen> {
  final GlobalKey _stackKey = GlobalKey();
  Size? _displayedImageRect;
  Offset? _displayedImageOffset;

  late final ClimbingRoute _route;

  @override
  void initState() {
    super.initState();
    _route = _buildRoute();
    WidgetsBinding.instance.addPostFrameCallback((_) => _computeImageLayout());
  }

  // ── Reconstruct ClimbingRoute from JSON ───────────────────────────────────

  ClimbingRoute _buildRoute() {
    final d = widget.routeData;

    List<ClimbingHold> parseHolds(dynamic raw) {
      if (raw == null) return [];
      final list = raw as List<dynamic>;
      return list.map((item) {
        final m = Map<String, dynamic>.from(item as Map);
        return ClimbingHold(
          id: m['id'] as String,
          position: Offset(
            (m['position_dx'] as num).toDouble(),
            (m['position_dy'] as num).toDouble(),
          ),
          confidence: (m['confidence'] as num).toDouble(),
          width: (m['width'] as num).toDouble(),
          height: (m['height'] as num).toDouble(),
          isSelected: m['is_selected'] == 1 || m['is_selected'] == true,
          role: HoldRole.values.byName(m['role'] as String),
          selectionOrder: m['selectionOrder'] as int?,
        );
      }).toList();
    }

    final w = (d['image_width'] as num?)?.toDouble() ?? 0.0;
    final h = (d['image_height'] as num?)?.toDouble() ?? 0.0;

    return ClimbingRoute(
      id: d['id'] as String,
      name: d['name'] as String? ?? 'Unnamed',
      imagePath: '',
      imageSize: (w > 0 && h > 0) ? Size(w, h) : null,
      allHolds: parseHolds(d['all_holds']),
      selectedHolds: parseHolds(d['selected_holds']),
      createdAt: d['created_at'] != null
          ? DateTime.tryParse(d['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      difficulty: d['difficulty'] as String? ?? 'V0',
      isSequenceClimb: d['is_sequence_climb'] as bool? ?? false,
    );
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  void _computeImageLayout() {
    final imageSize = _route.imageSize;
    final ctx = _stackKey.currentContext;
    if (imageSize == null || ctx == null) return;

    final box = ctx.findRenderObject() as RenderBox;
    final containerSize = box.size;

    final scale = (containerSize.width / imageSize.width) <
            (containerSize.height / imageSize.height)
        ? (containerSize.width / imageSize.width)
        : (containerSize.height / imageSize.height);

    setState(() {
      _displayedImageRect =
          Size(imageSize.width * scale, imageSize.height * scale);
      _displayedImageOffset = Offset(
        (containerSize.width - imageSize.width * scale) / 2,
        (containerSize.height - imageSize.height * scale) / 2,
      );
    });
  }

  // ── Duplicate to library ──────────────────────────────────────────────────

  Future<void> _duplicateRoute() async {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();

    final duplicate = SavedRoute(
      id: newId,
      name: '${_route.name} (copy)',
      difficulty: _route.difficulty,
      allHolds: _route.allHolds.map((h) => h.copy()).toList(),
      selectedHolds: _route.selectedHolds.map((h) => h.copy()).toList(),
      imagePath: _route.imagePath,
      imageBytes: null, // network image; no local bytes available
      imageSize: _route.imageSize,
      createdAt: DateTime.now(),
      isSequenceClimb: _route.isSequenceClimb,
    );

    await RouteDatabase.instance.insertRoute(duplicate);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('"${_route.name} (copy)" saved to your library')),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.routeData['image_url'] as String?;
    final username = widget.routeData['profiles']?['username'] as String? ??
        'unknown';

    return Scaffold(
      appBar: AppBar(
        title: Text(_route.name),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Save a copy to my library',
            onPressed: _duplicateRoute,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image + hold overlay ──────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 400,
              child: Stack(
                key: _stackKey,
                children: [
                  Positioned.fill(
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                  if (_displayedImageRect != null &&
                      _displayedImageOffset != null &&
                      _route.isSequenceClimb)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _SequenceLinePainter(
                          holds: _route.selectedHolds,
                          imageSize: _route.imageSize!,
                          displayedSize: _displayedImageRect!,
                          displayedOffset: _displayedImageOffset!,
                        ),
                      ),
                    ),
                  if (_displayedImageRect != null &&
                      _displayedImageOffset != null)
                    ..._buildHoldMarkers(),

                  // Watermark
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
                        '${_route.name}  •  ${_route.difficulty}',
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

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Shared by ─────────────────────────────────────────
                  Row(
                    children: [
                      const CircleAvatar(
                          radius: 16, child: Icon(Icons.person, size: 16)),
                      const SizedBox(width: 8),
                      Text('Shared by @$username',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Chips ─────────────────────────────────────────────
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        label: Text(_route.difficulty),
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                      ),
                      Chip(
                          label: Text(
                              '${_route.selectedHolds.length} holds')),
                      if (_route.isSequenceClimb)
                        Chip(
                          label: const Text('Sequence'),
                          backgroundColor: Colors.purple[100],
                          avatar: const Icon(
                              Icons.format_list_numbered,
                              size: 16),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Hold sequence list ────────────────────────────────
                  if (_route.isSequenceClimb) ...[
                    Text('Hold Sequence',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    ..._route.selectedHolds.map(_buildSequenceRow),
                    const SizedBox(height: 16),
                  ],

                  // ── Comments ──────────────────────────────────────────
                  const Divider(),
                  _CommentsSection(routeId: _route.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hold markers ──────────────────────────────────────────────────────────

  List<Widget> _buildHoldMarkers() {
    final imgSize = _route.imageSize!;
    final dispSize = _displayedImageRect!;
    final offset = _displayedImageOffset!;
    final scale = dispSize.width / imgSize.width;

    return _route.selectedHolds.map((hold) {
      final dispCX = hold.position.dx * scale + offset.dx;
      final dispCY = hold.position.dy * scale + offset.dy;
      final dispW = hold.width * scale;
      final dispH = hold.height * scale;
      final color = _roleColor(hold.role);
      final displayNumber = hold.selectionOrder ??
          (_route.selectedHolds.indexOf(hold) + 1);

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
            child: _route.isSequenceClimb
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

  Widget _buildSequenceRow(ClimbingHold hold) {
    final color = _roleColor(hold.role);
    final displayNumber =
        hold.selectionOrder ?? (_route.selectedHolds.indexOf(hold) + 1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: color),
            child: Center(
              child: Text('$displayNumber',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(_roleText(hold.role),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hold.confidence >= 0.8
                  ? Colors.green
                  : hold.confidence >= 0.6
                      ? Colors.orange
                      : Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${(hold.confidence * 100).toInt()}%',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _placeholder() => Container(
        color: Colors.grey[300],
        child: const Center(
            child: Icon(Icons.image_not_supported, size: 48)),
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
}

// ── Comments section ──────────────────────────────────────────────────────────

class _CommentsSection extends StatefulWidget {
  final String routeId;
  const _CommentsSection({required this.routeId});

  @override
  State<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<_CommentsSection> {
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final comments =
          await CommentsService.instance.getComments(widget.routeId);
      if (mounted) setState(() { _comments = comments; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await CommentsService.instance.addComment(widget.routeId, text);
      _controller.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not post comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete(String commentId) async {
    await CommentsService.instance.deleteComment(commentId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService.instance.currentUser?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comments',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),

        // ── Comment list ──────────────────────────────────────────────────
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No comments yet. Be the first!',
                style: TextStyle(color: Colors.grey)),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = _comments[i];
              final username =
                  c['profiles']?['username'] as String? ?? 'unknown';
              final isOwn = c['user_id'] == currentUserId;
              final createdAt = c['created_at'] != null
                  ? DateTime.tryParse(c['created_at'] as String)
                  : null;
              final timeLabel = createdAt != null
                  ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
                  : '';

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                    radius: 16, child: Icon(Icons.person, size: 14)),
                title: Row(
                  children: [
                    Text('@$username',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(timeLabel,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
                subtitle: Text(c['body'] as String? ?? ''),
                trailing: isOwn
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                        tooltip: 'Delete comment',
                        onPressed: () => _delete(c['id'] as String),
                      )
                    : null,
              );
            },
          ),

        const SizedBox(height: 12),

        // ── Input ─────────────────────────────────────────────────────────
        if (AuthService.instance.isLoggedIn)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _submit(),
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Post'),
              ),
            ],
          )
        else
          const Text('Sign in to leave a comment.',
              style: TextStyle(color: Colors.grey)),

        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Sequence line painter (copied from RouteDetailScreen) ─────────────────────

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

    final ordered = holds.toList()
      ..sort((a, b) {
        final ao = a.selectionOrder ?? holds.indexOf(a) + 1;
        final bo = b.selectionOrder ?? holds.indexOf(b) + 1;
        return ao.compareTo(bo);
      });

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
      final shortened = _shortenSegment(from, to,
          startGap: ordered[i].width * scale / 2 + 4,
          endGap: ordered[i + 1].width * scale / 2 + 4);
      if (shortened == null) continue;
      final (p1, p2) = shortened;
      _drawDashed(canvas, p1, p2, shadowPaint);
      _drawDashed(canvas, p1, p2, linePaint);
      _drawArrowhead(canvas, p1, p2, shadowPaint, size: 10);
      _drawArrowhead(canvas, p1, p2, linePaint, size: 8);
    }
  }

  (Offset, Offset)? _shortenSegment(Offset from, Offset to,
      {required double startGap, required double endGap}) {
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
    final wing1 = Offset(to.dx - ux * size - uy * (size * 0.5),
        to.dy - uy * size + ux * (size * 0.5));
    final wing2 = Offset(to.dx - ux * size + uy * (size * 0.5),
        to.dy - uy * size - ux * (size * 0.5));
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
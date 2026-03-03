import 'package:flutter/material.dart';
import 'data/climbing_models.dart';

class EditRouteScreen extends StatefulWidget {
  final ClimbingRoute route;

  const EditRouteScreen({super.key, required this.route});

  @override
  State<EditRouteScreen> createState() => _EditRouteScreenState();
}

class _EditRouteScreenState extends State<EditRouteScreen> {
  late List<ClimbingHold> _allHolds;
  late List<ClimbingHold> _selectedHolds;
  @override
  void initState() {
    super.initState();

    // IMPORTANT: work on copies, not original objects
    _allHolds = widget.route.allHolds.map((h) => h.copy()).toList();
    _selectedHolds = widget.route.selectedHolds.map((h) => h.copy()).toList();
  }

  // ── Toggle selection ───────────────────────────────

  void _toggleHold(ClimbingHold hold) {
    setState(() {
      hold.isSelected = !hold.isSelected;

      if (!hold.isSelected) {
        hold.selectionOrder = null;
      } else if (widget.route.isSequenceClimb) {
        // assign next order
        final maxOrder = _allHolds
            .where((h) => h.selectionOrder != null)
            .map((h) => h.selectionOrder!)
            .fold(0, (a, b) => a > b ? a : b);

        hold.selectionOrder = maxOrder + 1;
      }
    });
  }

  // ── Save ──────────────────────────────────────────

  void _save() {
    final updatedRoute = ClimbingRoute(
      id: widget.route.id,
      name: widget.route.name,
      imagePath: widget.route.imagePath,
      imageBytes: widget.route.imageBytes,
      imageSize: widget.route.imageSize,
      allHolds: _allHolds,
      selectedHolds: _selectedHolds,
      createdAt: widget.route.createdAt,
      difficulty: widget.route.difficulty,
      isSequenceClimb: widget.route.isSequenceClimb,
    );

    Navigator.pop(context, updatedRoute);
  }

  // ── Build ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedHolds.where((h) => h.isSelected).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Route'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildImage()),

          // holds overlay
          ..._buildHoldMarkers(),

          Positioned(
            bottom: 16,
            left: 16,
            child: Chip(label: Text('$selectedCount selected')),
          ),
        ],
      ),
    );
  }

  // ── Image ─────────────────────────────────────────

  Widget _buildImage() {
    final route = widget.route;

    if (route.imageBytes != null) {
      return Image.memory(route.imageBytes!, fit: BoxFit.contain);
    }

    return Container(color: Colors.black12);
  }

  // ── Hold UI ───────────────────────────────────────

  List<Widget> _buildHoldMarkers() {
    return _allHolds.map((hold) {
      final color = hold.isSelected ? Colors.green : Colors.grey;

      return Positioned(
        left: hold.position.dx - hold.width / 2,
        top: hold.position.dy - hold.height / 2,
        width: hold.width,
        height: hold.height,
        child: GestureDetector(
          onTap: () => _toggleHold(hold),
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: hold.selectionOrder != null
                  ? Text(
                      '${hold.selectionOrder}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
          ),
        ),
      );
    }).toList();
  }
}
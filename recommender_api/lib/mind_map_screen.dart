import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'models/mind_map_data.dart';
import 'mind_map/layout_engine.dart';
import 'mind_map/edge_painter.dart';
import 'theme/glassmorphism.dart';

class MindMapScreen extends StatefulWidget {
  final Map<String, dynamic> data; // Raw JSON from backend

  const MindMapScreen({super.key, required this.data});

  @override
  State<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends State<MindMapScreen> {
  late MindMapResponseData _mapData;
  final TransformationController _transformController = TransformationController();

  //color palette for tree map blocks 
  static const List<Color> _treeMapColors = [
    Color(0xFF3B82F6), // blue
    Color(0xFF8B5CF6), // violet
    Color(0xFF06B6D4), // cyan
    Color(0xFFF97316), // orange
    Color(0xFF10B981), // emerald
    Color(0xFFEF4444), // red
    Color(0xFFF59E0B), // amber
    Color(0xFFEC4899), // pink
  ];

  @override
  void initState() {
    super.initState();
    _mapData = MindMapResponseData.fromJson(widget.data);
    LayoutEngine.applyLayout(_mapData);
  }

  // the total canvas size needed to contain all nodes
  Size _calculateCanvasSize() {
    double maxX = 0, maxY=0;

    // Hint: Iterate all nodes, find the max x + width and max y + heightdouble
    for (var node in _mapData.nodes) {
    double right  = node.position.dx + node.size.width;
    double bottom = node.position.dy + node.size.height;
    if (right > maxX) maxX = right;
    if (bottom > maxY) maxY = bottom;
    }

    return Size(maxX + 200, maxY + 200);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canvasSize = _calculateCanvasSize();

    return Scaffold(
      appBar: AppBar(
        title: Text(_mapData.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Reset View',
            onPressed: () {
              _transformController.value = Matrix4.identity();
            },
          ),
        ],
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [Colors.grey[100]!, Colors.blue[50]!],
          ),
        ),

        // gradient background matching the app's dark/light theme
        child: InteractiveViewer(
          // --- This is what gives us free pan & zoom ---
          transformationController: _transformController,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          minScale: 0.2,
          maxScale: 3.0,
          constrained: false, // Allows canvas to be larger than screen

          child: SizedBox(
            width: canvasSize.width,
            height: canvasSize.height,
            child: Stack(
              children: [
                // ============================
                // LAYER 1: Edge lines (bottom)
                // ============================
                Positioned.fill(
                  child: CustomPaint(
                    painter: EdgePainter(
                      nodes: _mapData.nodes,
                      edges: _mapData.edges,
                      mapType: _mapData.mapType,
                      isDark: isDark,
                    ),
                  ),
                ),

                // ============================
                // LAYER 2: Node cards (top)
                // ============================
                ..._mapData.nodes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final node = entry.value;

                  if (_mapData.mapType == "tree") {
                    return _buildTreeMapBlock(node, index, isDark);
                  }
                  return Positioned(
                    left: node.position.dx,
                    top: node.position.dy,
                    width: node.size.width,
                    height: node.size.height,
                    child: _buildNodeCard(node, isDark),
                  ).animate().fadeIn(duration: 400.ms, delay: (50 * index).ms)
                      .scale(begin: const Offset(0.8, 0.8), duration: 400.ms, delay: (50 * index).ms);
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // Node Card Widget
  Widget _buildNodeCard(MindMapNode node, bool isDark) {
    //  GlassContainer for glassmorphism styling
    Color borderColor;
    double fontSize;
    FontWeight fontWeight;

    // Hint 2: Style differently based on node.type:
    //         - 'root': Larger text, gradient background, primary color border
    //         - 'branch': Medium size, subtle highlight
    //         - 'leaf': Smallest, plain glass
    switch (node.type) {
      case 'root':
        borderColor = Colors.blue;
        fontSize = 16;
        fontWeight = FontWeight.bold;
        break;
      case 'branch':
        borderColor = Colors.purple;
        fontSize = 13;
        fontWeight = FontWeight.w600;
        break;
      default:
        borderColor = isDark ? Colors.white24 : Colors.grey.shade300;
        fontSize = 12;
        fontWeight = FontWeight.w500;
    }

    return GlassContainer(
      borderRadius: node.type == 'root' ? 20 : 12,
      gradient: node.type == 'root'
          ? LinearGradient(
              colors: [Colors.blue.withValues(alpha: 0.25),
                Colors.purple.withValues(alpha: 0.15),
                ],
            )
          : null,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor.withValues(alpha: 0.5), width: node.type == 'root' ? 2.0 : 1.0),
          borderRadius: BorderRadius.circular(node.type == 'root' ? 20 : 12),
        ),
        child: Center(  
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              node.label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
              style: GoogleFonts.inter(
                color: isDark ? Colors.white : Colors.black,
                fontSize: fontSize,
                fontWeight: fontWeight,
              ),
            ),
          ),
      ),
      ),
    );
  }

  Widget _buildTreeMapBlock(MindMapNode node, int index, bool isDark) {
    final color = _treeMapColors[index % _treeMapColors.length];
    final hasChildren = _mapData.edges.any((e) => e.idFrom == node.id);
    return Positioned(
      left: node.position.dx,
      top: node.position.dy,
      width: node.size.width,
      height: node.size.height,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: hasChildren ? 0.15 : 0.35),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            node.label,
            style: GoogleFonts.inter(
              fontSize: node.type == 'root' ? 14 : 11,
              fontWeight: node.type == 'root' ? FontWeight.bold : FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: (30 * index).ms);
  }
}
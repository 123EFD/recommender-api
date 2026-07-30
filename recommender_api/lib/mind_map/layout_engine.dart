import 'dart:math';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import '../models/mind_map_data.dart';

// Assign (x,y) to each node
class LayoutEngine {
  static void applyLayout(MindMapResponseData mindMapData) {
    // 1. Measure text and assign dynamic bounds to all nodes
    for (var node in mindMapData.nodes) {
      if (mindMapData.mapType != 'tree') {
        node.size = _measureNodeText(node);
      }
    }

    // 2. Apply layout algorithms
    switch (mindMapData.mapType) {
      case 'flowchart':
        _layoutFlowchart(mindMapData);
        break;
      case 'bubble':
        _layoutBubble(mindMapData);
        break;
      case 'tree':
        _layoutTreeMap(mindMapData);
        break;
      case 'concept':
        _layoutConcept(mindMapData);
        break;
      default:
        _layoutHierarchical(mindMapData);
    }
  }

  static Size _measureNodeText(MindMapNode node) {
    double fontSize;
    FontWeight fontWeight;

    switch (node.type) {
      case 'root':
        fontSize = 16.0;
        fontWeight = FontWeight.bold;
        break;
      case 'branch':
        fontSize = 13.0;
        fontWeight = FontWeight.w600;
        break;
      default:
        fontSize = 12.0;
        fontWeight = FontWeight.w500;
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: node.label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontFamily: 'Inter', // Assuming GoogleFonts.inter
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
    )..layout(minWidth: 0, maxWidth: 160); // Allow text to wrap up to 160 width

    // Add padding (horizontal 12*2, vertical 8*2) + border space
    return Size(
      max(100.0, textPainter.size.width + 32.0),
      max(50.0, textPainter.size.height + 24.0),
    );
  }
  
  // Helper methods
  static Map<String, List<String>> _buildAdjacencyMap(List<MindMapEdge> edges) {
    final map = <String, List<String>>{};
    for (var edge in edges) {
      map.putIfAbsent(edge.idFrom, () => []).add(edge.idTo);
    }
    return map;
  }

  static Map<String, MindMapNode> _buildNodeMap(List<MindMapNode> nodes) {
    final map = <String, MindMapNode>{};
    for (var node in nodes) {
      map[node.id] = node;
    }
    return map;
  }

  static MindMapNode _findRoot(List<MindMapNode> nodes, List<MindMapEdge> edges) {
    // Find the root node (type == 'root', or the node with no incoming edges)
    final allTargets  = nodes.map((n) => n.id).toSet();
    for (var node in nodes) {
      if ( !allTargets.contains(node.id)) return node;
    }

    for (var node in nodes) {
      if (node.type == 'root') return node;
    }

    return nodes.first; // fallback to the first node
  }

  // Hierarchical layout
  static void _layoutHierarchical(MindMapResponseData mindMapData) {
    if (mindMapData.nodes.isEmpty) return;
    final adjacency  = _buildAdjacencyMap(mindMapData.edges);
    final nodeMap = _buildNodeMap(mindMapData.nodes);
    final root = _findRoot(mindMapData.nodes, mindMapData.edges);

    const double verticalSpacing = 150.0;
    const double horizontalSpacing = 220.0;

    //count the leaad descendants under each node to prevent overlapping 
    Map<String, int> leafCounts = {};
    int countLeaves(String nodeId) {
      final children = adjacency[nodeId] ?? [];
      if (children.isEmpty) {
        leafCounts[nodeId] = 1;
        return 1;
      }
      int total = 0;
      for (var childId in children) {
        total += countLeaves(childId);
      }
      leafCounts[nodeId] = total;
      return total;
    }

    countLeaves(root.id);

    // Position each node using DFS 
    void positionNode(String nodeId, int depth , double xOffset) {
      final node = nodeMap[nodeId]!;
      final children = adjacency[nodeId] ?? [];
      final leafCount = leafCounts[nodeId] ?? 1;

      //node's X is the center of its allocated horizontal space based on its leaf count
      double totalWidth = leafCount * horizontalSpacing;
      double centerX = xOffset + (totalWidth / 2) - (node.size.width / 2);
      double y = 80.0 + (depth * verticalSpacing);
      node.position = Offset(centerX, y);

      // left-to-right positioning of children
      double childXOffset = xOffset;
      for (var childId in children) {
        int childLeaves = leafCounts[childId] ?? 1;
        positionNode(childId, depth + 1, childXOffset);
        childXOffset += childLeaves * horizontalSpacing;
      }
    }

    positionNode(root.id, 0, 0.0);

    // Normalize coord. 
    _normalizePositions(mindMapData.nodes, 100, 80);
  }

  // Flowchart layout
  static void _layoutFlowchart(MindMapResponseData mindMapData) {
    if (mindMapData.nodes.isEmpty) return;

    final adjacency = _buildAdjacencyMap(mindMapData.edges);
    final nodeMap = _buildNodeMap(mindMapData.nodes);
    final root = _findRoot(mindMapData.nodes, mindMapData.edges);
    const double verticalGap = 130.0;
    const double laneOffset = 200.0;
    double centerX = 800.0;
    double currentY = 80.0;

    Set<String> visited = {};

    void walk(String nodeId, double xPos) {
      if (visited.contains(nodeId)) return;
      visited.add(nodeId);

      final node = nodeMap[nodeId]!;
      node.position = Offset(xPos - node.size.width / 2, currentY);
      currentY += node.size.height + verticalGap;

      final children = adjacency[nodeId] ?? [];
      if (children.length == 1) {
        walk(children[0], xPos);
      } else if (children.length == 2) {
        //decision branch
        double branchY = currentY;

        //left branch
        final leftNode = nodeMap[children[0]]!;
        leftNode.position = Offset(xPos - laneOffset - leftNode.size.width / 2, branchY);
        visited.add(children[0]);

        //right branch
        final rightNode = nodeMap[children[1]]!;
        rightNode.position = Offset(xPos + laneOffset - rightNode.size.width / 2, branchY);
        visited.add(children[1]); 

        currentY = branchY + leftNode.size.height + verticalGap; // move down after branches

        final leftChildren = adjacency[children[0]] ?? [];
        final rightChildren = adjacency[children[1]] ?? [];

        //both branch converge to same node
        if (leftChildren.isNotEmpty && rightChildren.isNotEmpty && leftChildren.first == rightChildren.first) {
          walk(leftChildren.first, xPos);
        } else {
          //walk left branch children
          for (var childId in leftChildren) {
            walk(childId, xPos - laneOffset);
          }
          //walk right branch children
          for (var childId in rightChildren) {
            walk(childId, xPos + laneOffset);
          }
        }
      }
      else if (children.length > 2) {
        //multiple branches
        double totalWidth = (children.length - 1) * laneOffset;
        double startX = xPos - totalWidth / 2;
        double branchY = currentY;
        for (int i = 0; i < children.length; i++) {
          final child = nodeMap[children[i]]!;
          child.position = Offset(startX + i * laneOffset - child.size.width / 2, branchY);
          visited.add(children[i]);
        }
        currentY = branchY + (nodeMap[children[0]]?.size.height ?? 60) + verticalGap;
      }
    }
    walk(root.id, centerX);
    _normalizePositions(mindMapData.nodes, 100, 80);
  }

  // Bubble Map (Bilateral Radial Arcs)
  static void _layoutBubble(MindMapResponseData data) {
    if (data.nodes.isEmpty) return;
    final adjacency = _buildAdjacencyMap(data.edges);
    final nodeMap = _buildNodeMap(data.nodes);
    final root = _findRoot(data.nodes, data.edges);
    
    final Offset center = const Offset(900, 900);
    root.size = Size(root.size.width + 40, root.size.height + 20); // Make root visually larger
    root.position = Offset(center.dx - root.size.width / 2, center.dy - root.size.height / 2);

    final firstLevel = adjacency[root.id] ?? [];
    if (firstLevel.isEmpty) return;

    // Split first level into left and right hemispheres
    final leftNodes = <String>[];
    final rightNodes = <String>[];
    for (int i = 0; i < firstLevel.length; i++) {
      if (i % 2 == 0) {
        rightNodes.add(firstLevel[i]);
      } else {
        leftNodes.add(firstLevel[i]);
      }
    }

    void layoutHemisphere(List<String> nodes, bool isRight) {
      if (nodes.isEmpty) return;
      // Spread nodes over a 120-degree arc on the respective side
      final double totalArc = 120.0 * (pi / 180.0);
      final double startAngle = isRight ? -totalArc / 2 : pi - (totalArc / 2);
      final double angleStep = nodes.length > 1 ? totalArc / (nodes.length - 1) : 0;
      final double radius = 280.0;

      for (int i = 0; i < nodes.length; i++) {
        double angle = startAngle + (i * angleStep);
        double x = center.dx + (radius * cos(angle));
        double y = center.dy + (radius * sin(angle));

        final child = nodeMap[nodes[i]]!;
        child.position = Offset(x - child.size.width / 2, y - child.size.height / 2);

        // Position sub-children
        final secondLevel = adjacency[child.id] ?? [];
        if (secondLevel.isEmpty) continue;
        
        Offset childCenter = Offset(x, y);
        // Sub-orbit angle spread
        double subArc = 90.0 * (pi / 180.0);
        // Base sub-orbit outward from center
        double baseAngle = atan2(y - center.dy, x - center.dx);
        double subStartAngle = baseAngle - (subArc / 2);
        double subStep = secondLevel.length > 1 ? subArc / (secondLevel.length - 1) : 0;
        double subRadius = 180.0;

        for (int j = 0; j < secondLevel.length; j++) {
          double subAngle = subStartAngle + (j * subStep);
          double sx = childCenter.dx + (subRadius * cos(subAngle));
          double sy = childCenter.dy + (subRadius * sin(subAngle));

          final subChild = nodeMap[secondLevel[j]]!;
          subChild.position = Offset(sx - subChild.size.width / 2, sy - subChild.size.height / 2);
        }
      }
    }

    layoutHemisphere(leftNodes, false);
    layoutHemisphere(rightNodes, true);

    _normalizePositions(data.nodes, 100, 100);
  }

  // Tree Map
  static void _layoutTreeMap(MindMapResponseData data) {
    if (data.nodes.isEmpty) return;
    final adjacency = _buildAdjacencyMap(data.edges);
    final nodeMap = _buildNodeMap(data.nodes);
    final root = _findRoot(data.nodes, data.edges);

     // Root gets the entire canvas
    const double canvasWidth = 1600.0;
    const double canvasHeight = 900.0;
    const double padding = 6.0;
    root.position = const Offset(0, 0);
    root.size = const Size(canvasWidth, canvasHeight);

    void sliceRectangle(String nodeId, bool sliceVertically) {
      MindMapNode parent = nodeMap[nodeId]!;
      List<String> children = adjacency[nodeId] ?? [];
      if (children.isEmpty) return;
      
      double headerHeight = 30.0;
      double innerX = parent.position.dx + padding;
      double innerY = parent.position.dy + headerHeight + padding;
      double innerWidth = parent.size.width - (padding * 2);
      double innerHeight = parent.size.height - headerHeight - (padding * 2);

      if (innerWidth <= 0 || innerHeight <= 0) return;

      for (int  i =0; i < children.length; i++) {
        MindMapNode child = nodeMap[children[i]]!;
        double childWidth, childHeight, startX, startY;
        if (sliceVertically) {
          childWidth = innerWidth / children.length;
          childHeight = innerHeight;
          startX = innerX + (i * childWidth);
          startY = innerY;
        } else {
          childWidth = innerWidth;
          childHeight = innerHeight / children.length;
          startX = innerX;
          startY = innerY + (i * childHeight);
        }

        child.position = Offset(startX, startY);
        child.size = Size(childWidth, childHeight);

        //flip the slicing direction for the next level
        sliceRectangle(child.id, !sliceVertically);
      }
    }
    sliceRectangle(root.id, true);
  }

  //Concept Map
  static void _layoutConcept(MindMapResponseData data) {
    if (data.nodes.isEmpty) return;
    final adjacency = _buildAdjacencyMap(data.edges);
    final nodeMap = _buildNodeMap(data.nodes);
    final root = _findRoot(data.nodes, data.edges);

    // Concept maps are similar to hierarchical but with more horizontal spread
    // and every edge can have a relationship label, so we give extra spacing.
    const double verticalSpacing = 180.0;
    const double horizontalSpacing = 260.0;
    Map<String, int> leafCounts = {}; 

    int countLeaves(String nodeId, Set<String> visited) {
      if (visited.contains(nodeId)) {
        leafCounts[nodeId] = 0;
        return 0; // Avoid cycles
      }
      visited.add(nodeId);

      final children = adjacency[nodeId] ?? [];
      if (children.isEmpty) {
        leafCounts[nodeId] = 1;
        return 1;
      }
      int total = 0;
      for (var childId in children) {
        total += countLeaves(childId, visited);
      }
      leafCounts[nodeId] = total;
      return total;
    }
    countLeaves(root.id, {});

    void positionNode(String nodeId, int depth, double xOffset, Set<String> visited) {
      if (visited.contains(nodeId)) return;
      visited.add(nodeId);

      final node = nodeMap[nodeId]!;
      final children = adjacency[nodeId] ?? [];
      final leafCount = leafCounts[nodeId] ?? 1;

      double totalWidth = leafCount * horizontalSpacing;
      double centerX = xOffset + (totalWidth / 2) - (node.size.width / 2);
      double y = 80.0 + (depth * verticalSpacing);
      node.position = Offset(centerX, y);

      double childXOffset = xOffset;
      for (var childId in children) {
        int childLeaves = leafCounts[childId] ?? 1;
        positionNode(childId, depth + 1, childXOffset, visited);
        childXOffset += childLeaves * horizontalSpacing;
      }
    }

    positionNode(root.id, 0, 0.0, {});
    _normalizePositions(data.nodes, 100, 80);
  }

  //Normalize : shift all nodes so top-left is at (xOffset, yOffset)
  static void _normalizePositions(List<MindMapNode> nodes, double minX, double minY) {
    if (nodes.isEmpty) return;
    double currentMinX = double.infinity;
    double currentMinY = double.infinity;
    for (var node in nodes) {
      if (node.position.dx < currentMinX) currentMinX = node.position.dx;
      if (node.position.dy < currentMinY) currentMinY = node.position.dy;
    }

    double shiftX = minX - currentMinX;
    double shiftY = minY - currentMinY;

    for (var node in nodes) {
      node.position = Offset(node.position.dx + shiftX, node.position.dy + shiftY);
    }
  }
}
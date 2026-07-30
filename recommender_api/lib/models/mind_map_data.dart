import 'dart:ui';

class MindMapNode {
  final String id;
  final String label;
  final String type;
  Offset position;
  Size size;

  MindMapNode({
    required this.id, 
    required this.label, 
    this.type = 'leaf',
    this.position = Offset.zero, 
    this.size = const Size(150, 60),
    });

  // Factory constructor to build a Node from the parsed JSON dictionary
  factory MindMapNode.fromJson(Map<String, dynamic> json) {
    return MindMapNode(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      type: json['type']?.toString() ?? 'leaf',
      position: Offset.zero, // Calculated later by Layout Engine
      size: const Size(150, 60),
    );
  }
}

class MindMapEdge {
  final String idFrom;
  final String idTo;
  final String? label; // Optional, mainly used for Concept Maps

  MindMapEdge({required this.idFrom, required this.idTo, this.label});

  factory MindMapEdge.fromJson(Map<String, dynamic> json) {
    return MindMapEdge(
      idFrom: json['id_from']?.toString() ?? json['idFrom']?.toString() ?? '',
      idTo: json['id_to']?.toString() ?? json['idTo']?.toString() ?? '',
      label: json['label']?.toString(),
    );
  }
}

class MindMapResponseData {
  final String title;
  final String mapType;
  final List<MindMapNode> nodes;
  final List<MindMapEdge> edges;
  final String mermaidCode;

  MindMapResponseData({
    required this.title,
    required this.mapType,
    required this.nodes,
    required this.edges,
    required this.mermaidCode,
  });

  factory MindMapResponseData.fromJson(Map<String, dynamic> json) {
    return MindMapResponseData(
      title: json['title']?.toString() ?? 'Mind Map',
      mapType: json['map_type']?.toString() ?? 'hierarchical',
      mermaidCode: json['mermaid_code']?.toString() ?? '',
      nodes: (json['nodes'] as List?)?.map((n) => MindMapNode.fromJson(n)).toList() ?? [],
      edges: (json['edges'] as List?)?.map((e) => MindMapEdge.fromJson(e)).toList() ?? [],
    );
  }
}
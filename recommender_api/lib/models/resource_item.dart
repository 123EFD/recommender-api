class ResourceItem {
  final String resourceId;
  final String topic;
  final int durationMin;
  final String type;
  final String content;

  ResourceItem({
    required this.resourceId,
    required this.topic,
    required this.durationMin,
    required this.type,
    required this.content,
  });

  factory ResourceItem.fromJson(Map<String, dynamic> json) {
    // [BLANK 1]: Return a new ResourceItem by mapping the JSON keys to the properties.
    // Hint: The JSON keys from FastAPI are exactly: 
    // 'resource_id', 'topic', 'duration', 'type', and 'content'.
    return ResourceItem(
       // ... your mapping here (e.g. resourceId: json['resource_id'] as String)
      resourceId: json['resource_id'] as String,
      topic: json['topic'] as String,
      durationMin: json['duration_min'] as int,
      type: json['type'] as String,
      content: json['content'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'resource_id': resourceId,
      'topic': topic,
      'duration': durationMin,
      'type': type,
      'content': content,
    };
  }
}
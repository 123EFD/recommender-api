import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/resource_item.dart';

class VideoPlayerWidget extends StatelessWidget {
  final ResourceItem item;

  const VideoPlayerWidget({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // YouTube placeholder with "Watch" button
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_outline, color: Colors.white70, size: 56),
                SizedBox(height: 12),
                Text(item.topic, style: TextStyle(color: Colors.white, fontSize: 16)),
                SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: Icon(Icons.open_in_new),
                  label: Text("Watch on YouTube"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  // [BLANK 2]: Open a YouTube search for this topic
                  // Hint: Use launchUrl(Uri.parse("https://www.youtube.com/results?search_query=${Uri.encodeComponent(item.topic)}"))
                  onPressed: () async {
                    await launchUrl(Uri.parse("https://www.youtube.com/results?search_query=${Uri.encodeComponent(item.topic)}"));
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          // Transcript
        ],
      ),
    );
  }
}
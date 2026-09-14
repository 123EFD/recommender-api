import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bundler_state.dart';
import '../models/resource_item.dart';
import '../widgets/flashcard_deck_widget.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/pyq_solution_widget.dart';

class StudySessionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bundle = context.watch<BundlerState>().currentBundle;

    if (bundle.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text("Your Study Bundle")),
        body: Center(child: Text("No resources found. Try another topic!")),
      );
    }

    final totalMinutes = bundle.fold(0, (sum, item) => sum + item.durationMin);

    // Group items by type
    final flashcards = bundle.where((i) => i.type == 'flashcard').toList();
    final videos = bundle.where((i) => i.type == 'video_chunk' || i.type == 'video').toList();
    final pyqs = bundle.where((i) => i.type == 'pyq_solution').toList();

    // Dynamically build active tabs and their corresponding views
    List<Widget> activeTabs = [];
    List<Widget> activeTabViews = [];

    if (flashcards.isNotEmpty) {
      activeTabs.add(Tab(text: "Flashcards (${flashcards.length})"));
      activeTabViews.add(FlashcardDeckWidget(items: flashcards));
    }
    if (videos.isNotEmpty) {
      activeTabs.add(Tab(text: "Videos (${videos.length})"));
      activeTabViews.add(_buildListView(videos, 'video_chunk'));
    }
    if (pyqs.isNotEmpty) {
      activeTabs.add(Tab(text: "Problems (${pyqs.length})"));
      activeTabViews.add(_buildListView(pyqs, 'pyq_solution'));
    }

    return DefaultTabController(
      length: activeTabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Your Study Bundle"),
          bottom: TabBar(
            tabs: activeTabs,
            isScrollable: true,
          ),
        ),
        body: Column(
          children: [
            // Bundle summary header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              color: Colors.blueAccent.withValues(alpha: 0.1),
              child: Text(
                "${bundle.length} resources • $totalMinutes minutes total",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            // The active tab view
            Expanded(
              child: TabBarView(
                children: activeTabViews,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<ResourceItem> items, String type) {
    // For videos and PYQs, keep the vertical scrolling list view
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final ResourceItem item = items[index];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "${index + 1} of ${items.length}  •  ${item.durationMin} min",
                style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            if (type == 'video_chunk' || type == 'video')
              VideoPlayerWidget(item: item)
            else if (type == 'pyq_solution')
              PyqSolutionWidget(item: item)
            else
              Center(child: Text("Unknown type: ${item.type}")),
            SizedBox(height: 32),
          ],
        );
      },
    );
  }
}
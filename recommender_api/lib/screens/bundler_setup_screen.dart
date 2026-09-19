import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bundler_state.dart';
import 'study_session_screen.dart'; 

class BundlerSetupScreen extends StatefulWidget {
  final String? initialTopic;

  const BundlerSetupScreen({super.key, this.initialTopic});
  
  @override
  _BundlerSetupScreenState createState() => _BundlerSetupScreenState();
}

  // A list of suggested topics for the user to choose from.
  final List<String> _suggestedTopics = const [
    'General Programming',
    'Data Science',
    'Machine Learning',
    'Algorithms',
    'Data Structures',
    'Database',
    'Computer Networks',
    'Software Engineering',
    'Normalization',
    'Memory Allocation',
    'Graph Theory',
    'Pointers in C',
    'Backpropagation',
];

class _BundlerSetupScreenState extends State<BundlerSetupScreen> {
  final TextEditingController _minutesController = TextEditingController(text: "15");
  late final TextEditingController _topicController;

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(text: widget.initialTopic ?? "General Programming");
  }

  @override
  Widget build(BuildContext context) {

    final bundlerState = context.watch<BundlerState>();

    return Container(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("How much time do you have?", style: TextStyle(fontSize: 18)),
            TextField(
              controller: _minutesController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: "e.g. 15"),
            ),
            SizedBox(height: 20),
            Text("Topic", style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _topicController.text),
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _suggestedTopics;
                }
                // Filter suggestions based on what the user types (case-insensitive)
                return _suggestedTopics.where((String option) {
                  return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                _topicController.text = selection;
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                // Keep our main _topicController in sync with user typing
                textEditingController.addListener(() {
                  _topicController.text = textEditingController.text;
                });
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  onChanged: (val) {
                    _topicController.text = val;
                  },
                  decoration: InputDecoration(
                    hintText: "Type or select a topic (e.g. Normalization)",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                );
              },
            ),
            SizedBox(height: 30),
            // Show a spinner if loading, otherwise show the button
            if (bundlerState.isLoading)
              Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: () async {
                  final minutes = int.tryParse(_minutesController.text);
                  final topic = _topicController.text;

                  if (minutes == null || minutes <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Please enter a valid positive number for minutes.")),
                    );
                    return;
                  }
                  
                  if (minutes > 240) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Maximum study duration is 240 minutes (4 hours).")),
                    );
                    return;
                  }

                  await context.read<BundlerState>().fetchBundle(minutes, topic);

                  if (context.mounted && context.read<BundlerState>().errorMessage.isEmpty) {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => StudySessionScreen()));
                  }
                },
                child: Text("Build My Bundle"),
              ),
              
            // Display any error messages from the backend
            if (bundlerState.errorMessage.isNotEmpty) ...[
              SizedBox(height: 20),
              Text(bundlerState.errorMessage, style: TextStyle(color: Colors.red)),
            ]
          ],
        ),
      ),
    );
  }
}
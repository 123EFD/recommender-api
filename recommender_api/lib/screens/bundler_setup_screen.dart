import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bundler_state.dart';
import 'study_session_screen.dart'; 

class BundlerSetupScreen extends StatefulWidget {
  @override
  _BundlerSetupScreenState createState() => _BundlerSetupScreenState();
}

class _BundlerSetupScreenState extends State<BundlerSetupScreen> {
  final TextEditingController _minutesController = TextEditingController(text: "15");
  final TextEditingController _topicController = TextEditingController(text: "General Programming");

  @override
  Widget build(BuildContext context) {

    final bundlerState = context.watch<BundlerState>();

    return Scaffold(
      appBar: AppBar(title: Text("Survival Guide Builder")),
      body: Padding(
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
            DropdownButtonFormField<String>(
              value: _topicController.text.isEmpty ? 'General Programming' : _topicController.text,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                'General Programming',
                'Data Science',
                'Machine Learning',
                'Algorithms',
                'Data Structures',
                'Database',
                'Computer Networks',
                'Software Engineering',
              ].map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  _topicController.text = newValue;
                }
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
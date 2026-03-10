import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Recommender',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100], // Like Tailwind bg-gray-100
      ),
      home: const StudentProfileScreen(),
    );
  }
}

// A custom class to hold the controllers for our dynamic course rows
class CourseEntry {
  TextEditingController nameController = TextEditingController();
  TextEditingController gradeController = TextEditingController();
}

// This is a StatefulWidget because the UI changes (adding/removing courses)
class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  // 1. Setup State Variables (Equivalent to JS variables)
  final TextEditingController _sscController = TextEditingController(text: '3.5');
  final TextEditingController _lastGpaController = TextEditingController(text: '3.0');
  
  int _selectedAttendance = 3;
  int _selectedPreparation = 2;
  
  // This list tracks our dynamic rows
  List<CourseEntry> _courses = [CourseEntry()]; 

  // Hidden AI Features
  final int income = 2, hometown = 1, department = 0, gaming = 2;

  bool _isLoading = false;
  Map<String, dynamic>? _predictionResult; // Holds the AI's response

  // 2. Submit Logic
  Future<void> _analyzeNeeds() async {
    //loading spinner
    setState(() {
      _isLoading = true;
      _predictionResult = null; // Clear previous results
    });

    // Package courses into a list of maps (JSON)
    List<Map<String, dynamic>> coursesArray = _courses.map((course) {
      return {
        "name": course.nameController.text.toUpperCase().trim(),
        "grade": double.tryParse(course.gradeController.text) ?? 0.0,
      };
    }).toList();

    // Create the final JSON payload
    Map<String, dynamic> studentData = {
      "ssc": double.tryParse(_sscController.text) ?? 0.0,
      "last": double.tryParse(_lastGpaController.text) ?? 0.0,
      "attendance": _selectedAttendance,
      "preparation": _selectedPreparation,
      "income": income,
      "hometown": hometown,
      "department": department,
      "gaming": gaming,
      "courses": coursesArray,
    };

    try {
      final url = Uri.parse('http://127.0.0.1:8000/predict');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(studentData),
      );

      if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          //update state 
          setState(() {
            _predictionResult = data;
          });
        } else {
          print("Server error: ${response.statusCode}");
        }
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  //URL launcher logic
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode:LaunchMode.externalApplication);//open in Chrome/Safari
    } else {
      debugPrint('Could not launch $urlString');
    }
  }

  // 3. UI Layout
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Academic Profile'),
        elevation: 0,
      ),
      // SingleChildScrollView prevents keyboard overflow errors!
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0), // Tailwind p-6
        child: Form(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Row for SSC and GPA ---
              Row(
                children: [
                  Expanded(
                    child: _buildTextField('SSC Score (0-4)', _sscController),
                  ),
                  const SizedBox(width: 16), // Gap between inputs
                  Expanded(
                    child: _buildTextField('Last Semester GPA', _lastGpaController),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- Dropdowns ---
              _buildDropdown(
                label: 'Class Attendance',
                value: _selectedAttendance,
                items: const {1: 'Below 40%', 2: '40%-59%', 3: '60%-79%', 4: '80%-100%'},
                onChanged: (val) => setState(() => _selectedAttendance = val!),
              ),
              const SizedBox(height: 16),

              _buildDropdown(
                label: 'Daily Study Preparation',
                value: _selectedPreparation,
                items: const {1: '0-1 hour', 2: '2-3 hours', 3: 'More than 3 hours'},
                onChanged: (val) => setState(() => _selectedPreparation = val!),
              ),
              
              const Divider(height: 40, thickness: 1),
              
              // --- Dynamic Courses Section ---
              const Text('Current Semester Courses', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              // Map over our list of classes to draw the rows
              ..._courses.asMap().entries.map((entry) {
                int index = entry.key;
                CourseEntry course = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: course.nameController,
                          decoration: const InputDecoration(
                            hintText: 'Code (e.g. WIA1006)',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80, // Force a small width for the grade box
                        child: TextFormField(
                          controller: course.gradeController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true), // Pops up number pad!
                          decoration: const InputDecoration(
                            hintText: 'Grade',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          // setState triggers a UI refresh to remove the row!
                          setState(() {
                            _courses.removeAt(index);
                          });
                        },
                      )
                    ],
                  ),
                );
              }),
              
              TextButton(
                onPressed: () {
                  // setState triggers a UI refresh to add a new row!
                  setState(() {
                    _courses.add(CourseEntry());
                  });
                },
                child: const Text('+ Add Another Course'),
              ),

              const SizedBox(height: 24),

              //show loading spinner/result box
              if (_isLoading) 
                  const Center(child: CircularProgressIndicator())
              else if (_predictionResult != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _predictionResult!['needs_resources'] ? Colors.red[50] : Colors.green[50],
                      border: Border.all(
                        color: _predictionResult!['needs_resources'] ? Colors.red[300]! : Colors.green[300]!,
                      ),  
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                    children: [
                      Text(
                        _predictionResult!['message'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _predictionResult!['needs_resources'] ? Colors.red[800] : Colors.green[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Risk Score: ${_predictionResult!['confidence_score']}%",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                  
              // --- Submit Button ---
              SizedBox(
                width: double.infinity, // Full width button
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _analyzeNeeds,
                  child: const Text('Analyze Needs with AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // Helper Widget for Text Fields
  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  // Helper Widget for Dropdowns
  Widget _buildDropdown({
    required String label,
    required int value,
    required Map<int, String> items,
    required void Function(int?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        DropdownButtonFormField<int>(
          value: value,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: items.entries.map((entry) {
            return DropdownMenuItem<int>(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildResourceCard(Map<String, dynamic> resource) {
    IconData icon;
    Color iconColor;

    if (resource['resource_type'] == 'video') {
      //styling based on type
      icon = Icons.play_circle_fill;
      iconColor = Colors.red;
    } else if (resource['resource_type'] == 'book') {
      icon = Icons.menu_book;
      iconColor = Colors.blue;
    } else {
      icon = Icons.article;
      iconColor = Colors.cyanAccent;
    }

  //list items using ListTile widget
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 8.0),
      child : ListTile(
        leading: Icon(icon, color: iconColor, size: 32),
        title: Text(
          resource['title'],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${resource['course_code']} - ${resource['resource_type'].toUpperCase()}", 
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold)
            ),
          
          //resource explanation 
          if (resource['explanation'] != null && resource['explanation'].toString().isNotEmpty )
          ]
        )
      )
    )
  }
}
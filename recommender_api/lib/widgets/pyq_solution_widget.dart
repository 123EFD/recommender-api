import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
//import 'package:pdf/pdf.dart';
//import 'package:pdf/widgets.dart' as pw;
//import 'package:printing/printing.dart';
import '../models/resource_item.dart';

class PyqSolutionWidget extends StatefulWidget {
  final ResourceItem item;
  const PyqSolutionWidget({Key? key, required this.item}) : super(key: key);

  @override
  _PyqSolutionWidgetState createState() => _PyqSolutionWidgetState();
}

class _PyqSolutionWidgetState extends State<PyqSolutionWidget> {
  String? _lensResult;
  bool _isLoadingLens = false;
  String _activeLens = "None";

  // Function to call the Lens Switcher API
  Future<void> _applyLens(String lensType) async {
    setState(() {
      _isLoadingLens = true;
      _activeLens = lensType;
    });

    try {
      final url = Uri.parse('http://localhost:8000/lens/transform');
      final body = jsonEncode({
        "source_text": widget.item.content,
        "lens": lensType
      });

      final response = await http.post(url, headers: {'Content-Type' : 'application/json'},
      body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _lensResult = data['transformed'];
      } else {
        _lensResult = "Error applying lens: ${response.body}";
      }
    } catch (e) {
      _lensResult = "Error applying lens: $e";
    }

    setState(() => _isLoadingLens = false);
  }

  /* Function to generate and save PDF
  Future<void> _exportToPdf() async {
    final pdf = pw.Document();
    
    pdf.addPage(pw.Page(build: (pw.Context context) => pw.Text(widget.item.content)));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async  => pdf.save());
  }
  */

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // PDF Export Button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: Icon(Icons.picture_as_pdf),
              label: Text("Export PDF"),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("PDF export will be available in the next update!")),
                );
              },
            ),
          ),
          SizedBox(height: 16),

          // The original PYQ Content
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(widget.item.content, style: TextStyle(fontSize: 16)),
          ),
          SizedBox(height: 24),

          // Lens Switcher Toggles
          Text("Don't understand? Switch Perspective:", style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _lensButton("analogy", Icons.lightbulb, "Analogy"),
              _lensButton("visual", Icons.account_tree, "Visual Logic"),
              _lensButton("exam", Icons.grading, "Exam Focus"),
            ],
          ),
          SizedBox(height: 24),

          // Lens Result Area
          if (_isLoadingLens)
            Center(child: CircularProgressIndicator())
          else if (_lensResult != null)
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber),
                borderRadius: BorderRadius.circular(12),
              ),
              // If the user selected 'visual', render the Mermaid chart. Otherwise, show normal text.
              child: Text(_lensResult!, style: TextStyle(fontSize: 16)),
            ),
        ],
      ),
    );
  }

  Widget _lensButton(String id, IconData icon, String label) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: _activeLens == id ? Colors.amber : Colors.white,
        foregroundColor: Colors.black87,
      ),
      onPressed: () => _applyLens(id),
    );
  }
}
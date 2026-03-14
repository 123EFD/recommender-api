import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
//import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class PdfChatScreen extends StatefulWidget {
  const PdfChatScreen({super.key});

  @override
  State<PdfChatScreen> createState() => _PdfChatScreenState();
}

class _PdfChatScreenState extends State<PdfChatScreen> {
  List<String> _pdfLibrary = [];

  // IP helper (Use 10.0.2.2 for Android Emulator, 127.0.0.1 for Web/iOS)
  final String _baseUrl = "http://127.0.0.1:8000";

  // --- SEGMENT 2: State Variables ---
  Uint8List? _pdfBytes;
  String _pdfName = "";
  bool _isProcessingPdf = false;

  final TextEditingController _chatController = TextEditingController();
  bool _isAiThinking = false;
  
  //persistent chat history using Map(Dictionary) instead of single List 
  // The 'String' is the filename ; The 'List' is the chat history for that file.
  Map<String, List<Map<String, String>>> _chatSessions = {};
  List<Map<String, String>> _currentActiveChat = []; 

  Future<void> _fetchLibrary() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/library'));

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);

        setState(() {
          _pdfLibrary = data.cast<String>(); 
          //cast<R> used on collections for type checking, more flexible than as keyword
        });
      }
    } catch (e) {
        debugPrint("Library Fetch Error: $e");
    }
  }

  //switching folder logic
  void _loadChatForFile(String filename) {
    setState(() {
      _pdfName = filename;

      if (_chatSessions.containsKey(filename)) {
        //chekc history for the file and load it
        _currentActiveChat = _chatSessions[filename]!;
      } else {
        _chatSessions[filename] = [];
        _currentActiveChat = _chatSessions[filename]!;
      }
    });
  }

  //save history even after restart (encode -> decode)
  Future<void> _saveToDisk() async {
    final prefs = await SharedPreferences.getInstance(); //get access to phone's hard drives
    String jsonString = jsonEncode(_chatSessions);
    await prefs.setString("saved_chat_history", jsonString);//save through key-value pair
  }

  //saves message to the currently active chat 
  void _saveMessage(String role, String text) {
    setState(() {
      _currentActiveChat.add({"role": role, "text": text});
      _chatSessions[_pdfName] = _currentActiveChat;
      _saveToDisk(); //save every time a new message is added
    });
  }

 //load history from disk when app starts
  @override 
  void initState() {
    super.initState();
    _loadCabinetFromDisk(); //initiate the hard drive for chat memory
    _fetchLibrary(); //fetch pdf library from backend when app starts
  }

  Future<void> _loadCabinetFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString("saved_chat_history");

    if (jsonString != null) {
      Map<String, dynamic> decodedData = jsonDecode(jsonString); //return dynamic type
      
      //just imagine cabinet as pdf history storage, contain chat history 
      Map<String, List<Map<String, String>>> restoredCabinet = {};

      decodedData.forEach((key, value) {
        restoredCabinet[key] = List<Map<String, String>>.from(
          (value as List).map((item) => Map<String, String>.from(item))
        );
      });

      // 4. Update state to restore memory
      setState(() {
        _chatSessions = restoredCabinet;
      });
    }
  }

  //  PDF Upload Logic 
  Future<void> _pickAndUploadPdf() async {
    // Open the phone's native file browser
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, //load file into memory
    );

    if (result != null) {
      setState(() {
        _pdfBytes = result.files.single.bytes;
        _pdfName = result.files.single.name;
        _isProcessingPdf = true;
      });

      try {
        var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/upload-pdf'));
        //send bytes since path will be block by web 
        request.files.add(
          http.MultipartFile.fromBytes(
            'file', 
            _pdfBytes!,
            filename: _pdfName
            )
        );

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);
          
          _loadChatForFile(data['filename']);

          if (_currentActiveChat.isEmpty) {
            _saveMessage("ai", "✅ Successfully loaded ${data['chunks_processed']} chunks. What would you like to know?");
          }
        } 
      } catch (e) {
        _saveMessage("ai", "❌ Upload failed: $e");
      } finally {
        setState(() => _isProcessingPdf = false);
      }
    }
  }

  // --- SEGMENT 4: AI Chat Logic ---
  Future<void> _sendMessage() async {
    String question = _chatController.text.trim();
    if (question.isEmpty || _pdfName.isEmpty) return;

    _saveMessage("user", question);
    setState(() {
      _chatController.clear();
      _isAiThinking = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "question": question,
          "filename": _pdfName
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          _saveMessage("ai", data['answer']);
        });
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      _saveMessage("ai", "⚠️ AI Connection Error: $e");
    } finally {
      setState(() => _isAiThinking = false);
    }
  }

  // --- SEGMENT 5: The UI Layout ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF AI Workspace'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _isProcessingPdf ? null : _pickAndUploadPdf,
            tooltip: 'Upload PDF',
          )
        ],
      ),

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Your PDF Library', 
                style: TextStyle(color: Colors.white, fontSize: 24)
              ),
            ),

            if (_pdfLibrary.isEmpty) 
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("No PDFs uploaded yet.", style: TextStyle(color: Colors.orangeAccent)),
              ),

              ..._pdfLibrary.map((filename) {
                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                  title: Text(filename, style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.chevron_right, size: 16),
                  onTap: () {
                    Navigator.pop(context);

                    _loadChatForFile(filename);
                  },
                );
              }),
          ],
        ),
      ),
      
      body: Row(
        children: [
          // TOP HALF: The PDF Viewer
          Expanded(
            flex: 5, 
            child: Container(
              color: Colors.grey[300],
              child: _isProcessingPdf
                  ? const Center(child: CircularProgressIndicator())
                  : _pdfBytes != null
                      ? SfPdfViewer.memory(_pdfBytes!)
                      : const Center(
                          child: Text(
                            "Tap the upload icon to select a PDF", 
                            style: TextStyle(color: Colors.grey)
                          )
                        ),
            ),
          ),

          // BOTTOM HALF: The Chat Interface
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // The Scrollable Message List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _currentActiveChat.length,
                      itemBuilder: (context, index) {
                        var msg = _currentActiveChat[index];
                        bool isUser = msg['role'] == 'user';
                        
                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isUser ? Colors.blue[600] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: isUser 
                              ? Text(
                                  msg['text']!, 
                                  style: const TextStyle(color: Colors.white)
                                )
                              : MarkdownBody(
                                  data: msg['text']!,
                                  styleSheet: MarkdownStyleSheet(
                                    p: const TextStyle(fontSize: 14),
                                  ),
                              ), // Renders AI Markdown perfectly
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // "Thinking" Indicator
                  if (_isAiThinking)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "AI is searching notes...", 
                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)
                      ),
                    ),

                  // The Bottom Input Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey[300]!))
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            decoration: InputDecoration(
                              hintText: _pdfName.isEmpty 
                                  ? "Upload a PDF first..." 
                                  : "Ask about the PDF...",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20)
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            enabled: _pdfName.isNotEmpty,
                            onSubmitted: (_) => _sendMessage(), 
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: _pdfName.isEmpty ? Colors.grey : Colors.blue[600],
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 20),
                            onPressed: _pdfName.isEmpty ? null : _sendMessage,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
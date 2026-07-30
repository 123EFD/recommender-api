import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import 'theme/glassmorphism.dart';
import 'mind_map_screen.dart';

class PdfChatScreen extends StatefulWidget {
  final bool isFullScreen;
  const PdfChatScreen({super.key, this.isFullScreen = false});

  @override
  State<PdfChatScreen> createState() => _PdfChatScreenState();
}

class _PdfChatScreenState extends State<PdfChatScreen> with TickerProviderStateMixin {
  List<String> _pdfLibrary = [];
  final String _baseUrl = "https://kasshier-ai-study-suite.hf.space";

  Uint8List? _pdfBytes;
  String _pdfName = "";
  bool _isProcessingPdf = false;

  final TextEditingController _chatController = TextEditingController();
  bool _isAiThinking = false;

  List<Map<String, String>> _currentActiveChat = [];

  late AnimationController _sidebarController;
  late Animation<double> _sidebarAnimation;
  bool _isSidebarOpen = false;
  bool _isGeneratingMap = false;

  @override
  void initState() {
    super.initState();
    _fetchLibrary();
    _sidebarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _sidebarAnimation = CurvedAnimation(
      parent: _sidebarController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
      if (_isSidebarOpen) {
        _fetchLibrary(); // refresh library when opened
        _sidebarController.forward();
      } else {
        _sidebarController.reverse();
      }
    });
  }

  Future<void> _loadChatForFile(String filename) async {
    setState(() {
      _pdfName = filename;
      _currentActiveChat = [];
    });

    try {
      final response = await http.get(Uri.parse('$_baseUrl/get-chat/$filename'));

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _currentActiveChat = data.map((item) => {
            "role": item['role'].toString(),
            "text": item['text'].toString()
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Failed to load chat for $filename: $e");
    }
  }

  Future<void> _waitForProcessing(String filename) async {
    bool isDone = false;

    while (!isDone) {
      await Future.delayed(const Duration(seconds: 2));

      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/job-status/${Uri.encodeComponent(filename)}')
        );

        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);

          if (data['status'] == 'completed') {
            isDone = true;
          } else if (data['status'] == 'failed') {
            setState(() {
              _currentActiveChat = [
                {"role": "ai", "text": "❌ The AI failed to read this document."}
              ];
            });
            isDone = true;
          }
        }
      } catch (e) {
        debugPrint("Error waiting for processing: $e");
      }
    }
  }

  Future<void> _saveMessage(String role, String text) async {
    setState(() {
      _currentActiveChat.add({"role": role, "text": text});
    });

    try {
      await http.post(
        Uri.parse('$_baseUrl/save-message'),
        headers: { 'Content-type' : 'application/json' },
        body: jsonEncode({
          "filename": _pdfName,
          "role": role,
          "text": text,
        }),
      );
    } catch (e) {
      debugPrint("Failed to save message: $e");
    }
  }

  Future<void> _fetchLibrary() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/library'));

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        debugPrint("FLUTTER RECEIVED THIS LIBRARY DATA: $data");

        setState(() {
          _pdfLibrary = List<String>.from(data);
        });
      }
    } catch (e) {
      debugPrint("Library Fetch Error: $e");
    }
  }

  Future<void> _pickAndUploadPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null) {
      setState(() {
        _pdfBytes = result.files.single.bytes;
        _pdfName = result.files.single.name;
        _isProcessingPdf = true;
      });

      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/upload-pdf'),
        );
        request.files.add(
          http.MultipartFile.fromBytes('file', _pdfBytes!, filename: _pdfName),
        );

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);

          setState(() {
            _pdfName = data['filename'];
            if (!_pdfLibrary.contains(_pdfName)) {
              _pdfLibrary.insert(0, _pdfName);
            }

            _currentActiveChat = [
              {"role": "ai", "text": "⏳ AI is reading and memorizing this document. Please wait..."}
            ];
          });

          await _waitForProcessing(data['filename']);
          await _loadChatForFile(data['filename']);

          if (_currentActiveChat.isEmpty) {
            _saveMessage(
              "ai",
              "✅ Successfully loaded ${data['chunks_processed']} chunks. What would you like to know?",
            );
          }
        }
      } catch (e) {
        _saveMessage("ai", "❌ Upload failed: $e");
      } finally {
        setState(() => _isProcessingPdf = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    String question = _chatController.text.trim();
    if (question.isEmpty || _pdfName.isEmpty) return;

    _saveMessage("user", question);

    setState(() {
      _chatController.clear();
      _isAiThinking = true;
      _currentActiveChat.add({"role" : "ai", "text":""});
    });

    try {
      var request = http.Request('POST', Uri.parse('$_baseUrl/chat'));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({"question":question, "filename": _pdfName}); 

      var response = await http.Client().send(request);

      if (response.statusCode == 200) {
        setState(() => _isAiThinking = false);

        await for (var chunk in response.stream.transform(utf8.decoder)) {
          setState(() {
            _currentActiveChat.last["text"] = _currentActiveChat.last['text']! + chunk;
          });
        }
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      setState(() {
        _currentActiveChat.last['text'] = "⚠️ AI Connection Error: $e";
      });
    } finally {
      setState(() => _isAiThinking = false);
    }
  }

  Future<void> _deletePdf(String filename) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/delete-pdf/${Uri.encodeComponent(filename)}')
      );

      if (response.statusCode == 200) {
        setState(() {
          _pdfLibrary.remove(filename);
          if (_pdfName == filename) {
            _pdfName = "";
            _currentActiveChat = [];
          }
        });
      }
    } catch (e) {
      debugPrint("Failed to delete PDF: $e");
    }
  }

  Future<void> _clearChatHistory() async {
      if (_pdfName.isEmpty) return;

      setState(() {
        _currentActiveChat = [];
      });

      try {
        final response = await http.delete(
          Uri.parse('$_baseUrl/clear-chat/${Uri.encodeComponent(_pdfName)}')
        );

        if (response.statusCode == 200) {
          _saveMessage("ai", "✅ Chat history cleared.");
        } else {
          debugPrint("Failed to clear chat history: ${response.statusCode}");
        }
      } catch (e) {
          debugPrint("Clear chat error: $e");
      }
  }

  Future<void> _renamePdf(String oldFilename, String newFilename) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/rename-pdf'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "old_filename": oldFilename,
          "new_filename": newFilename
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String updatedName = data['new_filename'];

        setState(() {
          int index = _pdfLibrary.indexOf(oldFilename);
          if ( index != -1) _pdfLibrary[index] = updatedName;
          if (_pdfName == oldFilename) _pdfName = updatedName;
        });
      }
    } catch (e) {
      debugPrint("Failed to rename PDF: $e");
    }
  }

  Future<void> _showRenameDialog(String oldFilename) async {
    TextEditingController renameController = TextEditingController(
      text: oldFilename.replaceAll('.pdf', '')
    );

    return showDialog(
      context: context, 
      builder: (context) {
        return AlertDialog(
          title: const Text("Rename PDF"),
          content: TextField(
            controller: renameController,
            decoration: const InputDecoration(
              hintText: "Enter new name",
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  String newName = renameController.text.trim();
                  if (newName.isNotEmpty) {
                    Navigator.pop(context);
                    await _renamePdf(oldFilename, newName);
                  }
                },
                child: const Text("Rename"),
              ),
          ],
        );
      }
    );
  }

  Future<void> _generateMindMap({
    required String source, 
    required String mapType,
    int? pageStart,
    int? pageEnd,
  }) async {
    //show loading indicator 
    setState(() {
      _isGeneratingMap = true;
    });

    try {
      //biuld request and send the http.post()
      final response = await http.post(
        Uri.parse('$_baseUrl/generate-mind-map'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "filename": _pdfName,
          "source": source,
          "map_type": mapType,
          "page_start": pageStart,
          "page_end": pageEnd
        }),
      );

      //parse response JSON include nodes, edges, mermaid_code
      if (response.statusCode == 200) {
        //parse the JSON string into Dart objects
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        //navigate to MindMapScree, pass the typed data
        if (mounted) {
          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (_) => MindMapScreen(data: jsonResponse),
            ),
          );
        }
      } else {
        throw Exception("Failed to generate mind map: ${response.body}");
      }
    } catch (e) {
      //show Snackbar or dialog to inform user of failure
      debugPrint("Failed to generate mind map: $e");
    } finally {
      setState(() {
        _isGeneratingMap = false;
      });
    }
  }

  void _showMindMapDialog() {
    int selectedSourceIndex = 0; //0=Chat history, 1 = PDF range
    String selectedMapType = 'hierarchical';
    final pageStartController = TextEditingController();
    final pageEndController = TextEditingController();

    final mapTypes = [
    {'id': 'hierarchical', 'label': 'Hierarchical', 'icon': Icons.account_tree},
    {'id': 'flowchart',    'label': 'Flowchart',    'icon': Icons.linear_scale},
    {'id': 'bubble',       'label': 'Bubble Map',   'icon': Icons.bubble_chart},
    {'id': 'tree',         'label': 'Tree Map',     'icon': Icons.park_outlined},
    {'id': 'concept',      'label': 'Concept Map',  'icon': Icons.hub_outlined},
  ];

  showDialog(
    context: context,
    builder: (dialogContext) {
      //use StatefulBuilder to manage the dialog state and update own UI instead of entire screen
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);

          return AlertDialog(
            //glassmorphism background color from theme
            title: const Text('Generate Mind Map'),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  //Source Selection Tabs
                  const Text('Source', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      _buildSourceTab(label: 'Chat History', index: 0, selectedIndex: selectedSourceIndex, onTap: () {
                        setDialogState(() {
                          selectedSourceIndex = 0;
                        });
                      }),
                      _buildSourceTab(label: 'PDF Range', index: 1, selectedIndex: selectedSourceIndex, onTap: () {
                        setDialogState(() {
                          selectedSourceIndex = 1;
                        });
                      })
                    ]
                  ),

                  const SizedBox(height: 16),

                  //PDF Range Inputs tabs
                  if (selectedSourceIndex == 1) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pageStartController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Start Page',
                              border: OutlineInputBorder(),
                            ),
                          )
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: pageEndController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'End Page',
                              border: OutlineInputBorder(),
                            ),
                          )
                        )
                      ],
                      ),
                      const SizedBox(height: 16),
                  ],

                  //Map Type Selector
                  const Text('Map Type', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing : 8,
                    runSpacing: 8,
                    children: mapTypes.map((type) {
                      final isSelected = type['id'] == selectedMapType;
                      return GestureDetector(
                        onTap: () {
                          //update selectedMapType using setDialogState
                          setDialogState(() {
                            selectedMapType = type['id'] as String;
                          });
                        },
                        child: Container(
                          width: 130,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            //primary color gradient if selected, else neutral background
                            gradient: isSelected ? LinearGradient(
                              colors: [Colors.blue[600]!, Colors.blue[400]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ) : null,
                            color: isSelected ? null : theme.colorScheme.surface.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(type['icon'] as IconData),
                              const SizedBox(height: 4),
                              Text(type['label'] as String, textAlign:
                              TextAlign.center),
                            ],
                            ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              ),

              //Actions Buttons
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    //call the mind map generation function with selected options
                    _generateMindMap(
                      source : selectedSourceIndex == 0 ? 'chat_history' : 'pdf_range',
                      mapType: selectedMapType,
                      pageStart : int.tryParse(pageStartController.text),
                      pageEnd : int.tryParse(pageEndController.text)
                    );
                  },
                  child: const Text('Generate Mind Map'),
                ),
              ],
          );
        },
      );
    },
    );
  }

  Widget _buildSourceTab({
    required String label,
    required int index,
    required int selectedIndex,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isSelected = index == selectedIndex;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[400]!],
                  )
                : null,
            color: isSelected ? null : theme.colorScheme.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.blue : theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : theme.colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('PDF AI Workspace', style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: _toggleSidebar,
          ),
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.5),
              ),
            ),
          ),
          actions: [
            if (widget.isFullScreen)
              IconButton(
                icon: const Icon(Icons.fullscreen_exit),
                tooltip: 'Back to Split View',
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            if (_pdfName.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.cleaning_services_rounded),
                tooltip: 'New Chat',
                onPressed: _clearChatHistory,
              ),
            if (_pdfName.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.account_tree_outlined),
                tooltip: 'Export as Mind Map',
                onPressed: () {
                  _showMindMapDialog();
                }
              ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: _isProcessingPdf ? null : _pickAndUploadPdf,
              tooltip: 'Upload PDF',
            ),
          ],
        ),
        body: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Main Content
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 800) {
                    return Row(
                      children: [
                        Expanded(flex: 5, child: _buildPdfViewer()),
                        Expanded(flex: 5, child: _buildChatInterface()),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        TabBar(
                          labelColor: theme.colorScheme.primary,
                          unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          indicatorColor: theme.colorScheme.primary,
                          indicatorWeight: 3,
                          tabs: const [
                            Tab(icon: Icon(Icons.picture_as_pdf), text: "Document"),
                            Tab(icon: Icon(Icons.chat), text: "Chat"),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [_buildPdfViewer(), _buildChatInterface()],
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ),

            // Sidebar Overlay
            AnimatedBuilder(
              animation: _sidebarAnimation,
              builder: (context, child) {
                if (_sidebarAnimation.value == 0) {
                  return const SizedBox.shrink();
                }
                return GestureDetector(
                  onTap: _toggleSidebar,
                  child: Opacity(
                    opacity: _sidebarAnimation.value * 0.5,
                    child: Container(
                      color: Colors.black,
                    ),
                  ),
                );
              },
            ),

            // Animated Sidebar
            AnimatedBuilder(
              animation: _sidebarAnimation,
              builder: (context, child) {
                if (_sidebarAnimation.value == 0) {
                  return const SizedBox.shrink();
                }
                return FractionalTranslation(
                  translation: Offset(_sidebarAnimation.value - 1.0, 0),
                  child: child,
                );
              },
              child: SizedBox(
                width: 300,
                height: double.infinity,
                child: GlassContainer(
                  child: Material(
                    color: Colors.transparent,
                    child: SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary.withValues(alpha: 0.8),
                                  theme.colorScheme.secondary.withValues(alpha: 0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Text(
                              'Your PDF Library',
                              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (_pdfLibrary.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                "No PDFs uploaded yet.",
                                style: TextStyle(color: Colors.orangeAccent, fontSize: 18),
                              ),
                            ).animate().fadeIn(duration: 400.ms),
                          Expanded(
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: _pdfLibrary.length,
                              itemBuilder: (context, index) {
                                String filename = _pdfLibrary[index];
                                return ListTile(
                                  leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                                  title: Text(filename, style: const TextStyle(fontWeight: FontWeight.w500)),
                                  trailing: PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 20),
                                    onSelected: (value) {
                                      if (value == 'rename') {
                                        _showRenameDialog(filename);
                                      } else if (value == 'delete') {
                                        _deletePdf(filename);
                                      }
                                    },
                                    itemBuilder: (BuildContext context) => [
                                      const PopupMenuItem(
                                        value: 'rename',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 18, color: Colors.blue),
                                            SizedBox(width: 8),
                                            Text("Rename"),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, size: 18, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text("Delete", style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    _toggleSidebar();
                                    _loadChatForFile(filename);
                                  },
                                ).animate().fadeIn(delay: (50 * index).ms, duration: 400.ms).slideX(begin: -0.2, end: 0);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfViewer() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        gradient: _pdfName.isEmpty ? LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surface.withValues(alpha: 0.8),
          ],
        ) : null,
      ),
      child: _isProcessingPdf
          ? const Center(child: CircularProgressIndicator())
          : _pdfName.isNotEmpty
          ? SfPdfViewer.network(
            '$_baseUrl/get-pdf/${Uri.encodeComponent(_pdfName)}',
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.picture_as_pdf, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text(
                    "Tap the upload icon to add a PDF",
                    style: TextStyle(fontSize: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }

  Widget _buildChatInterface() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _currentActiveChat.length,
              itemBuilder: (context, index) {
                var msg = _currentActiveChat[index];
                bool isUser = msg['role'] == 'user';

                Widget messageBubble = isUser
                    ? Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[600]!, Colors.blue[400]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16).copyWith(bottomRight: const Radius.circular(4)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(msg['text']!, style: const TextStyle(color: Colors.white)),
                      )
                    : Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: GlassContainer(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: MarkdownBody(
                              data: msg['text']!,
                              styleSheet: MarkdownStyleSheet(
                                p: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
                              ),
                            ),
                          ),
                        ),
                      );

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: messageBubble,
                ).animate()
                 .fadeIn(duration: 300.ms)
                 .slideX(begin: isUser ? 0.2 : -0.2, end: 0, curve: Curves.easeOutCubic);
              },
            ),
          ),

          if (_isAiThinking)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("AI is thinking", style: TextStyle(color: Colors.grey)),
                  const SizedBox(width: 8),
                  Row(
                    children: List.generate(3, (index) => 
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ).animate(onPlay: (controller) => controller.repeat())
                         .fadeIn(duration: 300.ms)
                         .then(delay: (150 * index).ms)
                         .fadeOut(duration: 300.ms),
                      )
                    ),
                  )
                ],
              ),
            ),

          GlassContainer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.5),
                border: Border(top: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.1))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      decoration: InputDecoration(
                        hintText: _pdfName.isEmpty ? "Upload a PDF first..." : "Ask about the PDF...",
                        hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                        filled: true,
                        fillColor: theme.colorScheme.surface.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      enabled: _pdfName.isNotEmpty,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: _pdfName.isEmpty ? null : LinearGradient(
                        colors: [Colors.blue[600]!, Colors.blue[400]!],
                      ),
                      color: _pdfName.isEmpty ? Colors.grey : null,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _pdfName.isEmpty ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

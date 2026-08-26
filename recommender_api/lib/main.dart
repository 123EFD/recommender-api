import 'screens/home_screen.dart';
import 'pdf_chat_screen.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'theme/app_theme.dart';
import 'theme/glassmorphism.dart';
import 'widgets/grid_painter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'services/bundler_state.dart';
import 'screens/bundler_setup_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => BundlerState(),
      child: const MyApp(),
    )
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void toggleTheme(BuildContext context) {
    final _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.toggleTheme();
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Recommender',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: const MainNavigationScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final List<Widget> screens = [
      HomeScreen(onNavigate: (index) {
        setState(() {
          _selectedIndex = index;
        });
      }),
      const StudentProfileScreen(),
      BundlerSetupScreen(),
      const PdfChatScreen(isFullScreen: true),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true, // Let body flow under AppBar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: AppBar(
              title: const Text('AI Study Suite'),
              elevation: 0,
              backgroundColor: isDark 
                  ? Colors.black.withOpacity(0.5) 
                  : const Color(0xFFFFFDE7).withOpacity(0.5),
              foregroundColor: isDark ? Colors.blueAccent : Colors.blue[900],
              actions: [
                IconButton(
                  icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                  onPressed: () {
                    MyApp.toggleTheme(context);
                  },
                  tooltip: 'Toggle Theme',
                ),
              ],
            ),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: isDark ? Colors.black87 : const Color(0xFFFFFDE7),
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: isDark ? Colors.blueAccent : Colors.blue[900], 
                  fontSize: 24,
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home_outlined, color: isDark ? Colors.blueAccent : Colors.blue[800]),
              title: const Text('Home'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.psychology_outlined, color: isDark ? Colors.blueAccent : Colors.blue[800]),
              title: const Text('Recommender'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.inventory_2_outlined, color: isDark ? Colors.blueAccent : Colors.blue[800]),
              title: const Text('Bundle'),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.chat_bubble_outline, color: isDark ? Colors.blueAccent : Colors.blue[800]),
              title: const Text('PDF Chat'),
              selected: _selectedIndex == 3,
              onTap: () {
                setState(() => _selectedIndex = 3);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: CustomPaint(
        painter: GridPainter(isDark: isDark),
        child: SafeArea( // Push content below the transparent appbar
          child: IndexedStack(
            index: _selectedIndex,
            children: screens,
          ),
        ),
      ),
    );
  }
}

class CourseEntry {
  TextEditingController nameController = TextEditingController();
  TextEditingController gradeController = TextEditingController();
}

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final TextEditingController _sscController = TextEditingController(text: '3.5');
  final TextEditingController _lastGpaController = TextEditingController(text: '3.0');

  int _selectedAttendance = 3;
  int _selectedPreparation = 2;
  List<CourseEntry> _courses = [CourseEntry()];
  final int income = 2, hometown = 1, department = 0, gaming = 2;
  bool _isLoading = false;
  Map<String, dynamic>? _predictionResult;

  Future<void> _analyzeNeeds() async {
    setState(() {
      _isLoading = true;
      _predictionResult = null;
    });

    List<Map<String, dynamic>> coursesArray = _courses.map((course) {
      return {
        "name": course.nameController.text.toUpperCase().trim(),
        "grade": double.tryParse(course.gradeController.text) ?? 0.0,
      };
    }).toList();

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
      // Target LOCAL backend to test the new DAG algorithm!
      final url = Uri.parse('http://localhost:8000/predict');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(studentData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GlassContainer(
          borderRadius: 0,
          child: SizedBox.expand(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Student Academic Profile',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.local_fire_department, color: Colors.orange),
              tooltip: "High-Yield Heatmap",
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PdfChatScreen(isFullScreen: true,)
                ),
              );
            },
          ),
        ],
      ),
      endDrawer: Drawer(
        width: 350,
        child: Container(
          color: isDark ? const Color(0xFF16213E) : Colors.white,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.only(top: 50, left: 16, bottom: 16),
                width: double.infinity,
                color: isDark ? Colors.black87 : Colors.blue[50],
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orange, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      "Peer-Validated Heatmap",
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<http.Response>(
                  future: http.get(Uri.parse('http://localhost:8000/api/heatmap')), // Target LOCAL backend
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text("Error loading heatmap: ${snapshot.error}", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)));
                    } else if (snapshot.hasData) {
                      if (snapshot.data!.statusCode == 200) {
                        final List<dynamic> items = jsonDecode(snapshot.data!.body);
                        return ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return ListTile(
                              leading: Text("#${index + 1}", style: GoogleFonts.shareTechMono(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold)),
                              title: Text(item['title'] ?? 'Unknown', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                              subtitle: Text("Wilson Score: ${(item['wilson_score'] * 100).toStringAsFixed(1)}% | Struggling Attempts: ${item['total_struggling_attempts']}", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12)),
                              trailing: IconButton(
                                icon : Icon(
                                  item['type'] == 'video' ? Icons.play_circle_fill : Icons.article,
                                  color: isDark ? Colors.blueAccent : Colors.blue[300],
                                  size: 28,
                                ),
                                onPressed: () async {
                                  //check if have direct URL
                                  final urlString = item['url'];
                                  if (urlString != null && urlString.isNotEmpty) {
                                    final Uri url = Uri.parse(urlString);
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(url, mode: LaunchMode.externalApplication);
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (content) => BundlerSetupScreen(),
                                        ),
                                      );
                                    }
                                  }
                                }
                              )
                            );
                          },
                        );
                      } else {
                        // Show the actual error from the server instead of generic text
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(), // Loading button/indicator above text
                              const SizedBox(height: 16),
                              Text("Server Error ${snapshot.data!.statusCode}\nIs your backend running?", 
                                textAlign: TextAlign.center,
                                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                            ],
                          ),
                        );
                      }
                    } else {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text("Heatmap Loading...\n(Wilson Score Algorithm Pending)", 
                              textAlign: TextAlign.center,
                              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                          ],
                        ),
                      );
                    }
                  }
                ),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        color: Colors.transparent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassContainer(
                  borderRadius: 16,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildTextField('SSC Score (0-4)', _sscController)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField('Last Semester GPA', _lastGpaController)),
                          ],
                        ),
                        const SizedBox(height: 16),
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                GlassContainer(
                  borderRadius: 16,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Semester Courses',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ..._courses.asMap().entries.map((entry) {
                          int index = entry.key;
                          CourseEntry course = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: course.nameController,
                                    decoration: InputDecoration(
                                      hintText: 'Code (e.g. WIA1006)',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      filled: true,
                                      fillColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 90,
                                  child: TextFormField(
                                    controller: course.gradeController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      hintText: 'Grade',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      filled: true,
                                      fillColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.redAccent),
                                  onPressed: () {
                                    setState(() { _courses.removeAt(index); });
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                        TextButton.icon(
                          onPressed: () {
                            setState(() { _courses.add(CourseEntry()); });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Another Course'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()).animate().fadeIn()
                else if (_predictionResult != null)
                  GlassContainer(
                    borderRadius: 16,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _predictionResult!['needs_resources'] 
                          ? [Colors.redAccent.withValues(alpha: isDark ? 0.2 : 0.1), Colors.redAccent.withValues(alpha: isDark ? 0.1 : 0.05)]
                          : [Colors.greenAccent.withValues(alpha: isDark ? 0.2 : 0.1), Colors.greenAccent.withValues(alpha: isDark ? 0.1 : 0.05)],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            _predictionResult!['message'],
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _predictionResult!['needs_resources'] 
                                  ? (isDark ? Colors.red[300] : Colors.red[800]) 
                                  : (isDark ? Colors.green[300] : Colors.green[800]),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Risk Score: ${_predictionResult!['confidence_score']}%",
                            style: GoogleFonts.inter(fontSize: 14),
                          ),
                          if (_predictionResult!['resource_links'] != null &&
                              (_predictionResult!['resource_links'] as List).isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text(
                              'Recommended Resources:',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            ...(_predictionResult!['resource_links'] as List).map((res) {
                              return _buildResourceCard(res as Map<String, dynamic>);
                            }),
                          ],
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[600]!, Colors.blue[400]!],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _analyzeNeeds,
                      child: Text(
                        'Analyze Needs with AI',
                        style: GoogleFonts.inter(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required int value,
    required Map<int, String> items,
    required void Function(int?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: value,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
          ),
          items: items.entries.map((entry) {
            return DropdownMenuItem<int>(value: entry.key, child: Text(entry.value));
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
      icon = Icons.play_circle_fill;
      iconColor = Colors.redAccent;
    } else if (resource['resource_type'] == 'book') {
      icon = Icons.menu_book;
      iconColor = Colors.blueAccent;
    } else {
      icon = Icons.article;
      iconColor = Colors.cyan;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: GlassContainer(
        borderRadius: 12,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            hoverColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            onTap: () => _launchURL(resource['url']),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(icon, color: iconColor, size: 36),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resource['title'],
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${resource['course_code']} - ${resource['resource_type'].toUpperCase()}",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (resource['explanation'] != null && resource['explanation'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              resource['explanation'],
                              style: GoogleFonts.inter(fontStyle: FontStyle.italic, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SplitScreenTest extends StatelessWidget {
  const SplitScreenTest({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
              ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
              : [Colors.grey[100]!, Colors.blue[50]!],
          ),
        ),
        child: Row(
          children: [
            const Expanded(flex: 1, child: StudentProfileScreen()),
            Container(
              width: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.purpleAccent.withValues(alpha: 0.1),
                    Colors.purpleAccent,
                    Colors.purpleAccent.withValues(alpha: 0.1),
                  ],
                ),
              ),
            ),
            const Expanded(flex: 1, child: PdfChatScreen()),
          ],
        ),
      ),
    );
  }
}

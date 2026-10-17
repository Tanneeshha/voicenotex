import 'package:flutter/material.dart';
import '../../../core/services/style_service.dart';
import '../../../core/services/api_service.dart';
import '../../speech_ai/screens/speech_screen.dart';
import '../screens/ai_screen.dart';
import '../../notes/screens/notes_screen.dart';
import '../widgets/lecture_dialog.dart';
import '../widgets/ai/style_dialog.dart';
import 'lecture_detail_screen.dart';
import '../../profile/screens/profile_screen.dart';
import 'package:intl/intl.dart';

// UI Colors matched to the uploaded screenshot
const Color primaryDark = Color(0xFF162544); // The deep blue of text and FAB
const Color heroStart = Color(0xFF11254D); // Dark left side of hero
const Color heroEnd = Color(0xFF236B8E); // Tealish right side of hero
const Color iconTeal = Color(0xFF4ACFBE); // The teal of the graduation cap
const Color textMuted = Color(0xFF8B94A3); // Gray text
const Color borderLight = Color(0xFFF0F1F5); // Light borders for cards
const Color starYellow = Color(0xFFFFC107); // Yellow for favorites
const Color textPrimary = Color(0xFF1C2D49);
const Color textSecondary = Color(0xFF64748B);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> get _selectedStyles => StyleService.selectedStyles;
  String? get userEmail => StyleService.currentUserEmail;

  List<dynamic> _lectures = [];
  bool _isLoading = true;
  bool _showFavoritesOnly = false;
  
  int _totalLectures = 0;
  int _totalFavorites = 0;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _loadStats(); // Fire and forget
      await _loadLectures(); // Wait for primary data
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStats() async {
    if (userEmail == null) return;
    final res = await ApiService.getUserStats(userEmail!);
    if (res["success"] == true && mounted) {
      final data = res["data"];
      setState(() {
        // We sync this, but we'll also rely on _lectures.length for 100% accuracy on this screen
        _totalFavorites = data["favorites"] ?? 0;
      });
    }
  }

  Future<void> _loadLectures() async {
    if (userEmail == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final res = await ApiService.getLectures(userEmail!, favoritesOnly: _showFavoritesOnly);

      if (res["success"] == true && mounted) {
        setState(() {
          _lectures = res["data"] is List ? res["data"] : [];
          _totalLectures = _lectures.length; // Ensure 100% accurate live count
          _totalFavorites = _lectures.where((l) => l['is_favorite'] == true).length;
        });
      }
    } catch (e) {
      debugPrint("Error loading lectures: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> lecture) async {
    final lectureId = lecture["lecture_id"]?.toString();
    if (lectureId == null) return;
    final current = lecture["is_favorite"] == true;

    // Optimistic UI update
    setState(() {
      lecture["is_favorite"] = !current;
      if (!current) {
        _totalFavorites++;
      } else {
        _totalFavorites--;
      }
    });

    final res = await ApiService.toggleFavorite(
      lectureId: lectureId,
      email: userEmail!,
      isFavorite: !current,
    );

    if (res["success"] != true && mounted) {
      // Revert if failed
      setState(() {
        lecture["is_favorite"] = current;
        if (current) {
          _totalFavorites++;
        } else {
          _totalFavorites--;
        }
      });
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _getUserDisplayName() {
    final raw = userEmail?.split('@')[0] ?? "Student";
    return raw[0].toUpperCase() + raw.substring(1).replaceAll(RegExp(r'[^a-zA-Z]'), ' ');
  }

  void _showStartLectureDialog() {
    showDialog(
      context: context,
      builder: (_) => LectureDialog(
        onStart: (title, code, instructor) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SpeechScreen(
                lectureTitle: title,
                courseCode: code,
                instructor: instructor,
              ),
            ),
          ).then((_) {
            _loadData();
          });
        },
      ),
    );
  }

  void _showSearchDialog() {
    final searchController = TextEditingController();
    List<dynamic> searchResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Search lectures, notes, subjects...",
                        prefixIcon: const Icon(Icons.search_rounded, color: primaryDark),
                        suffixIcon: isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: primaryDark)),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: (query) async {
                        if (query.trim().isEmpty) {
                          setModalState(() => searchResults = []);
                          return;
                        }
                        setModalState(() => isSearching = true);
                        final res = await ApiService.searchNotes(email: userEmail!, query: query.trim());
                        if (res["success"] == true) {
                          setModalState(() {
                            searchResults = res["data"] is List ? res["data"] : [];
                            isSearching = false;
                          });
                        } else {
                          setModalState(() => isSearching = false);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: searchResults.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_rounded, size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  searchController.text.isEmpty ? "Search your lectures" : "No results found",
                                  style: const TextStyle(color: textSecondary, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: searchResults.length,
                            itemBuilder: (ctx, i) {
                              final r = searchResults[i];
                              final title = r["ai_title"]?.toString() ?? r["title"]?.toString() ?? "Untitled";
                              final subject = r["subject"]?.toString() ?? "General";
                              final isFav = r["is_favorite"] == true;
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: iconTeal.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.menu_book_rounded, color: iconTeal, size: 20),
                                ),
                                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(subject, style: const TextStyle(color: textSecondary, fontSize: 12)),
                                trailing: isFav ? const Icon(Icons.star_rounded, color: starYellow, size: 20) : null,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => LectureDetailScreen(lectureId: r["lecture_id"].toString()))).then((_) => _loadData());
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: primaryDark,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildHeroCard(),
                  const SizedBox(height: 24),
                  _buildStatsGrid(),
                  const SizedBox(height: 32),
                  _buildQuickActions(),
                  const SizedBox(height: 32),
                  _buildRecentLecturesHeader(),
                  const SizedBox(height: 16),
                  _buildRecentLecturesList(),
                  const SizedBox(height: 100), // Space for FAB and Bottom Nav
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // 1. Polished Header Section
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "Hello, ${_getUserDisplayName()}! ",
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [iconTeal, Colors.blue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      blendMode: BlendMode.srcATop,
                      child: const Text(
                        "👋",
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Ready to capture knowledge today?",
              style: TextStyle(
                color: textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: primaryDark, size: 28),
              onPressed: () {},
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
            )
          ],
        )
      ],
    );
  }

  // 2. Hero Card (Total Lectures - Dynamically Synced)
  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [heroStart, heroEnd],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: heroStart.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Total Lectures",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                "$_totalLectures",
                style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold, height: 1.0),
              ),
            ],
          ),
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: iconTeal,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 40),
          )
        ],
      ),
    );
  }

  // 3. Fully Dynamic 1x3 Stats Grid
  Widget _buildStatsGrid() {
    try {
      int notesCount = _lectures.where((l) => l['ai_response'] != null).length;
      
      // Dynamic Subjects Count
      int subjectsCount = _lectures
          .map((l) => l['subject'])
          .where((s) => s != null && s.toString().isNotEmpty)
          .toSet()
          .length;
          
      return Row(
        children: [
          Expanded(child: _buildGridItem("Notes", "$notesCount", Icons.description_rounded, const Color(0xFF10B981))),
          const SizedBox(width: 12),
          Expanded(child: _buildGridItem("Favorites", "$_totalFavorites", Icons.star_rounded, const Color(0xFFF59E0B))),
          const SizedBox(width: 12),
          Expanded(child: _buildGridItem("Subjects", "$subjectsCount", Icons.menu_book_rounded, primaryDark)),
        ],
      );
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.red.withValues(alpha: 0.1),
        child: Text("Error in stats: $e", style: const TextStyle(color: Colors.red)),
      );
    }
  }

  Widget _buildGridItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Text(value, style: const TextStyle(color: primaryDark, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // 3.5 Quick Actions
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Quick Actions", style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildActionCard(Icons.smart_toy_rounded, "AI Chat", const Color(0xFF8B5CF6), () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AiAssistantScreen())).then((_) => _loadData());
            }),
            _buildActionCard(Icons.folder_copy_rounded, "My Notes", const Color(0xFF10B981), () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesScreen())).then((_) => _loadData());
            }),
            _buildActionCard(Icons.star_rounded, "Favorites", const Color(0xFFF97316), () {
              setState(() => _showFavoritesOnly = !_showFavoritesOnly);
              _loadLectures();
            }, isActive: _showFavoritesOnly),
            _buildActionCard(Icons.tune_rounded, "AI Style", const Color(0xFFC084FC), () {
              StyleDialog.show(
                context,
                initialStyles: _selectedStyles,
                onApply: (styles) async {
                  await StyleService.saveStyles(styles);
                  if (mounted) setState(() {});
                },
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(IconData icon, String label, Color color, VoidCallback onTap, {bool isActive = false}) {
    final bgColor = isActive ? color : color.withValues(alpha: 0.08);
    final iconColor = isActive ? Colors.white : color;
    
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isActive ? color : color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(color: iconColor, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentLecturesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _showFavoritesOnly ? "Favourite Lectures" : "Recent Lectures",
          style: const TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (_showFavoritesOnly)
          GestureDetector(
            onTap: () {
              setState(() => _showFavoritesOnly = false);
              _loadLectures();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: iconTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded, color: iconTeal, size: 14),
                  SizedBox(width: 4),
                  Text(
                    "See All",
                    style: TextStyle(color: iconTeal, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          )
        else
          const Text(
            "See All",
            style: TextStyle(color: iconTeal, fontSize: 14, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }

  // 5. Redesigned Premium Recent Lectures List
  Widget _buildRecentLecturesList() {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: primaryDark)));
    }
    if (_lectures.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          border: Border.all(color: borderLight, width: 1.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          children: [
            Icon(Icons.mic_none_rounded, size: 48, color: textMuted),
            SizedBox(height: 16),
            Text("No lectures yet.", style: TextStyle(color: primaryDark, fontWeight: FontWeight.bold)),
            Text("Tap the mic to record.", style: TextStyle(color: textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    final displayLectures = _lectures.take(5).toList();

    return Column(
      children: displayLectures.map((lecture) => _buildPremiumLectureCard(lecture)).toList(),
    );
  }

  Widget _buildPremiumLectureCard(Map<String, dynamic> lecture) {
    try {
      final title = lecture["ai_title"]?.toString() ?? lecture["title"]?.toString() ?? "Untitled";
      final isFavorite = lecture["is_favorite"] == true;
      final date = _formatDate(lecture["created_at"]?.toString() ?? "");
      final subject = lecture["subject"]?.toString() ?? "General";
      final hasNotes = lecture["ai_response"] != null;
      
      final courseCode = lecture["course_code"]?.toString();

      return GestureDetector(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => LectureDetailScreen(lectureId: lecture["lecture_id"].toString())));
          if (mounted) _loadData();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderLight, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 15,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colored Subject Badge/Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.menu_book_rounded, color: iconTeal, size: 24),
              ),
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _toggleFavorite(lecture),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Icon(
                              isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                              color: isFavorite ? starYellow : textMuted.withValues(alpha: 0.5),
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [subject, if (courseCode != null && courseCode.isNotEmpty) courseCode, date].join(' • '),
                      style: const TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    
                    // Metadata Chips
                    Row(
                      children: [
                        if (hasNotes)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 12),
                                SizedBox(width: 4),
                                Text("AI Notes", style: TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        if (!hasNotes)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.pending_actions, color: Colors.orange, size: 12),
                                SizedBox(width: 4),
                                Text("Processing", style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        color: Colors.red.withValues(alpha: 0.1),
        child: Text("Error rendering card: $e", style: const TextStyle(color: Colors.red)),
      );
    }
  }

  // 6. Centered Floating Action Button (The big Mic)
  Widget _buildFAB() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: primaryDark,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: primaryDark.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: FloatingActionButton(
        onPressed: _showStartLectureDialog,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 36),
      ),
    );
  }

  // 7. Bottom Navigation Bar matching screenshot
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: BottomAppBar(
        color: Colors.transparent,
        shape: const CircularNotchedRectangle(),
        notchMargin: 12,
        elevation: 0,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(Icons.home_rounded, "Home", 0, isFilled: true),
                _buildNavItem(Icons.video_library_outlined, "Lectures", 1, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesScreen())).then((_) => _loadData());
                }),
                const SizedBox(width: 48), // Space for FAB
                _buildNavItem(Icons.search_rounded, "Search", 2, onTap: () => _showSearchDialog()),
                _buildNavItem(Icons.person_outline_rounded, "Profile", 3, onTap: () async {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, {VoidCallback? onTap, bool isFilled = false}) {
    bool isSelected = _currentIndex == index;
    final color = isSelected ? primaryDark : textMuted;
    
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/services/style_service.dart';
import '../../../core/services/api_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../notes/screens/notes_screen.dart';
import '../../home/screens/lecture_detail_screen.dart';
import '../../auth/screens/onboarding_preferences_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// Reuse colors from home_screen for consistency
const Color primaryDark = Color(0xFF162544);
const Color heroStart = Color(0xFF11254D);
const Color heroEnd = Color(0xFF236B8E);
const Color iconTeal = Color(0xFF4ACFBE);
const Color textMuted = Color(0xFF8B94A3);
const Color borderLight = Color(0xFFF0F1F5);
const Color textPrimary = Color(0xFF1C2D49);
const Color textSecondary = Color(0xFF64748B);
const Color starYellow = Color(0xFFFFC107);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? get userEmail => StyleService.currentUserEmail;
  String _selectedAvatar = 'https://randomuser.me/api/portraits/men/32.jpg';

  final List<String> _avatars = [
    'https://randomuser.me/api/portraits/men/32.jpg',
    'https://randomuser.me/api/portraits/women/44.jpg',
    'https://randomuser.me/api/portraits/men/46.jpg',
    'https://randomuser.me/api/portraits/women/68.jpg',
    'https://randomuser.me/api/portraits/men/90.jpg',
    'https://randomuser.me/api/portraits/women/12.jpg',
    'https://randomuser.me/api/portraits/men/22.jpg',
    'https://randomuser.me/api/portraits/women/35.jpg',
    'https://randomuser.me/api/portraits/men/62.jpg',
    'https://randomuser.me/api/portraits/women/94.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAvatar = prefs.getString('profile_avatar');
    if (savedAvatar != null && _avatars.contains(savedAvatar)) {
      setState(() {
        _selectedAvatar = savedAvatar;
      });
    }
  }

  Future<void> _saveAvatar(String avatarUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_avatar', avatarUrl);
    setState(() {
      _selectedAvatar = avatarUrl;
    });
  }

  String _getUserDisplayName() {
    final raw = userEmail?.split('@')[0] ?? "Student";
    return raw[0].toUpperCase() +
        raw.substring(1).replaceAll(RegExp(r'[^a-zA-Z]'), ' ');
  }

  void _showAvatarSelection() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose your Avatar',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _avatars.length,
                  itemBuilder: (context, index) {
                    final avatar = _avatars[index];
                    final isSelected = avatar == _selectedAvatar;
                    return GestureDetector(
                      onTap: () {
                        _saveAvatar(avatar);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: iconTeal, width: 3)
                              : null,
                          color: borderLight,
                        ),
                        child: ClipOval(
                          child: Image.network(
                            avatar,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: textMuted,
                                ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Favorites ──────────────────────────────────────────────
  void _openFavorites() async {
    if (userEmail == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _FavoritesSheet(userEmail: userEmail!);
      },
    );
  }

  // ── Feedback History ──────────────────────────────────────
  void _openFeedbackHistory() async {
    if (userEmail == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _FeedbackHistorySheet(userEmail: userEmail!);
      },
    );
  }

  // ── Settings ──────────────────────────────────────────────
  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingPreferencesScreen()),
    );
  }

  // ── Help & Support ────────────────────────────────────────
  void _openHelp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Icon(
                    Icons.school_rounded,
                    color: primaryDark,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "VoiceNoteX",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "AI-Powered Lecture Notes",
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  _helpItem(
                    Icons.mic_none_rounded,
                    "Record",
                    "Tap the mic to start recording your lecture.",
                  ),
                  _helpItem(
                    Icons.auto_awesome,
                    "AI Notes",
                    "Your recording is transcribed and turned into smart notes.",
                  ),
                  _helpItem(
                    Icons.tune_rounded,
                    "Personalize",
                    "Use AI Note Settings to customize how notes are generated.",
                  ),
                  _helpItem(
                    Icons.thumb_up_alt_outlined,
                    "Feedback",
                    "Rate your notes so the AI learns your preferences.",
                  ),
                  _helpItem(
                    Icons.picture_as_pdf_rounded,
                    "Export",
                    "Download any lecture as a professional PDF.",
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    "Version 1.0.0 • Built with ❤️",
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _helpItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconTeal, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textPrimary,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 12, color: textSecondary),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Search ────────────────────────────────────────────────
  void _showSearchDialog() {
    if (userEmail == null) return;
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Search lectures, notes, subjects...",
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: primaryDark,
                        ),
                        suffixIcon: isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: primaryDark,
                                  ),
                                ),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (query) async {
                        if (query.trim().isEmpty) {
                          setModalState(() => searchResults = []);
                          return;
                        }
                        setModalState(() => isSearching = true);
                        final res = await ApiService.searchNotes(
                          email: userEmail!,
                          query: query.trim(),
                        );
                        if (res["success"] == true) {
                          setModalState(() {
                            searchResults = res["data"] is List
                                ? res["data"]
                                : [];
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
                                Icon(
                                  Icons.search_rounded,
                                  size: 48,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  searchController.text.isEmpty
                                      ? "Search your lectures"
                                      : "No results found",
                                  style: const TextStyle(
                                    color: textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: searchResults.length,
                            itemBuilder: (ctx, i) {
                              final r = searchResults[i];
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: iconTeal.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.menu_book_rounded,
                                    color: iconTeal,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  r["ai_title"]?.toString() ??
                                      r["title"]?.toString() ??
                                      "Untitled",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  r["subject"]?.toString() ?? "General",
                                  style: const TextStyle(
                                    color: textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LectureDetailScreen(
                                        lectureId: r["lecture_id"].toString(),
                                      ),
                                    ),
                                  );
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
      backgroundColor: borderLight,
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [heroStart, heroEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.3,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _showAvatarSelection,
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.network(
                                    _selectedAvatar,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.person,
                                              size: 60,
                                              color: primaryDark,
                                            ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: iconTeal,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _getUserDisplayName(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail ?? 'student@voicenotex.com',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildMenuOption(
                          icon: Icons.task_outlined,
                          title: 'My Lectures',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotesScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuOption(
                          icon: Icons.star_border_rounded,
                          title: 'Favorites',
                          onTap: _openFavorites,
                        ),
                        _buildMenuOption(
                          icon: Icons.feedback_outlined,
                          title: 'Feedback History',
                          onTap: _openFeedbackHistory,
                        ),
                        _buildMenuOption(
                          icon: Icons.auto_awesome,
                          title: 'AI Note Settings',
                          onTap: _openSettings,
                        ),
                        _buildMenuOption(
                          icon: Icons.help_outline_rounded,
                          title: 'Help & Support',
                          onTap: _openHelp,
                        ),
                        const SizedBox(height: 16),
                        _buildMenuOption(
                          icon: Icons.logout_rounded,
                          title: 'Logout',
                          isDanger: true,
                          showArrow: true,
                          onTap: () async {
                            await StyleService.logout();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDanger = false,
    bool showArrow = true,
  }) {
    final color = isDanger ? Colors.redAccent : textPrimary;
    final bgColor = isDanger
        ? Colors.redAccent.withValues(alpha: 0.05)
        : borderLight.withValues(alpha: 0.6);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderLight, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDanger
                      ? Colors.redAccent.withValues(alpha: 0.1)
                      : primaryDark.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              if (showArrow)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: textMuted.withValues(alpha: 0.6),
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }

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
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(
          Icons.mic_none_rounded,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
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
                _buildNavItem(
                  Icons.home_rounded,
                  "Home",
                  0,
                  onTap: () => Navigator.pop(context),
                ),
                _buildNavItem(
                  Icons.video_library_outlined,
                  "Lectures",
                  1,
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const NotesScreen()),
                    );
                  },
                ),
                const SizedBox(width: 48),
                _buildNavItem(
                  Icons.search_rounded,
                  "Search",
                  2,
                  onTap: _showSearchDialog,
                ),
                _buildNavItem(
                  Icons.person_rounded,
                  "Profile",
                  3,
                  isFilled: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index, {
    VoidCallback? onTap,
    bool isFilled = false,
  }) {
    bool isSelected = index == 3;
    final color = isSelected ? primaryDark : textMuted;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
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

// ═══════════════════════════════════════════════════════════════
// Favorites Bottom Sheet
// ═══════════════════════════════════════════════════════════════
class _FavoritesSheet extends StatefulWidget {
  final String userEmail;
  const _FavoritesSheet({required this.userEmail});

  @override
  State<_FavoritesSheet> createState() => _FavoritesSheetState();
}

class _FavoritesSheetState extends State<_FavoritesSheet> {
  List<dynamic> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService.getLectures(
      widget.userEmail,
      favoritesOnly: true,
    );
    if (res["success"] == true && mounted) {
      setState(() {
        _favorites = res["data"] is List ? res["data"] : [];
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String dateStr) {
    try {
      return DateFormat(
        'MMM dd, yyyy',
      ).format(DateTime.parse(dateStr).toLocal());
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 28),
                SizedBox(width: 12),
                Text(
                  "Your Favorites",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: primaryDark),
                  )
                : _favorites.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_border_rounded,
                          size: 48,
                          color: textMuted,
                        ),
                        SizedBox(height: 12),
                        Text(
                          "No favorites yet",
                          style: TextStyle(color: textSecondary),
                        ),
                        Text(
                          "Star a lecture to see it here.",
                          style: TextStyle(color: textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _favorites.length,
                    itemBuilder: (ctx, i) {
                      final f = _favorites[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC107).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: Color(0xFFFFC107),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          f["ai_title"]?.toString() ??
                              f["title"]?.toString() ??
                              "Untitled",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          "${f["subject"] ?? "General"} • ${_formatDate(f["created_at"]?.toString() ?? "")}",
                          style: const TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFC107),
                          size: 20,
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LectureDetailScreen(
                                lectureId: f["lecture_id"].toString(),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Feedback History Bottom Sheet
// ═══════════════════════════════════════════════════════════════
class _FeedbackHistorySheet extends StatefulWidget {
  final String userEmail;
  const _FeedbackHistorySheet({required this.userEmail});

  @override
  State<_FeedbackHistorySheet> createState() => _FeedbackHistorySheetState();
}

class _FeedbackHistorySheetState extends State<_FeedbackHistorySheet> {
  List<dynamic> _lectures = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService.getLectures(widget.userEmail);
    if (res["success"] == true && mounted) {
      final all = res["data"] is List ? res["data"] as List : [];
      setState(() {
        _lectures = all.where((l) => l["feedback"] != null).toList();
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.feedback_outlined, color: primaryDark, size: 28),
                SizedBox(width: 12),
                Text(
                  "Feedback History",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: primaryDark),
                  )
                : _lectures.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.feedback_outlined,
                          size: 48,
                          color: textMuted,
                        ),
                        SizedBox(height: 12),
                        Text(
                          "No feedback yet",
                          style: TextStyle(color: textSecondary),
                        ),
                        Text(
                          "Rate your AI notes to see them here.",
                          style: TextStyle(color: textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _lectures.length,
                    itemBuilder: (ctx, i) {
                      final l = _lectures[i];
                      final feedback = l["feedback"];
                      final rating = feedback?["rating"]?.toString() ?? "—";
                      final isHelpful = rating == "helpful";
                      final feedbackType = feedback?["feedback_type"]
                          ?.toString();
                      final comment = feedback?["comment"]?.toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isHelpful
                                      ? Icons.thumb_up_rounded
                                      : Icons.thumb_down_rounded,
                                  color: isHelpful
                                      ? Colors.green
                                      : Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l["ai_title"]?.toString() ??
                                        l["title"]?.toString() ??
                                        "Untitled",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isHelpful
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isHelpful ? "Helpful" : "Needs Improvement",
                                    style: TextStyle(
                                      color: isHelpful
                                          ? Colors.green
                                          : Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (feedbackType != null &&
                                    feedbackType.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    "• $feedbackType",
                                    style: const TextStyle(
                                      color: textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (comment != null && comment.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                '"$comment"',
                                style: const TextStyle(
                                  color: textSecondary,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

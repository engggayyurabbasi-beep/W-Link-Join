import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'firebase_options.dart';
import 'services/firebase_auth_service.dart';
import 'services/firebase_storage_service.dart';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart'
    show TextInputFormatter, TextEditingValue, MaxLengthEnforcement;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countrify/countrify.dart';
import 'package:country/country.dart' as country_data;
import 'package:language_code/language_code.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/group_model.dart';
import 'data/group_repository.dart';
import 'data/firestore_group_repository.dart';
import 'data/group_categories.dart';
import 'admin/admin_login_screen.dart';

class _WordLimitFormatter extends TextInputFormatter {
  _WordLimitFormatter(this.maxWords);

  final int maxWords;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.trim();
    final words = text.isEmpty ? <String>[] : text.split(RegExp(r'\s+'));

    return words.length <= maxWords ? newValue : oldValue;
  }
}

class WLinkInterstitialController {
  // Ads are disabled in this test build.
  static Future<void> showIfReady() async {}
}

/// W-Link Join
/// Single-file Flutter UI foundation.
/// No demo groups, users, reviews, statistics, or fake backend responses.
/// Connect Firebase/Firestore/Storage before enabling real data operations.

ThemeMode _initialThemeMode = ThemeMode.light;
AppLanguage _initialLanguage = AppLanguage.english;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    final guestUser = await FirebaseAuthService.ensureGuestSignIn();
    debugPrint('Firebase guest authentication ready: ${guestUser.uid}');
  } catch (error, stackTrace) {
    debugPrint('Firebase guest authentication unavailable');
    debugPrint('$error');
    debugPrintStack(stackTrace: stackTrace);
  }

  debugPrint('AdMob disabled for startup testing');

  try {
    final prefs = await SharedPreferences.getInstance();
    _initialThemeMode = prefs.getString("wlink_theme") == "dark"
        ? ThemeMode.dark
        : ThemeMode.light;
  } catch (e, stackTrace) {
    debugPrint("SharedPreferences initialization failed");
    debugPrintStack(stackTrace: stackTrace);
    _initialThemeMode = ThemeMode.light;
  }

  runApp(const ProviderScope(child: WLinkJoinApp()));
}

// -----------------------------------------------------------------------------
// APP STATE
// -----------------------------------------------------------------------------

final themeModeProvider = StateProvider<ThemeMode>((ref) => _initialThemeMode);
final languageProvider = StateProvider<AppLanguage>((ref) => _initialLanguage);

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => GroupRepository(),
);

final firestoreGroupRepositoryProvider = Provider<FirestoreGroupRepository>(
  (ref) => FirestoreGroupRepository(),
);

final groupsProvider = StreamProvider<List<GroupModel>>(
  (ref) => ref.watch(firestoreGroupRepositoryProvider).watchApprovedGroups(),
);

final savedGroupIdsProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(groupRepositoryProvider).getSavedIds(),
);

enum AppLanguage { hindi, english }

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/explore',
            builder: (context, state) => ExploreScreen(
              initialCategory: state.uri.queryParameters['category'] ?? 'all',
            ),
          ),
          GoRoute(
            path: '/membership',
            builder: (context, state) => const MembershipPlansScreen(),
          ),
          GoRoute(
            path: '/submit',
            builder: (context, state) => const SubmitGroupScreen(),
          ),
          GoRoute(
            path: '/saved',
            builder: (context, state) => const SavedGroupsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/group/:id',
        builder: (context, state) =>
            GroupDetailsScreen(groupId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const OwnerAnalyticsScreen(),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminLoginScreen(),
      ),
    ],
  );
});

class WLinkJoinApp extends ConsumerWidget {
  const WLinkJoinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'W-Link Join',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}

// -----------------------------------------------------------------------------
// THEME
// -----------------------------------------------------------------------------

class AppTheme {
  static const Color green = Color(0xFF16864A);
  static const Color greenDark = Color(0xFF0D6637);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: green,
      brightness: Brightness.light,
      primary: green,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF6F8F6),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF17231B),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE8EEE9)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7F9F7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E8E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E8E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: green, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: green),
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: green,
      brightness: Brightness.dark,
      primary: const Color(0xFF55C982),
      surface: const Color(0xFF171D19),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF101511),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF171D19),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF171D19),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF2A352D)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF202921),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF354239)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF354239)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF55C982), width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16864A),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// LOCALIZATION HELPERS
// -----------------------------------------------------------------------------

class T {
  static String get(AppLanguage language, String hindi, String english) =>
      language == AppLanguage.hindi ? hindi : english;
}

String tr(WidgetRef ref, String hindi, String english) =>
    T.get(ref.watch(languageProvider), hindi, english);

String trContext(BuildContext context, String hindi, String english) {
  final container = ProviderScope.containerOf(context);
  return T.get(container.read(languageProvider), hindi, english);
}

// -----------------------------------------------------------------------------
// APP SHELL AND NAVIGATION
// -----------------------------------------------------------------------------

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  int _indexForLocation(String location) {
    if (location.startsWith('/explore')) return 1;
    if (location.startsWith('/submit')) return 2;
    if (location.startsWith('/saved')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final selected = _indexForLocation(location);
    final language = ref.watch(languageProvider);

    final labels = language == AppLanguage.hindi
        ? ['होम', 'खोजें', 'जोड़ें', 'सेव', 'प्रोफाइल']
        : ['Home', 'Explore', 'Submit', 'Saved', 'Profile'];

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) async {
          const routes = ['/', '/explore', '/submit', '/saved', '/profile'];

          if (location == '/' && index == 1) {
            await WLinkInterstitialController.showIfReady();
            if (!context.mounted) return;
          }

          context.go(routes[index]);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: labels[0],
          ),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: labels[1],
          ),
          NavigationDestination(
            icon: const Icon(Icons.add_circle_outline),
            selectedIcon: const Icon(Icons.add_circle),
            label: labels[2],
          ),
          NavigationDestination(
            icon: const Icon(Icons.bookmark_border),
            selectedIcon: const Icon(Icons.bookmark),
            label: labels[3],
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: labels[4],
          ),
        ],
      ),
    );
  }
}

class PageScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const PageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
    );
  }
}

// -----------------------------------------------------------------------------
// SHARED WIDGETS
// -----------------------------------------------------------------------------

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 82,
              width: 82,
              decoration: BoxDecoration(
                color: color.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: color.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: color.onSurfaceVariant, height: 1.5),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTap;

  const SectionHeading({
    super.key,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (trailing != null)
          TextButton(onPressed: onTap, child: Text(trailing!)),
      ],
    );
  }
}

class FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const FeatureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: color.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: color.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class WLinkBannerAd extends StatelessWidget {
  const WLinkBannerAd({super.key});

  @override
  Widget build(BuildContext context) {
    // Reserved banner area. Ads will be restored in a future update.
    return const SizedBox(height: 50);
  }
}

// -----------------------------------------------------------------------------

Widget _buildGroupImage(
  String path, {
  double? width,
  required double height,
  BoxFit fit = BoxFit.cover,
  required ImageErrorWidgetBuilder errorBuilder,
}) {
  final localFile = File(path);

  if (path.isNotEmpty && localFile.existsSync()) {
    return Image.file(
      localFile,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
    );
  }

  return Image.network(
    path,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}

// HOME
// -----------------------------------------------------------------------------

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Widget _groupCard(BuildContext context, GroupModel group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _buildGroupImage(
            group.imageUrl,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const SizedBox(
              width: 52,
              height: 52,
              child: Icon(Icons.groups_outlined),
            ),
          ),
        ),
        title: Text(
          group.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${group.category} • ${group.city}, ${group.country}\n${group.description}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/group/${group.id}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final isHindi = language == AppLanguage.hindi;
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.asset(
                'assets/app_icon.png',
                height: 36,
                width: 36,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'W-Link Join',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isHindi ? 'सूचनाएँ' : 'Notifications',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(isHindi ? 'सूचनाएँ' : 'Notifications'),
                content: Text(
                  isHindi
                      ? 'इस Offline Version में Server Notifications उपलब्ध नहीं हैं।'
                      : 'Server notifications are not available in this offline version.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(isHindi ? 'बंद करें' : 'Close'),
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.notifications_none),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF16864A), Color(0xFF0D6637)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHindi
                      ? 'अपने पसंदीदा WhatsApp Groups खोजें'
                      : 'Discover WhatsApp Groups you love',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Discover Groups. Connect People.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 18),
                InkWell(
                  onTap: () => context.go('/explore'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: AppTheme.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isHindi
                                ? 'Group खोजने के लिए यहाँ टैप करें'
                                : 'Tap here to find groups',
                            style: const TextStyle(
                              color: Color(0xFF526057),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward, color: AppTheme.green),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const WLinkBannerAd(),
          SectionHeading(
            title: isHindi ? 'मेरे डिवाइस के Groups' : 'Groups on this Device',
          ),
          groupsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => EmptyState(
              icon: Icons.error_outline,
              title: isHindi ? 'डेटा लोड नहीं हुआ' : 'Could not load groups',
              message: isHindi
                  ? 'कृपया दोबारा कोशिश करें।'
                  : 'Please try again.',
              action: OutlinedButton(
                onPressed: () => ref.invalidate(groupsProvider),
                child: Text(isHindi ? 'दोबारा कोशिश करें' : 'Retry'),
              ),
            ),
            data: (groups) {
              final sortedGroups = [...groups]
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              final categories =
                  groups
                      .map((group) => group.category.trim())
                      .where((category) => category.isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort();

              if (groups.isEmpty) {
                return EmptyState(
                  icon: Icons.groups_2_outlined,
                  title: isHindi
                      ? 'अभी कोई Group नहीं है'
                      : 'No groups available yet',
                  message: isHindi
                      ? 'इस फोन पर Submit किए गए Groups यहाँ दिखाई देंगे।'
                      : 'Groups submitted on this device will appear here.',
                  action: OutlinedButton.icon(
                    onPressed: () => context.go('/submit'),
                    icon: const Icon(Icons.add),
                    label: Text(
                      isHindi ? 'Group Submit करें' : 'Submit a Group',
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...sortedGroups
                      .take(5)
                      .map((group) => _groupCard(context, group)),
                  if (sortedGroups.length > 5)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.go('/explore'),
                        child: Text(isHindi ? 'सभी देखें' : 'View all'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SectionHeading(
                    title: isHindi ? 'Popular Categories' : 'Categories',
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((category) {
                      return ActionChip(
                        avatar: const Icon(Icons.category_outlined, size: 18),
                        label: Text(category),
                        onPressed: () => context.go(
                          '/explore?category=${Uri.encodeComponent(category)}',
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  SectionHeading(
                    title: isHindi ? 'Recently Added Groups' : 'Recently Added',
                    trailing: isHindi ? 'सभी देखें' : 'View all',
                    onTap: () => context.go('/explore'),
                  ),
                  ...sortedGroups
                      .take(3)
                      .map((group) => _groupCard(context, group)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// EXPLORE AND SEARCH
// -----------------------------------------------------------------------------

class WLinkNativeAd extends StatelessWidget {
  const WLinkNativeAd({super.key});

  @override
  Widget build(BuildContext context) {
    // Native ads are disabled for this test build.
    return const SizedBox.shrink();
  }
}

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key, this.initialCategory = 'all'});

  final String initialCategory;

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final searchController = TextEditingController();
  String selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = ref.watch(languageProvider) == AppLanguage.hindi;
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isHindi ? 'Groups खोजें' : 'Explore Groups'),
        actions: [
          IconButton(
            onPressed: () {
              searchController.clear();
              setState(() => selectedCategory = 'all');
            },
            icon: const Icon(Icons.refresh),
            tooltip: isHindi ? 'रीसेट करें' : 'Reset filters',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: isHindi ? 'Group का नाम खोजें' : 'Search group name',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          Expanded(
            child: groupsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => EmptyState(
                icon: Icons.error_outline,
                title: isHindi ? 'डेटा लोड नहीं हुआ' : 'Could not load groups',
                message: isHindi
                    ? 'कृपया दोबारा कोशिश करें।'
                    : 'Please try again.',
                action: OutlinedButton(
                  onPressed: () => ref.invalidate(groupsProvider),
                  child: Text(isHindi ? 'दोबारा कोशिश करें' : 'Retry'),
                ),
              ),
              data: (groups) {
                final categories =
                    groups.map((group) => group.category).toSet().toList()
                      ..sort();

                final query = searchController.text.trim().toLowerCase();

                final filteredGroups = groups.where((group) {
                  final matchesSearch =
                      query.isEmpty ||
                      group.name.toLowerCase().contains(query) ||
                      group.category.toLowerCase().contains(query) ||
                      group.city.toLowerCase().contains(query);

                  final matchesCategory =
                      selectedCategory == 'all' ||
                      group.category == selectedCategory;

                  return matchesSearch && matchesCategory;
                }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                if (groups.isEmpty) {
                  return EmptyState(
                    icon: Icons.groups_2_outlined,
                    title: isHindi
                        ? 'अभी कोई Group नहीं मिला'
                        : 'No groups found',
                    message: isHindi
                        ? 'अभी तक इस फोन में कोई Group Submit नहीं किया गया है।'
                        : 'No groups have been submitted on this device yet.',
                    action: OutlinedButton.icon(
                      onPressed: () => context.go('/submit'),
                      icon: const Icon(Icons.add),
                      label: Text(
                        isHindi ? 'Group Submit करें' : 'Submit a Group',
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    if (categories.isNotEmpty)
                      SizedBox(
                        height: 54,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: ChoiceChip(
                                label: Text(isHindi ? 'सभी' : 'All'),
                                selected: selectedCategory == 'all',
                                onSelected: (_) {
                                  setState(() => selectedCategory = 'all');
                                },
                              ),
                            ),
                            ...categories.map(
                              (category) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: ChoiceChip(
                                  label: Text(category),
                                  selected: selectedCategory == category,
                                  onSelected: (_) {
                                    setState(() => selectedCategory = category);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: filteredGroups.isEmpty
                          ? Center(
                              child: Text(
                                isHindi
                                    ? 'कोई Group नहीं मिला।'
                                    : 'No matching groups found.',
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount:
                                  filteredGroups.length +
                                  (filteredGroups.length - 1) ~/ 5,
                              itemBuilder: (context, index) {
                                if (index > 0 && (index + 1) % 6 == 0) {
                                  return const WLinkNativeAd();
                                }

                                final groupIndex = index - ((index + 1) ~/ 6);
                                final group = filteredGroups[groupIndex];

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(12),
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: _buildGroupImage(
                                        group.imageUrl,
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const SizedBox(
                                                  width: 52,
                                                  height: 52,
                                                  child: Icon(
                                                    Icons.groups_outlined,
                                                  ),
                                                ),
                                      ),
                                    ),
                                    title: Text(
                                      group.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        '${group.category} • ${group.city}, ${group.country}\n${group.description}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    isThreeLine: true,
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () =>
                                        context.push('/group/${group.id}'),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// GROUP SUBMISSION
// -----------------------------------------------------------------------------

class SubmitGroupScreen extends ConsumerStatefulWidget {
  const SubmitGroupScreen({super.key});

  @override
  ConsumerState<SubmitGroupScreen> createState() => _SubmitGroupScreenState();
}

class _SubmitGroupScreenState extends ConsumerState<SubmitGroupScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final currentLinkController = TextEditingController();
  final categoryController = TextEditingController();
  final countryController = TextEditingController();
  final stateController = TextEditingController();
  final cityController = TextEditingController();
  final languageController = TextEditingController();
  final descriptionController = TextEditingController();
  final rulesController = TextEditingController();
  final ownerContactController = TextEditingController();
  bool permissionConfirmed = false;
  bool showOwnerContact = false;
  bool _isSaving = false;
  String? selectedCategory;
  Country? selectedCountry;
  CountryState? selectedState;
  City? selectedCity;
  List<String> selectedLanguages = [];
  List<CountryState> availableStates = [];
  List<City> availableCities = [];
  bool isLoadingStates = false;
  bool isLoadingCities = false;
  String? selectedImagePath;

  Future<void> _pickGroupImage() async {
    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1280,
      );

      if (picked == null) return;

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'group_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedFile = await File(picked.path)
          .copy('${directory.path}/$fileName');

      if (!mounted) return;
      setState(() => selectedImagePath = savedFile.path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not select the image. Please try again.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in [
      nameController,
      currentLinkController,
      categoryController,
      countryController,
      stateController,
      cityController,
      languageController,
      descriptionController,
      rulesController,
      ownerContactController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    selectedCountry = AllCountries.getByAlpha2Code('IN');
    if (selectedCountry != null) {
      countryController.text = selectedCountry!.name;
      _loadStates(selectedCountry!);
    }
  }

  Future<void> _loadStates(Country country) async {
    setState(() {
      isLoadingStates = true;
      isLoadingCities = false;
      selectedState = null;
      selectedCity = null;
      availableStates = [];
      availableCities = [];
      stateController.clear();
      cityController.clear();
    });

    final states = await GeoRepository.instance.statesOf(country.alpha2Code);

    if (!mounted) return;

    setState(() {
      availableStates = states;
      isLoadingStates = false;
    });
  }

  Future<void> _loadCities(CountryState state) async {
    setState(() {
      isLoadingCities = true;
      selectedCity = null;
      availableCities = [];
      cityController.clear();
    });

    final cities = await GeoRepository.instance.citiesOf(state.id);

    if (!mounted) return;

    setState(() {
      availableCities = cities;
      isLoadingCities = false;
    });
  }

  String? requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return trContext(
        context,
        'यह जानकारी आवश्यक है',
        'This field is required',
      );
    }
    return null;
  }

  String? ownerContactValidator(String? value) {
    final contact = value?.trim() ?? '';
    if (showOwnerContact && contact.isEmpty) {
      return trContext(
        context,
        'Public Contact के लिए मोबाइल नंबर जरूरी है',
        'Phone number is required when public contact is enabled',
      );
    }
    if (contact.isEmpty) return null;
    final normalized = contact.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(normalized)) {
      return trContext(
        context,
        'सही मोबाइल नंबर दर्ज करें',
        'Enter a valid phone number',
      );
    }
    return null;
  }

  String? inviteLinkValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return trContext(
        context,
        'Invite Link आवश्यक है',
        'Invite link is required',
      );
    }
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'chat.whatsapp.com' ||
        uri.pathSegments.isEmpty) {
      return trContext(
        context,
        'सही WhatsApp Group Invite Link दर्ज करें',
        'Enter a valid WhatsApp Group invite link',
      );
    }
    return null;
  }

  Future<String?> _showSearchPicker({
    required String title,
    required List<String> options,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = options
                .where(
                  (item) => item.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        autofocus: true,
                        onChanged: (value) =>
                            setSheetState(() => query = value.trim()),
                        decoration: const InputDecoration(
                          hintText: 'Search options',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('No options found'))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  return ListTile(
                                    title: Text(item),
                                    onTap: () =>
                                        Navigator.pop(sheetContext, item),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<String> _languageOptionsForSelectedCountry() {
    final selected = selectedCountry;
    if (selected == null) return [];

    final matches = country_data.Countries.values.where(
      (country) => country.alpha2 == selected.alpha2Code,
    );

    if (matches.isEmpty) return [];

    final country = matches.first;
    final codes = <String>{
      ...country.languagesOfficial,
      ...country.languagesSpoken,
    };

    // Additional commonly used regional languages in India.
    if (country.alpha2 == 'IN') {
      codes.addAll([
        'ur',
        'bn',
        'pa',
        'ta',
        'te',
        'mr',
        'gu',
        'kn',
        'ml',
        'or',
        'as',
        'sd',
        'ks',
        'ne',
      ]);
    }

    final names = <String>{};
    for (final code in codes) {
      try {
        names.add(LanguageCodes.fromCode(code).englishName);
      } catch (_) {
        // Ignore language codes not available in the name database.
      }
    }

    final result = names.toList()..sort();
    return result;
  }

  Future<void> _showLanguagePicker() async {
    final options = _languageOptionsForSelectedCountry();

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No language options available')),
      );
      return;
    }

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        String query = '';
        final selected = Set<String>.from(selectedLanguages);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = options
                .where(
                  (item) => item.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.78,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Select Group Languages',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        autofocus: true,
                        onChanged: (value) =>
                            setSheetState(() => query = value.trim()),
                        decoration: const InputDecoration(
                          hintText: 'Search languages',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('${selected.length} selected'),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('No languages found'))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final language = filtered[index];
                                  return CheckboxListTile(
                                    value: selected.contains(language),
                                    title: Text(language),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    onChanged: (checked) {
                                      setSheetState(() {
                                        if (checked == true) {
                                          selected.add(language);
                                        } else {
                                          selected.remove(language);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(
                              sheetContext,
                              selected.toList()..sort(),
                            );
                          },
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        selectedLanguages = result;
        languageController.text = result.join(', ');
      });
    }
  }

  Future<void> _saveGroup() async {
    if (_isSaving) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    try {
      final groupId = DateTime.now().microsecondsSinceEpoch.toString();
      String imageUrl = '';

      if (selectedImagePath != null) {
        imageUrl = await FirebaseStorageService().uploadGroupImage(
          groupId: groupId,
          imageFile: File(selectedImagePath!),
        );
      }

      final group = GroupModel(
        id: groupId,
        name: nameController.text.trim(),
        currentLink: currentLinkController.text.trim(),
        previousLink: '',
        imageUrl: imageUrl,
        category: categoryController.text.trim(),
        subcategory: '',
        country: countryController.text.trim(),
        state: stateController.text.trim(),
        city: cityController.text.trim(),
        language: languageController.text.trim(),
        description: descriptionController.text.trim(),
        rules: '',
        ownerContact: ownerContactController.text.trim(),
        showOwnerContact: showOwnerContact,
        createdAt: DateTime.now(),
      );

      await ref.read(firestoreGroupRepositoryProvider).submitGroup(group);
      ref.invalidate(groupsProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Group submitted successfully.')));

      context.go('/explore');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(languageProvider) == AppLanguage.hindi
                ? 'Group सेव नहीं हो सका। दोबारा कोशिश करें।'
                : 'Could not save the group. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = ref.watch(languageProvider) == AppLanguage.hindi;

    return Scaffold(
      appBar: AppBar(
        title: Text(isHindi ? 'Group Submit करें' : 'Submit a Group'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _FormIntro(
              title: isHindi
                  ? 'अपने Group की जानकारी दें'
                  : 'Group information',
              subtitle: isHindi
                  ? 'सभी जानकारी सही भरें। अभी Group केवल इसी डिवाइस में सेव होगा, ऑनलाइन प्रकाशित नहीं होगा।'
                  : 'Provide accurate details. Groups are saved only on this device and are not published online in this version.',
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final now = DateTime.now();
                final monthKey =
                    'wlink_free_submissions_${now.year}_${now.month.toString().padLeft(2, '0')}';

                return FutureBuilder<int>(
                  future: SharedPreferences.getInstance().then(
                    (prefs) => prefs.getInt(monthKey) ?? 0,
                  ),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    final remaining = (2 - count).clamp(0, 2);

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.hourglass_top),
                        title: Text(
                          'Free submissions remaining: $remaining / 2',
                        ),
                        subtitle: Text(
                          'Used this month: $count / 2. Resets on the 1st.',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            _FieldLabel('Group Image (Optional)'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (selectedImagePath != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(selectedImagePath!),
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ] else
                      Container(
                        height: 110,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 42,
                        ),
                      ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _pickGroupImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        selectedImagePath == null
                            ? 'Choose Group Image'
                            : 'Change Group Image',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _FieldLabel(isHindi ? 'Group Name *' : 'Group Name *'),
            TextFormField(
              controller: nameController,
              validator: requiredValidator,
              maxLength: 20,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: isHindi ? 'Group का नाम' : 'Enter group name',
              ),
            ),
            const SizedBox(height: 16),
            _FieldLabel('WhatsApp Group Link *'),
            TextFormField(
              controller: currentLinkController,
              validator: inviteLinkValidator,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://chat.whatsapp.com/...',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Paste the active WhatsApp group invite link. The group picture cannot be fetched automatically from a public invite link in this offline version.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _FieldLabel('Category *'),
            TextFormField(
              controller: categoryController,
              validator: requiredValidator,
              readOnly: true,
              onTap: () async {
                final value = await _showSearchPicker(
                  title: 'Select Category',
                  options: GroupCategories.categories,
                );
                if (value != null && mounted) {
                  setState(() {
                    selectedCategory = value;
                    categoryController.text = value;
                  });
                }
              },
              decoration: const InputDecoration(
                hintText: 'Select a category',
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
            ),
            const SizedBox(height: 16),
            _FieldLabel('Country *'),
            TextFormField(
              controller: countryController,
              validator: requiredValidator,
              readOnly: true,
              onTap: () async {
                final countries =
                    AllCountries.all.map((country) => country.name).toList()
                      ..sort();

                final value = await _showSearchPicker(
                  title: 'Select Country',
                  options: countries,
                );

                if (value != null && mounted) {
                  final country = AllCountries.all.firstWhere(
                    (item) => item.name == value,
                  );
                  setState(() {
                    selectedCountry = country;
                    countryController.text = country.name;
                    selectedLanguages = [];
                    languageController.clear();
                  });
                  await _loadStates(country);
                }
              },
              decoration: const InputDecoration(
                hintText: 'Select country',
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
            ),
            const SizedBox(height: 16),
            _FieldLabel('State *'),
            TextFormField(
              controller: stateController,
              validator: requiredValidator,
              readOnly: true,
              enabled:
                  selectedCountry != null &&
                  !isLoadingStates &&
                  availableStates.isNotEmpty,
              onTap: () async {
                final value = await _showSearchPicker(
                  title: 'Select State',
                  options: availableStates.map((state) => state.name).toList(),
                );

                if (value != null && mounted) {
                  final state = availableStates.firstWhere(
                    (item) => item.name == value,
                  );
                  setState(() {
                    selectedState = state;
                    stateController.text = state.name;
                  });
                  await _loadCities(state);
                }
              },
              decoration: InputDecoration(
                hintText: isLoadingStates
                    ? 'Loading states...'
                    : 'Select state',
                suffixIcon: isLoadingStates
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.arrow_drop_down),
              ),
            ),
            const SizedBox(height: 16),
            _FieldLabel('City *'),
            TextFormField(
              controller: cityController,
              validator: requiredValidator,
              readOnly: true,
              enabled:
                  selectedState != null &&
                  !isLoadingCities &&
                  availableCities.isNotEmpty,
              onTap: () async {
                final value = await _showSearchPicker(
                  title: 'Select City',
                  options: availableCities.map((city) => city.name).toList(),
                );

                if (value != null && mounted) {
                  final city = availableCities.firstWhere(
                    (item) => item.name == value,
                  );
                  setState(() {
                    selectedCity = city;
                    cityController.text = city.name;
                  });
                }
              },
              decoration: InputDecoration(
                hintText: isLoadingCities ? 'Loading cities...' : 'Select city',
                suffixIcon: isLoadingCities
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.arrow_drop_down),
              ),
            ),
            const SizedBox(height: 16),
            _FieldLabel('Group Language *'),
            TextFormField(
              controller: languageController,
              validator: requiredValidator,
              readOnly: true,
              onTap: selectedCountry == null ? null : _showLanguagePicker,
              decoration: const InputDecoration(
                hintText: 'Select one or more languages',
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
            ),
            const SizedBox(height: 16),
            _FieldLabel('Group Description & Rules *'),
            TextFormField(
              controller: descriptionController,
              validator: requiredValidator,
              inputFormatters: [_WordLimitFormatter(100)],
              minLines: 4,
              maxLines: 7,
              decoration: const InputDecoration(
                hintText: 'Describe your group, its purpose and rules...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            _FieldLabel(
              isHindi
                  ? 'Owner Contact Number (वैकल्पिक)'
                  : 'Owner Contact Number (optional)',
            ),
            TextFormField(
              controller: ownerContactController,
              validator: ownerContactValidator,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: isHindi ? 'मोबाइल नंबर' : 'Phone number',
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: showOwnerContact,
              onChanged: (value) => setState(() => showOwnerContact = value),
              title: Text(
                isHindi
                    ? 'मेरा Contact Number Public दिखाएँ'
                    : 'Show my contact number publicly',
              ),
              subtitle: Text(
                isHindi
                    ? 'केवल आपकी स्पष्ट अनुमति पर दिखेगा।'
                    : 'Visible only with your explicit consent.',
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: permissionConfirmed,
              onChanged: (value) =>
                  setState(() => permissionConfirmed = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                isHindi
                    ? 'मैं पुष्टि करता/करती हूँ कि मुझे यह Invite Link साझा करने की अनुमति है।'
                    : 'I confirm that I have permission to share this invite link.',
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _isSaving
                  ? null
                  : () {
                      if (!formKey.currentState!.validate()) return;
                      if (!permissionConfirmed) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isHindi
                                  ? 'कृपया Permission Confirmation स्वीकार करें।'
                                  : 'Please confirm permission to share this link.',
                            ),
                          ),
                        );
                        return;
                      }
                      _saveGroup();
                    },
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isHindi ? 'Group सेव करें' : 'Save Group'),
            ),
            const SizedBox(height: 12),
            Text(
              isHindi
                  ? 'यह Group केवल इसी फोन में सेव होगा; अभी ऑनलाइन प्रकाशित नहीं होगा।'
                  : 'This group will be saved on this device only; it will not be published online yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _FormIntro extends StatelessWidget {
  final String title;
  final String subtitle;
  const _FormIntro({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(height: 1.45)),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

// -----------------------------------------------------------------------------
// SAVED GROUPS
// -----------------------------------------------------------------------------

class SavedGroupsScreen extends ConsumerWidget {
  const SavedGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHindi = ref.watch(languageProvider) == AppLanguage.hindi;
    final groupsAsync = ref.watch(groupsProvider);
    final savedAsync = ref.watch(savedGroupIdsProvider);

    return PageScaffold(
      title: isHindi ? 'Saved और Favourites' : 'Saved & Favourites',
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            isHindi ? 'Groups लोड नहीं हुए।' : 'Could not load groups.',
          ),
        ),
        data: (groups) => savedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text(
              isHindi
                  ? 'Saved सूची लोड नहीं हुई।'
                  : 'Could not load saved list.',
            ),
          ),
          data: (savedIds) {
            final savedGroups = groups
                .where((group) => savedIds.contains(group.id))
                .toList();

            if (savedGroups.isEmpty) {
              return EmptyState(
                icon: Icons.bookmark_border,
                title: isHindi ? 'अभी कुछ सेव नहीं है' : 'Nothing saved yet',
                message: isHindi
                    ? 'Explore में जाकर अपने पसंदीदा Groups सेव करें।'
                    : 'Explore groups and save your favourites here.',
                action: OutlinedButton(
                  onPressed: () => context.go('/explore'),
                  child: Text(isHindi ? 'Groups खोजें' : 'Explore Groups'),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: savedGroups.length,
              itemBuilder: (context, index) {
                final group = savedGroups[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildGroupImage(
                        group.imageUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(
                              width: 52,
                              height: 52,
                              child: Icon(Icons.groups_outlined),
                            ),
                      ),
                    ),
                    title: Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${group.category} • ${group.city}, ${group.country}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: isHindi ? 'Saved से हटाएँ' : 'Remove from saved',
                      icon: const Icon(Icons.bookmark, color: Colors.green),
                      onPressed: () async {
                        await ref
                            .read(groupRepositoryProvider)
                            .toggleSaved(group.id);
                        ref.invalidate(savedGroupIdsProvider);
                      },
                    ),
                    onTap: () => context.push('/group/${group.id}'),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PROFILE
// -----------------------------------------------------------------------------

class MembershipPlansScreen extends StatelessWidget {
  const MembershipPlansScreen({super.key});

  Widget _feature(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: AppTheme.green, size: 19),
          const SizedBox(width: 9),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _price(String duration, String price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(duration)),
          Text(price, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Membership Plans',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Choose the plan that works for you',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Compare group submission limits and advertising benefits.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppTheme.green,
                        size: 27,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Free Plan',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const Chip(label: Text('Default')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹0',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const Divider(height: 24),
                  _feature('2 new group submissions per month'),
                  _feature('Advertisements will be shown'),
                  _feature('Monthly limit resets on the 1st day of each month'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.block, color: AppTheme.green, size: 27),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ad-Free Plan',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ad-free access with 10 new group submissions per month.',
                  ),
                  const Divider(height: 24),
                  _price('Monthly', '₹75'),
                  _price('Quarterly (3 Months)', '₹199'),
                  _price('Half-Yearly (6 Months)', '₹349'),
                  _price('Yearly (12 Months)', '₹499'),
                  _price('Lifetime', '₹1,100'),
                  const Divider(height: 20),
                  _feature('No advertisements'),
                  _feature('10 new group submissions per month'),
                  _feature('Monthly submission limit resets on the 1st'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Card(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.green.withValues(alpha: 0.55),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium,
                        color: AppTheme.green,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Unlimited Premium',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '₹999',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.green,
                    ),
                  ),
                  const Text('Per year'),
                  const Divider(height: 24),
                  _feature('Completely ad-free experience'),
                  _feature('Unlimited group submissions'),
                  _feature('One-year membership'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Free Plan is the default plan in this version. Membership payments and activation are not available yet. Paid plan benefits will become active only after payment and membership verification are implemented.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Guest users can explore, join and save groups. Free Plan allows 2 group submissions per month.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHindi = ref.watch(languageProvider) == AppLanguage.hindi;
    return PageScaffold(
      title: isHindi ? 'प्रोफाइल' : 'Profile',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.12),
                    child: Icon(
                      Icons.person_outline,
                      size: 38,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isHindi ? 'Guest User' : 'Guest User',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    isHindi
                        ? 'Login करने पर आपकी प्रोफाइल यहाँ दिखाई देगी।'
                        : 'Your profile will appear here after login.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isHindi
                          ? 'आप अभी Guest Mode में ऐप इस्तेमाल कर रहे हैं। Login सुविधा अगले अपडेट में आएगी।'
                          : 'You are using the app in Guest Mode. Login will be available in a future update.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FeatureTile(
            icon: Icons.workspace_premium_outlined,
            title: 'Membership Plans',
            subtitle: 'Explore Ad-Free and Unlimited plans',
            onTap: () => context.push('/membership'),
          ),
          FeatureTile(
            icon: Icons.analytics_outlined,
            title: 'Owner Analytics',
            subtitle: 'View your group performance',
            onTap: () => context.push('/analytics'),
          ),
          FeatureTile(
            icon: Icons.support_agent_outlined,
            title: isHindi ? 'Support Ticket' : 'Support Ticket',
            subtitle: isHindi
                ? 'सहायता के लिए Ticket बनाएँ'
                : 'Create a support ticket',
            onTap: () => context.push('/support'),
          ),
          FeatureTile(
            icon: Icons.settings_outlined,
            title: isHindi ? 'Settings' : 'Settings',
            subtitle: isHindi
                ? 'Language और Theme बदलें'
                : 'Change language and theme',
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SETTINGS
// -----------------------------------------------------------------------------

class OwnerAnalyticsScreen extends ConsumerWidget {
  const OwnerAnalyticsScreen({super.key});

  Widget _statCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final now = DateTime.now();

    return PageScaffold(
      title: 'Owner Analytics',
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 42),
                const SizedBox(height: 12),
                const Text('Could not load your group data.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(groupsProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (groups) {
          final monthlyGroups = groups
              .where(
                (group) =>
                    group.createdAt.year == now.year &&
                    group.createdAt.month == now.month,
              )
              .length;

          final categoryCounts = <String, int>{};
          for (final group in groups) {
            final category = group.category.trim().isEmpty
                ? 'Uncategorized'
                : group.category.trim();
            categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
          }

          final categories = categoryCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          final recentGroups = [...groups]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Your Group Overview',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                'Statistics from groups saved on this device.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.45,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _statCard(
                    context,
                    'Total Groups',
                    '${groups.length}',
                    Icons.groups_outlined,
                    AppTheme.green,
                  ),
                  _statCard(
                    context,
                    'This Month',
                    '$monthlyGroups',
                    Icons.calendar_month_outlined,
                    Colors.blue,
                  ),
                  _statCard(
                    context,
                    'Categories',
                    '${categoryCounts.length}',
                    Icons.category_outlined,
                    Colors.deepPurple,
                  ),
                  _statCard(
                    context,
                    'Recent Groups',
                    '${recentGroups.take(5).length}',
                    Icons.schedule_outlined,
                    Colors.orange,
                  ),
                ],
              ),

              const SizedBox(height: 22),
              Text(
                'Category Distribution',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),

              if (categories.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('No category data available yet.'),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        for (final entry in categories) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(entry.key)),
                              Text(
                                '${entry.value} Groups',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: entry.value / groups.length,
                            minHeight: 7,
                            borderRadius: BorderRadius.circular(8),
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 22),
              Text(
                'Recent Submissions',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),

              if (recentGroups.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('You have not submitted any groups yet.'),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final group in recentGroups.take(10))
                        ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.groups_outlined),
                          ),
                          title: Text(
                            group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${group.category} • ${group.city}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            _dateLabel(group.createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Online Analytics Not Available Yet',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Online Views, Join Clicks, visitor activity and conversion reports are not tracked in this offline version. These require backend storage and event tracking, which will be added in a future update.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 9, top: 18),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return PageScaffold(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle(context, 'Appearance'),
          Card(
            child: Column(
              children: [
                RadioGroup<ThemeMode>(
                  groupValue: mode,
                  onChanged: (value) async {
                    if (value == null) return;

                    ref.read(themeModeProvider.notifier).state = value;

                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(
                      'wlink_theme',
                      value == ThemeMode.dark ? 'dark' : 'light',
                    );
                  },
                  child: Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.light,
                        title: const Text('Light Mode'),
                        subtitle: const Text('Use a bright appearance'),
                        secondary: const Icon(Icons.light_mode_outlined),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.dark,
                        title: const Text('Dark Mode'),
                        subtitle: const Text('Use a darker appearance'),
                        secondary: const Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _sectionTitle(context, 'Administration'),
          FeatureTile(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Admin Login',
            subtitle: 'Secure access for authorized administrators',
            onTap: () => context.push('/admin'),
          ),

          _sectionTitle(context, 'Membership & Account'),
          FeatureTile(
            icon: Icons.workspace_premium_outlined,
            title: 'Membership Plans',
            subtitle: 'View Ad-Free and Unlimited plans',
            onTap: () => context.push('/membership'),
          ),

          _sectionTitle(context, 'Help & Support'),
          FeatureTile(
            icon: Icons.support_agent_outlined,
            title: 'Support Center',
            subtitle: 'Create a support ticket',
            onTap: () => context.push('/support'),
          ),

          _sectionTitle(context, 'Privacy & Information'),
          FeatureTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy & Security',
            subtitle: 'Understand how your data is stored',
            onTap: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Privacy & Security'),
                content: const SingleChildScrollView(
                  child: Text(
                    'YOUR DATA\\n'
                    'Groups and Saved Groups are stored locally on this device.\\n\\n'
                    'NO ONLINE ACCOUNT\\n'
                    'This version does not use Firebase or online accounts.\\n\\n'
                    'DEVICE STORAGE\\n'
                    'Removing app data or uninstalling the app may erase locally stored information.\\n\\n'
                    'FUTURE FEATURES\\n'
                    'Online accounts, cloud backup and additional security features are planned for a future update.',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
          FeatureTile(
            icon: Icons.info_outline,
            title: 'About W-Link Join',
            subtitle: 'Discover Groups. Connect People.',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'W-Link Join',
              applicationVersion: '2.0',
              applicationLegalese: 'Discover Groups. Connect People.',
            ),
          ),

          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current App Version',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'This version stores group data locally. Online accounts, membership payments, cloud analytics and advertising integrations are not active in this build.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'W-Link Join',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppTheme.green,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Discover Groups. Connect People.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// GROUP DETAILS - EMPTY UNTIL REAL BACKEND DATA EXISTS
// -----------------------------------------------------------------------------

class GroupDetailsScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHindi = ref.watch(languageProvider) == AppLanguage.hindi;
    final groupsAsync = ref.watch(groupsProvider);
    final savedAsync = ref.watch(savedGroupIdsProvider);

    return groupsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text(isHindi ? 'Group Details' : 'Group Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(
          title: Text(isHindi ? 'Group Details' : 'Group Details'),
        ),
        body: Center(
          child: Text(
            isHindi ? 'डेटा लोड नहीं हुआ।' : 'Could not load group data.',
          ),
        ),
      ),
      data: (groups) {
        final matches = groups.where((group) => group.id == groupId);

        if (matches.isEmpty) {
          return PageScaffold(
            title: isHindi ? 'Group Details' : 'Group Details',
            body: EmptyState(
              icon: Icons.groups_outlined,
              title: isHindi ? 'Group उपलब्ध नहीं है' : 'Group unavailable',
              message: isHindi
                  ? 'यह Group इस फोन में नहीं मिला।'
                  : 'This group was not found on this device.',
              action: OutlinedButton(
                onPressed: () => context.go('/explore'),
                child: Text(isHindi ? 'वापस जाएँ' : 'Go back'),
              ),
            ),
          );
        }

        final group = matches.first;

        return savedAsync.when(
          loading: () => Scaffold(
            appBar: AppBar(title: Text(group.name)),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Scaffold(
            appBar: AppBar(title: Text(group.name)),
            body: Center(
              child: Text(
                isHindi
                    ? 'Saved डेटा लोड नहीं हुआ।'
                    : 'Could not load saved data.',
              ),
            ),
          ),
          data: (savedIds) {
            final isSaved = savedIds.contains(group.id);

            return PopScope<Object?>(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) async {
                if (didPop) return;
                await WLinkInterstitialController.showIfReady();
                if (context.mounted) context.go('/explore');
              },
              child: Scaffold(
                appBar: AppBar(
                  title: Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: [
                    IconButton(
                      tooltip: isHindi ? 'Save करें' : 'Save group',
                      icon: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                      ),
                      onPressed: () async {
                        await ref
                            .read(groupRepositoryProvider)
                            .toggleSaved(group.id);
                        ref.invalidate(savedGroupIdsProvider);
                      },
                    ),
                  ],
                ),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _buildGroupImage(
                        group.imageUrl,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 200,
                          width: double.infinity,
                          color: Theme.of(context).colorScheme.primaryContainer,
                          alignment: Alignment.center,
                          child: const Icon(Icons.groups_rounded, size: 76),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      group.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(group.category)),
                        Chip(label: Text(group.language)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _detailSection(
                      context,
                      'Description & Rules',
                      group.description,
                    ),
                    if (group.rules.trim().isNotEmpty)
                      _detailSection(context, 'Group Rules', group.rules),
                    _detailSection(
                      context,
                      isHindi ? 'स्थान' : 'Location',
                      '${group.city}, ${group.state}, ${group.country}',
                    ),
                    if (group.showOwnerContact && group.ownerContact.isNotEmpty)
                      _detailSection(
                        context,
                        isHindi ? 'Owner Contact' : 'Owner Contact',
                        group.ownerContact,
                      ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse(group.currentLink);
                          if (uri == null ||
                              !uri.hasScheme ||
                              (uri.scheme != 'https' && uri.scheme != 'http') ||
                              uri.host.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isHindi
                                      ? 'Invite Link सही नहीं है।'
                                      : 'Invalid invite link.',
                                ),
                              ),
                            );
                            return;
                          }

                          try {
                            final opened = await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                            if (!opened && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isHindi
                                        ? 'Link नहीं खुल सका।'
                                        : 'Could not open the link.',
                                  ),
                                ),
                              );
                            }
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isHindi
                                        ? 'Link खोलने में समस्या हुई।'
                                        : 'Unable to open the link.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.chat),
                        label: Text(
                          isHindi
                              ? 'WhatsApp Group Join करें'
                              : 'Join WhatsApp Group',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(groupRepositoryProvider)
                            .toggleSaved(group.id);
                        ref.invalidate(savedGroupIdsProvider);
                      },
                      icon: Icon(
                        isSaved
                            ? Icons.bookmark_remove
                            : Icons.bookmark_add_outlined,
                      ),
                      label: Text(
                        isSaved
                            ? (isHindi ? 'Saved से हटाएँ' : 'Remove from Saved')
                            : (isHindi
                                  ? 'Favourite में सेव करें'
                                  : 'Save to Favourites'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailSection(BuildContext context, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          SelectableText(value),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SUPPORT
// -----------------------------------------------------------------------------

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  static const Map<String, List<String>> issueOptions = {
    'Account & Profile': [
      'Login or account access',
      'Profile details',
      'Account settings',
    ],
    'Group Submission': [
      'Cannot submit a group',
      'Submission form issue',
      'Submission limit question',
    ],
    'Group Link': [
      'Invite link is invalid',
      'Group link has expired',
      'Cannot join a group',
    ],
    'Group Listing': [
      'Wrong group information',
      'Duplicate group',
      'Report inappropriate group',
    ],
    'Saved Groups': ['Cannot save a group', 'Saved group is missing'],
    'App & Technical': [
      'App not opening',
      'App is slow or freezing',
      'Display or navigation issue',
    ],
    'Privacy & Safety': [
      'Report spam or scam',
      'Privacy concern',
      'Abusive or harmful content',
    ],
    'Other': ['Suggestion or feedback', 'Other issue'],
  };

  String? selectedCategory;
  String? selectedIssue;
  final messageController = TextEditingController();
  bool isSaving = false;

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (selectedCategory == null ||
        selectedIssue == null ||
        messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select an issue category, issue type, and describe your issue.',
          ),
        ),
      );
      return;
    }
    if (isSaving) return;
    setState(() => isSaving = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south2')
          .httpsCallable('createSupportTicket');

      await callable.call({
        'category': selectedCategory,
        'issue': selectedIssue,
        'message': messageController.text.trim(),
      });

      if (!mounted) return;
      messageController.clear();
      setState(() {
        selectedCategory = null;
        selectedIssue = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Support request submitted successfully.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save your support request. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support Center')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Choose the issue that best describes your problem and send us the details.',
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 18),
          const _FieldLabel('Issue Category *'),
          DropdownButtonFormField<String>(
            initialValue: selectedCategory,
            isExpanded: true,
            decoration: const InputDecoration(
              hintText: 'Select issue category',
            ),
            items: issueOptions.keys
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) => setState(() {
              selectedCategory = value;
              selectedIssue = null;
            }),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Select Issue *'),
          DropdownButtonFormField<String>(
            initialValue: selectedIssue,
            isExpanded: true,
            decoration: const InputDecoration(hintText: 'Select your issue'),
            items:
                (selectedCategory == null
                        ? <String>[]
                        : issueOptions[selectedCategory] ?? <String>[])
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
            onChanged: selectedCategory == null
                ? null
                : (value) => setState(() => selectedIssue = value),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Describe Your Issue *'),
          TextField(
            controller: messageController,
            minLines: 5,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Describe your issue in detail...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: isSaving ? null : _submitTicket,
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: const Text('Submit Support Request'),
          ),
        ],
      ),
    );
  }
}

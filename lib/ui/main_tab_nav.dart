import 'package:fore_last_stand/meta/progression.dart';
import 'package:fore_last_stand/ui/run_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:fore_last_stand/ui/home_screen.dart';
import 'package:fore_last_stand/meta/profile_store.dart';
import 'package:fore_last_stand/ui/bag_screen.dart';
import 'package:fore_last_stand/ui/caddies_screen.dart';
import 'package:fore_last_stand/ui/clubhouse_screen.dart';
import 'package:fore_last_stand/ui/bestiary_screen.dart';
import 'package:fore_last_stand/ui/settings_screen.dart';

class MainTabNav extends StatefulWidget {
  const new({super.key, required this.store});

  final ProfileStore store;

  @override
  State<MainTabNav> createState() => _MainTabNavState();
}

class _MainTabNavState extends State<MainTabNav> {
  int _currentIndex = 2; // start on home_screen

  void _goToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _welcomeTutorialSeen() {
    widget.store.update((p) {
      if (!p.tutorialSeen.contains('welcome')) {
        p.tutorialSeen.add('welcome');
      }
    });
  }

  Widget _buildTutorialCard(ProfileStore store) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Welcome to Fore! Last Stand',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: () {
                _welcomeTutorialSeen();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const Text(
          'The course is overrun with zombie animals and you are the last one standing. Two places to learn the ropes:\n\n'
          '⛳ Driving Range: a guided tutorial on swinging, clubs, towers and Mulligan cards, then free practice on targets.\n\n'
          '📖 Bestiary: what every animal does and which clubs and towers counter it.',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: () {
                widget.store.update((p) {
                  if (!p.tutorialSeen.contains('welcome')) {
                    p.tutorialSeen.add('welcome');
                  }
                });
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RunScreen(
                      store: widget.store,
                      config: rangeConfigFor(widget.store.profile),
                    ),
                  ),
                );
              },
              child: const Text('Open Driving Range'),
            ),
            OutlinedButton(
              onPressed: () {
                _welcomeTutorialSeen();
                _goToTab(4);
              },
              child: const Text('Read animal guide'),
            ),
          ],
        ),
      ],
    );
  }

  void _showTutorialCardIfNeeded() {
    final store = widget.store;
    final p = store.profile;
    if (!p.tutorialSeen.contains('welcome')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(content: _buildTutorialCard(store)),
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _showTutorialCardIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // lockedText: p.bagUnlocked ? null : 'after 3 rounds',
          BagScreen(store: widget.store),

          // lockedText: p.clubhouseUnlocked ? null : 'after 2 rounds',
          ClubhouseScreen(store: widget.store),

          HomeScreen(store: widget.store),

          CaddiesScreen(store: widget.store),

          BestiaryScreen(store: widget.store),

          // SettingsScreen(store: widget.store),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final p = widget.store.profile;
          return BottomNavigationBar(
            backgroundColor: const Color(0xFF33691E),
            currentIndex: _currentIndex,
            onTap: (index) {
              if (index == 0 && !p.bagUnlocked) return;
              if (index == 1 && !p.clubhouseUnlocked) return;
              _goToTab(index);
            },
            items: [
              BottomNavigationBarItem(
                icon: p.bagUnlocked
                    ? const Icon(Icons.sports_golf)
                    : const Icon(Icons.lock),
                label: 'The Bag',
                backgroundColor: const Color(0xFF33691E),
                tooltip: p.bagUnlocked ? null : 'Unlocked after 3 rounds',
              ),
              BottomNavigationBarItem(
                icon: p.clubhouseUnlocked
                    ? const Icon(Icons.house)
                    : const Icon(Icons.lock),
                label: 'Clubhouse',
                backgroundColor: const Color(0xFF33691E),
                tooltip: p.clubhouseUnlocked ? null : 'Unlocked after 2 rounds',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.golf_course),
                label: 'Play',
                backgroundColor: Color(0xFF33691E),
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Caddies',
                backgroundColor: Color(0xFF33691E),
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.menu_book),
                label: 'Bestiary',
                backgroundColor: Color(0xFF33691E),
              ),
              // BottomNavigationBarItem(
              //   icon: Icon(Icons.settings),
              //   label: 'Settings',
              //   backgroundColor: Color(0xFF33691E),
              // ),
            ],
          );
        },
      ),
    );
  }
}

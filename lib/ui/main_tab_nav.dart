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
              setState(() {
                _currentIndex = index;
              });
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

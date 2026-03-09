import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/climbing_models.dart';
import 'create_route.dart';
import 'library_screen.dart';
import 'friends_tab.dart';
import 'profile_screen.dart';
import 'data/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final List<ClimbingRoute> _savedRoutes = [];

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);
  void _addRoute(ClimbingRoute route) => setState(() => _savedRoutes.add(route));

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      CreateRouteScreen(onRouteSaved: _addRoute),
      LibraryScreen(),
      const FriendsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false,
        title: Text(
          ['Create Route', 'Library', 'Friends'][_selectedIndex],
        ),
        actions: [
          StreamBuilder<AuthState>(
            stream: AuthService.instance.authStateChanges,
            builder: (context, _) {
              final loggedIn = AuthService.instance.isLoggedIn;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  icon: Icon(
                    loggedIn ? Icons.account_circle : Icons.account_circle_outlined,
                  ),
                  label: const Text('Profile'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.add_photo_alternate),
            label: 'Create',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Friends',
          ),
        ],
      ),
    );
  }
}
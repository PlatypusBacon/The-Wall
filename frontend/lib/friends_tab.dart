import 'package:flutter/material.dart';
import 'data/auth_service.dart';
import 'data/friends_service.dart';
import 'data/climbing_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'dart:async';
import 'shared_route_detail_screen.dart';
// At the top of friends_tab.dart, outside the classes:
final GlobalKey<_FriendsListTabState> friendsListKey = GlobalKey<_FriendsListTabState>();
class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // In _FriendsTabState, add:
  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        friendsListKey.currentState?._load();
      }
    });
    // Rebuild when auth state changes
    _authSub = AuthService.instance.authStateChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.instance.isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Sign in to connect with friends\nand see their shared routes',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              child: const Text('Sign In'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Feed'),
            Tab(text: 'Friends'),
            Tab(text: 'Requests'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _FriendsFeedTab(),
              _FriendsListTab(key: friendsListKey),
              _PendingRequestsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Feed ──────────────────────────────────────────────────────────────────────

class _FriendsFeedTab extends StatefulWidget {
  const _FriendsFeedTab();

  @override
  State<_FriendsFeedTab> createState() => _FriendsFeedTabState();
}

class _FriendsFeedTabState extends State<_FriendsFeedTab> {
  List<Map<String, dynamic>> _routes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final routes = await FriendsService.instance.getFriendsRoutes();
      if (mounted) setState(() { _routes = routes; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_routes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text('No shared routes yet.\nAdd friends to see their routes!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _routes.length,
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SharedRouteDetailScreen(routeData: _routes[i]),
            ),
          ),
          child: _SharedRouteCard(route: _routes[i]),
        ),
      ),
    );
  }
}

class _SharedRouteCard extends StatelessWidget {
  final Map<String, dynamic> route;
  const _SharedRouteCard({required this.route});

  @override
  Widget build(BuildContext context) {
    final username = route['profiles']?['username'] ?? 'unknown';
    final imageUrl = route['image_url'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 180,
                color: Colors.grey[200],
                child: const Icon(Icons.image_not_supported, size: 48),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 14)),
                    const SizedBox(width: 8),
                    Text('@$username',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(route['name'] ?? '',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    Chip(
                      label: Text(route['difficulty'] ?? ''),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                    ),
                    if (route['is_sequence_climb'] == true)
                      Chip(
                        label: const Text('Sequence'),
                        avatar: const Icon(Icons.format_list_numbered, size: 14),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.purple[100],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Friends list ──────────────────────────────────────────────────────────────

class _FriendsListTab extends StatefulWidget {
  const _FriendsListTab({super.key});

  @override
  State<_FriendsListTab> createState() => _FriendsListTabState();
}

class _FriendsListTabState extends State<_FriendsListTab> {
  List<Map<String, dynamic>> _friends = [];
  bool _loading = true;
  final _searchController = TextEditingController();
  Map<String, dynamic>? _searchResult;
  bool _searching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final friends = await FriendsService.instance.getFriends();
      if (mounted) setState(() { _friends = friends; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() { _searching = true; _searchResult = null; _searchError = null; });

    try {
      final result = await FriendsService.instance.findByUsername(query);
      if (mounted) {
        setState(() {
          _searching = false;
          if (result == null) {
            _searchError = 'No user found with that username';
          } else if (result['id'] == AuthService.instance.currentUser?.id) {
            _searchError = "That's you!";
          } else {
            _searchResult = result;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() { _searching = false; _searchError = e.toString(); });
    }
  }

  Future<void> _sendRequest(String userId) async {
    try {
      await FriendsService.instance.sendRequest(userId);
      setState(() => _searchResult = null);
      _searchController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send request: $e')),
        );
      }
    }
  }

  Future<void> _removeFriend(String friendshipId, String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text('Remove @$username from your friends?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FriendsService.instance.declineOrRemove(friendshipId);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search by username...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _searching ? null : _search,
                child: _searching
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Find'),
              ),
            ],
          ),
        ),

        // Search result
        if (_searchError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_searchError!, style: const TextStyle(color: Colors.red)),
          ),
        if (_searchResult != null)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text('@${_searchResult!['username']}'),
              trailing: FilledButton(
                onPressed: () => _sendRequest(_searchResult!['id']),
                child: const Text('Add'),
              ),
            ),
          ),

        const Divider(),

        // Friends list
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_friends.isEmpty)
          const Expanded(
            child: Center(
              child: Text('No friends yet.\nSearch for someone above!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _friends.length,
                itemBuilder: (context, i) {
                  final f = _friends[i];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text('@${f['username']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
                      tooltip: 'Remove friend',
                      onPressed: () => _removeFriend(f['friendship_id'], f['username']),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

// ── Pending requests ──────────────────────────────────────────────────────────

class _PendingRequestsTab extends StatefulWidget {
  const _PendingRequestsTab();

  @override
  State<_PendingRequestsTab> createState() => _PendingRequestsTabState();
}

class _PendingRequestsTabState extends State<_PendingRequestsTab> {
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final pending = await FriendsService.instance.getPendingIncoming();
      if (mounted) setState(() { _pending = pending; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(String friendshipId, bool accept) async {
    if (accept) {
      await FriendsService.instance.acceptRequest(friendshipId);
    } else {
      await FriendsService.instance.declineOrRemove(friendshipId);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_pending.isEmpty) {
      return const Center(
        child: Text('No pending requests',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _pending.length,
        itemBuilder: (context, i) {
          final req = _pending[i];
          final username = req['profiles!friendships_requester_id_fkey']?['username'] ?? 'unknown';          return Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text('@$username'),
              subtitle: const Text('wants to be your friend'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    tooltip: 'Accept',
                    onPressed: () => _respond(req['id'], true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    tooltip: 'Decline',
                    onPressed: () => _respond(req['id'], false),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
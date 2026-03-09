import '../main.dart';
import 'auth_service.dart';
import 'climbing_models.dart';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class FriendsService {
  static final FriendsService instance = FriendsService._();
  FriendsService._();

  // ── Search ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> findByUsername(String username) async {
    return await supabase
        .from('profiles')
        .select('id, username')
        .eq('username', username)
        .maybeSingle();
  }

  // ── Requests ──────────────────────────────────────────────────────────────

  Future<void> sendRequest(String addresseeId) async {
    await supabase.from('friendships').insert({
      'requester_id': AuthService.instance.currentUser!.id,
      'addressee_id': addresseeId,
      'status': 'pending',
    });
  }

  Future<void> acceptRequest(String friendshipId) async {
    await supabase
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('id', friendshipId);
  }

  Future<void> declineOrRemove(String friendshipId) async {
    await supabase.from('friendships').delete().eq('id', friendshipId);
  }

  Future<String?> uploadRouteImage(String routeId, Uint8List bytes) async {
    final uid = AuthService.instance.currentUser!.id;
    final path = '$uid/$routeId.jpg';  // e.g. "2e88ea18-.../1772776624439.jpg"
    await supabase.storage.from('route-images').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      retryAttempts: 3,
    );
    return supabase.storage.from('route-images').getPublicUrl(path);
  }

  // ── Fetch lists ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getFriends() async {
    final uid = AuthService.instance.currentUser!.id;
    
    // Get accepted friendships without trying to join profiles twice
    final rows = await supabase
        .from('friendships')
        .select('id, requester_id, addressee_id')
        .eq('status', 'accepted')
        .or('requester_id.eq.$uid,addressee_id.eq.$uid');

    if (rows.isEmpty) return [];

    // Collect the friend user IDs
    final friendIds = rows.map((row) {
      return row['requester_id'] == uid
          ? row['addressee_id'] as String
          : row['requester_id'] as String;
    }).toList();

    // Fetch their usernames in one query
    final profiles = await supabase
        .from('profiles')
        .select('id, username')
        .inFilter('id', friendIds);

    // Map profile id -> username for easy lookup
    final usernameMap = {
      for (final p in profiles) p['id'] as String: p['username'] as String
    };

    return rows.map((row) {
      final isRequester = row['requester_id'] == uid;
      final friendId = isRequester
          ? row['addressee_id'] as String
          : row['requester_id'] as String;
      return {
        'friendship_id': row['id'],
        'user_id': friendId,
        'username': usernameMap[friendId] ?? 'unknown',
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getPendingIncoming() async {
  final uid = AuthService.instance.currentUser!.id;
  return await supabase
      .from('friendships')
      .select('id, requester_id, profiles!friendships_requester_id_fkey(username)')
      .eq('addressee_id', uid)
      .eq('status', 'pending');
}

  // ── Shared routes ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getFriendsRoutes() async {
    return await supabase
        .from('shared_routes')
        .select('*, profiles(username)')
        .order('created_at', ascending: false);
  }

  Future<void> shareRoute(ClimbingRoute route, String imageUrl) async {
    await supabase.from('shared_routes').upsert({
      'id': route.id,
      'user_id': AuthService.instance.currentUser!.id,
      'name': route.name,
      'difficulty': route.difficulty,
      'is_sequence_climb': route.isSequenceClimb,
      'selected_holds':
          route.selectedHolds.map((h) => h.toMap()).toList(),
      'all_holds': route.allHolds.map((h) => h.toMap()).toList(),
      'image_url': imageUrl,
      'image_width': route.imageSize?.width ?? 0,
      'image_height': route.imageSize?.height ?? 0,
    });
  }

  Future<void> unshareRoute(String routeId) async {
    await supabase.from('shared_routes').delete().eq('id', routeId);
  }

  Future<bool> isRouteShared(String routeId) async {
    final row = await supabase
        .from('shared_routes')
        .select('id')
        .eq('id', routeId)
        .maybeSingle();
    return row != null;
  }
}
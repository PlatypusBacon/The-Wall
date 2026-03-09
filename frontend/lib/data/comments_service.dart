import '../main.dart';
import 'auth_service.dart';

class CommentsService {
  static final CommentsService instance = CommentsService._();
  CommentsService._();

  Future<List<Map<String, dynamic>>> getComments(String routeId) async {
    return await supabase
        .from('route_comments')
        .select('id, body, created_at, user_id, profiles(username)')
        .eq('route_id', routeId)
        .order('created_at', ascending: true);
  }

  Future<void> addComment(String routeId, String body) async {
    await supabase.from('route_comments').insert({
      'route_id': routeId,
      'user_id': AuthService.instance.currentUser!.id,
      'body': body,
    });
  }

  Future<void> deleteComment(String commentId) async {
    await supabase.from('route_comments').delete().eq('id', commentId);
  }
}
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// Central data layer. All data lives under users/{uid}/... exactly like the
/// web app, so trips/todos interoperate across web and mobile.
///
/// Workspace model (identical to the web app):
///   - Personal collections (notes, habits, expenses, ...) always read/write
///     under YOUR uid.
///   - Shared collections (trips, todos) read/write under the ACTIVE workspace
///     uid, which may be another user who shared their workspace with you.
class DbService {
  DbService._();
  static final DbService instance = DbService._();

  final FirebaseDatabase _fb = FirebaseDatabase.instance;

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  /// Set by WorkspaceProvider whenever the active workspace changes.
  String? activeWorkspaceUid;

  String? get _wsUid => activeWorkspaceUid ?? uid;

  DatabaseReference _node(String collection, {bool workspace = false}) =>
      _fb.ref('users/${workspace ? _wsUid : uid}/$collection');

  /// Live stream of a collection as a list of maps (id included).
  Stream<List<Map<String, dynamic>>> stream(String collection,
      {bool workspace = false}) {
    return _node(collection, workspace: workspace).onValue.map((event) {
      final list = <Map<String, dynamic>>[];
      final val = event.snapshot.value;
      if (val is Map) {
        val.forEach((key, value) {
          if (value is Map) {
            final m = Map<String, dynamic>.from(value);
            m['id'] = key;
            list.add(m);
          }
        });
      }
      return list;
    });
  }

  Future<String> add(String collection, Map<String, dynamic> data,
      {bool workspace = false}) async {
    final ref = _node(collection, workspace: workspace).push();
    await ref.set(data);
    return ref.key!;
  }

  Future<void> set(String collection, String id, Map<String, dynamic> data,
          {bool workspace = false}) =>
      _node(collection, workspace: workspace).child(id).set(data);

  Future<void> update(String collection, String id, Map<String, dynamic> data,
          {bool workspace = false}) =>
      _node(collection, workspace: workspace).child(id).update(data);

  Future<void> remove(String collection, String id, {bool workspace = false}) =>
      _node(collection, workspace: workspace).child(id).remove();

  // ---------------------------------------------------------------
  // Profile (same shape as the web app: users/{uid}/profile)
  // ---------------------------------------------------------------

  Future<Map<String, dynamic>?> getProfile() async {
    final snap = await _fb.ref('users/$uid/profile').get();
    final val = snap.value;
    if (val is Map) return Map<String, dynamic>.from(val);
    return null;
  }

  Stream<Map<String, dynamic>?> profileStream() {
    return _fb.ref('users/$uid/profile').onValue.map((e) {
      final val = e.snapshot.value;
      if (val is Map) return Map<String, dynamic>.from(val);
      return null;
    });
  }

  Future<void> saveProfile(String name, String phone) {
    return _fb.ref('users/$uid/profile').set({
      'name': name,
      'phone': phone,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  // ---------------------------------------------------------------
  // Workspace sharing (identical writes to the web app)
  // ---------------------------------------------------------------

  String escapeEmail(String email) =>
      email.toLowerCase().trim().replaceAll('.', ',');

  /// Look up a user by email via the emailToUid index.
  Future<String?> lookupUidByEmail(String email) async {
    final snap = await _fb.ref('emailToUid/${escapeEmail(email)}').get();
    final val = snap.value;
    if (val is Map) return val['uid'] as String?;
    return null;
  }

  /// Share my workspace with another user. Writes BOTH sides, like the web app.
  Future<void> shareWith(String email, String role) async {
    final targetUid = await lookupUidByEmail(email);
    if (targetUid == null) {
      throw Exception('User not found. They must create an account first.');
    }
    if (targetUid == uid) {
      throw Exception('You cannot share the workspace with yourself.');
    }

    await _fb.ref('users/$uid/collaborators/$targetUid').set({
      'email': email.trim(),
      'role': role,
    });

    final profile = await getProfile();
    final myName = profile?['name'] ?? 'Someone';

    await _fb.ref('users/$targetUid/sharedWithMe/$uid').set({
      'role': role,
      'ownerName': myName,
    });
  }

  /// Live role change - updates both sides so permissions take effect at once.
  Future<void> updateCollaboratorRole(String targetUid, String role) async {
    await _fb.ref('users/$uid/collaborators/$targetUid').update({'role': role});
    await _fb.ref('users/$targetUid/sharedWithMe/$uid').update({'role': role});
  }

  Future<void> removeCollaborator(String targetUid) async {
    await _fb.ref('users/$uid/collaborators/$targetUid').remove();
    await _fb.ref('users/$targetUid/sharedWithMe/$uid').remove();
  }

  /// People I have shared MY workspace with.
  Stream<List<Map<String, dynamic>>> collaboratorsStream() {
    return _fb.ref('users/$uid/collaborators').onValue.map((e) {
      final out = <Map<String, dynamic>>[];
      final val = e.snapshot.value;
      if (val is Map) {
        val.forEach((key, value) {
          if (value is Map) {
            final m = Map<String, dynamic>.from(value);
            m['uid'] = key;
            out.add(m);
          }
        });
      }
      return out;
    });
  }

  /// Workspaces other people have shared WITH me.
  Stream<List<Map<String, dynamic>>> sharedWithMeStream() {
    return _fb.ref('users/$uid/sharedWithMe').onValue.map((e) {
      final out = <Map<String, dynamic>>[];
      final val = e.snapshot.value;
      if (val is Map) {
        val.forEach((key, value) {
          if (value is Map) {
            final m = Map<String, dynamic>.from(value);
            m['uid'] = key;
            out.add(m);
          }
        });
      }
      return out;
    });
  }

  /// One-shot read of every collection for the current user (used by export).
  Future<Map<String, dynamic>> exportAll() async {
    final snap = await _fb.ref('users/$uid').get();
    final val = snap.value;
    if (val is Map) return Map<String, dynamic>.from(val);
    return {};
  }
}

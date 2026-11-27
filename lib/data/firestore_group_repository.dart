import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/group_model.dart';

class FirestoreGroupRepository {
  FirestoreGroupRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _functions = functions ??
           FirebaseFunctions.instanceFor(region: 'asia-south2');

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection('groups');

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Authentication required.');
    }
    return user.uid;
  }

  // Submit a new group through the secure server function.
  Future<void> submitGroup(GroupModel group) async {
    _uid;

    final callable = _functions.httpsCallable('submitGroup');

    await callable.call({
      'group': group.toJson(),
    });
  }

  // Update an owner's group through the secure server function.
  Future<void> updateMyGroup(GroupModel group) async {
    _uid;

    final callable = _functions.httpsCallable('updateGroup');

    await callable.call({
      'group': group.toJson(),
    });
  }

  // Public listing: approved groups remain visible.
  Stream<List<GroupModel>> watchApprovedGroups() {
    return _groups
        .where('approvalStatus', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => GroupModel.fromJson({...doc.data(), 'id': doc.id}))
              .toList(),
        );
  }

  // Owners can view their own submissions.
  Stream<List<GroupModel>> watchMyGroups() {
    return _groups
        .where('ownerUid', isEqualTo: _uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => GroupModel.fromJson({...doc.data(), 'id': doc.id}))
              .toList(),
        );
  }
}

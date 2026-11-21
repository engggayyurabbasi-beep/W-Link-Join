import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/group_model.dart';

class FirestoreGroupRepository {
  FirestoreGroupRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection('groups');

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Authentication required.');
    }
    return user.uid;
  }

  // Submit a new group. It becomes live immediately.
  Future<void> submitGroup(GroupModel group) async {
    final uid = _uid;

    final data = group.toJson()
      ..['ownerContact'] = group.showOwnerContact ? group.ownerContact : ''
      ..['ownerUid'] = uid
      ..['approvalStatus'] = 'approved'
      ..['verificationStatus'] = 'pending'
      ..['viewCount'] = 0
      ..['joinClickCount'] = 0
      ..['createdAt'] = Timestamp.fromDate(group.createdAt)
      ..['updatedAt'] = FieldValue.serverTimestamp();

    await _groups.doc(group.id).set(data);
  }

  // Update an owner's group without taking it offline.
  Future<void> updateMyGroup(GroupModel group) async {
    final uid = _uid;
    final doc = _groups.doc(group.id);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);

      if (!snapshot.exists) {
        throw StateError('Group not found.');
      }

      final existing = snapshot.data()!;
      if (existing['ownerUid'] != uid) {
        throw StateError('You are not allowed to edit this group.');
      }

      transaction.update(doc, {
        'name': group.name,
        'currentLink': group.currentLink,
        'previousLink': group.previousLink,
        'imageUrl': group.imageUrl,
        'category': group.category,
        'country': group.country,
        'state': group.state,
        'city': group.city,
        'language': group.language,
        'description': group.description,
        'rules': group.rules,
        'ownerContact': group.showOwnerContact ? group.ownerContact : '',
        'showOwnerContact': group.showOwnerContact,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Public listing: groups are live immediately after submission.
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

  // Owner can view their own submissions.
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

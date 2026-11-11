import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/firestore_paths.dart';

class LikeProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 좋아요 상태 변경
  Future<bool> toggleLike(String entryId, String authorId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // 자신의 글에는 좋아요 불가능
      if (user.uid == authorId) return false;

      final userLikesRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('likes')
          .doc(entryId);

      final entryRef = FirestorePaths.publicEntries(_firestore).doc(entryId);

      final likeDoc = await userLikesRef.get();

      // 트랜잭션으로 좋아요 처리
      bool isLiked = false;
      await _firestore.runTransaction((transaction) async {
        final entrySnapshot = await transaction.get(entryRef);

        if (!entrySnapshot.exists) {
          throw Exception('Entry does not exist!');
        }

        final currentLikeCount = (entrySnapshot.data()
                as Map<String, dynamic>)['likeCount'] as int? ??
            0;

        if (!likeDoc.exists) {
          // 좋아요 추가
          transaction.set(userLikesRef, {
            'entryId': entryId,
            'userId': authorId,
            'createdAt': FieldValue.serverTimestamp(),
          });

          transaction.update(entryRef, {
            'likeCount': currentLikeCount + 1,
          });

          isLiked = true;
        } else {
          // 좋아요 제거
          transaction.delete(userLikesRef);

          transaction.update(entryRef, {
            'likeCount': currentLikeCount > 0 ? currentLikeCount - 1 : 0,
          });

          isLiked = false;
        }
      });

      notifyListeners();
      return isLiked;
    } catch (e) {
      debugPrint('좋아요 토글 오류: $e');
      return false;
    }
  }

  // 좋아요 상태 확인
  Future<bool> isEntryLiked(String entryId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final likeDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('likes')
          .doc(entryId)
          .get();

      return likeDoc.exists;
    } catch (e) {
      debugPrint('좋아요 상태 확인 오류: $e');
      return false;
    }
  }

  // 좋아요한 항목 가져오기
  Future<List<Map<String, dynamic>>> getLikedEntries({String? topicId}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // 사용자의 좋아요 목록 가져오기
      final likesSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('likes')
          .orderBy('createdAt', descending: true)
          .get();

      if (likesSnapshot.docs.isEmpty) return [];

      // 좋아요한 항목의 ID 목록 추출
      final likedIds = likesSnapshot.docs
          .map((doc) => doc.data()['entryId'] as String?)
          .where((id) => id != null)
          .toList();

      if (likedIds.isEmpty) return [];

      // 결과 저장 리스트
      final List<Map<String, dynamic>> likedEntries = [];

      // 한 번에 10개씩 처리 (Firestore in 쿼리 제한)
      for (var i = 0; i < likedIds.length; i += 10) {
        final endIndex = (i + 10 < likedIds.length) ? i + 10 : likedIds.length;
        final chunk = likedIds.sublist(i, endIndex);

        final entriesSnapshot = await FirestorePaths.publicEntries(_firestore)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (var doc in entriesSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;

          // 특정 주제 ID가 제공된 경우, 해당 주제의 글만 필터링
          if (topicId != null && topicId.isNotEmpty) {
            if (data['topicId'] != topicId) {
              continue; // 주제가 일치하지 않으면 건너뛰기
            }
          }

          // 북마크 상태 확인
          final bookmarkDoc = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('bookmarks')
              .doc(doc.id)
              .get();

          data['isBookmarked'] = bookmarkDoc.exists;
          data['isLiked'] = true; // 이미 좋아요한 항목이므로

          likedEntries.add(data);
        }
      }

// 좋아요한 항목을 좋아요 순서에 맞게 재정렬
      final sortedEntries = <Map<String, dynamic>>[];
      for (var id in likedIds) {
        final entry = likedEntries.firstWhere(
          (entry) => entry['id'] == id,
          orElse: () => <String, dynamic>{},
        );
        if (entry.isNotEmpty) {
          sortedEntries.add(entry);
        }
      }

      return sortedEntries;
    } catch (e) {
      debugPrint('좋아요한 항목 가져오기 오류: $e');
      return [];
    }
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/firestore_paths.dart';

class BookmarkProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 북마크 상태 변경
  Future<bool> toggleBookmark(String entryId, String authorId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userBookmarksRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('bookmarks')
          .doc(entryId);

      final bookmarkDoc = await userBookmarksRef.get();

      if (!bookmarkDoc.exists) {
        // 북마크 추가
        await userBookmarksRef.set({
          'entryId': entryId,
          'userId': authorId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        notifyListeners();
        return true;
      } else {
        // 북마크 제거
        await userBookmarksRef.delete();

        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('북마크 토글 오류: $e');
      return false;
    }
  }

  // 북마크 상태 확인
  Future<bool> isEntryBookmarked(String entryId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final bookmarkDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('bookmarks')
          .doc(entryId)
          .get();

      return bookmarkDoc.exists;
    } catch (e) {
      debugPrint('북마크 상태 확인 오류: $e');
      return false;
    }
  }

  // 북마크된 항목 가져오기
  Future<List<Map<String, dynamic>>> getBookmarkedEntries(
      {String? topicId}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // 사용자의 북마크 목록 가져오기
      final bookmarksSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('bookmarks')
          .orderBy('createdAt', descending: true)
          .get();

      if (bookmarksSnapshot.docs.isEmpty) return [];

      // 북마크된 항목의 ID 목록 추출
      final bookmarkedIds = bookmarksSnapshot.docs
          .map((doc) => doc.data()['entryId'] as String?)
          .where((id) => id != null)
          .toList();

      if (bookmarkedIds.isEmpty) return [];

      // 결과 저장 리스트
      final List<Map<String, dynamic>> bookmarkedEntries = [];

      // 한 번에 10개씩 처리 (Firestore in 쿼리 제한)
      for (var i = 0; i < bookmarkedIds.length; i += 10) {
        final endIndex =
            (i + 10 < bookmarkedIds.length) ? i + 10 : bookmarkedIds.length;
        final chunk = bookmarkedIds.sublist(i, endIndex);

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

          // 좋아요 상태 확인
          final likeDoc = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('likes')
              .doc(doc.id)
              .get();

          data['isLiked'] = likeDoc.exists;
          data['isBookmarked'] = true; // 이미 북마크된 항목이므로

          bookmarkedEntries.add(data);
        }
      }

      // 북마크된 항목을 북마크 순서에 맞게 재정렬
      final sortedEntries = <Map<String, dynamic>>[];
      for (var id in bookmarkedIds) {
        final entry = bookmarkedEntries.firstWhere(
          (entry) => entry['id'] == id,
          orElse: () => <String, dynamic>{},
        );
        if (entry.isNotEmpty) {
          sortedEntries.add(entry);
        }
      }

      return sortedEntries;
    } catch (e) {
      debugPrint('북마크된 항목 가져오기 오류: $e');
      return [];
    }
  }
}

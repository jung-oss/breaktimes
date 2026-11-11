import 'package:cloud_firestore/cloud_firestore.dart';

/// Firebase Firestore 경로를 일관되게 관리하기 위한 유틸리티 클래스
class FirestorePaths {
  // 주제 관련 경로
  static const String topicsCollection = 'topics';
  static const String topicDocument = 'topic';
  static const String itemsCollection = 'items';

  // 주제 문서 참조 가져오기
  static DocumentReference getTopicDocumentRef(FirebaseFirestore firestore) {
    return firestore.collection(topicsCollection).doc(topicDocument);
  }

  // 특정 주제 항목 참조 가져오기
  static DocumentReference getTopicItemRef(
      FirebaseFirestore firestore, String itemId) {
    return getTopicDocumentRef(firestore)
        .collection(itemsCollection)
        .doc(itemId);
  }

  // 현재 활성화된 주제 가져오기
  static Future<DocumentSnapshot?> getActiveTopicItem(
      FirebaseFirestore firestore) async {
    try {
      final querySnapshot = await getTopicDocumentRef(firestore)
          .collection(itemsCollection)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first;
      }
      return null;
    } catch (e) {
      print('활성화된 주제 가져오기 오류: $e');
      return null;
    }
  }

  static CollectionReference todoItems(FirebaseFirestore firestore) {
    return firestore.collection('topics').doc('todo').collection('items');
  }

  // 사용자 관련 경로
  static DocumentReference userDoc(FirebaseFirestore firestore, String userId) {
    return firestore.collection('users').doc(userId);
  }

  static CollectionReference userMoods(
      FirebaseFirestore firestore, String userId) {
    return firestore.collection('users').doc(userId).collection('moods');
  }

  static CollectionReference userTodos(
      FirebaseFirestore firestore, String userId) {
    return firestore.collection('users').doc(userId).collection('todos');
  }

  static CollectionReference userProgress(
      FirebaseFirestore firestore, String userId) {
    return firestore.collection('users').doc(userId).collection('progress');
  }

  static CollectionReference userUsedTopics(
      FirebaseFirestore firestore, String userId) {
    return firestore.collection('users').doc(userId).collection('used_topics');
  }

  // 공개 글 관련 경로
  static CollectionReference publicEntries(FirebaseFirestore firestore) {
    return firestore.collection('publicEntries');
  }

  // 공개 격려 메시지 컬렉션 (필요한 경우)
  static CollectionReference publicMotivations(FirebaseFirestore firestore) {
    return firestore.collection('publicMotivations');
  }

  // 명언 컬렉션
  static CollectionReference quotes(FirebaseFirestore firestore) {
    return firestore.collection('quotes');
  }
}

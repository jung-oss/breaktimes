// lib/happiness_shop_2/categories/vitamin/services/vitamin_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/vitamin_slot.dart';
import '../models/vitamin_content.dart';
import '../../../common/services/love_ledger.dart';
import '../../../common/services/shop_functions.dart';

/// 행복 비타민 서비스 (기존 슬롯 시스템)
class VitaminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int SLOT_PRICE = 5; // 하트 5개
  static const int DEFAULT_SLOTS = 1; // 기본 슬롯 1개
  static const int MAX_SLOTS = 20; // 최대 슬롯 20개

  String get userId => _auth.currentUser?.uid ?? '';

  /// 사용자 슬롯 정보 가져오기
  Future<Map<String, int>> getUserSlotInfo() async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data() ?? {};

      return {
        'heartCount': data['heartCount'] ?? 0,
        'slotCount': data['slotCount'] ?? DEFAULT_SLOTS,
        'maxSlots': data['maxSlots'] ?? MAX_SLOTS,
      };
    } catch (e) {
      throw Exception('Failed to get user slot info: $e');
    }
  }

  /// 슬롯 늘리기(서버 함수 shopPurchaseSlot, 사랑하기 5개)
  ///
  /// 성공하면 true. 부족·최대·연결 문제는 false(사랑하기는 그대로)입니다.
  Future<bool> purchaseSlot() async {
    try {
      final result = await ShopFunctions.call('shopPurchaseSlot');
      LoveLedger.track(LoveLedgerEntry(
        isEarn: false,
        amount: SLOT_PRICE,
        reason: LoveReason.vitaminSlot,
        balanceAfter: (result['balanceAfter'] as num?)?.toInt() ?? 0,
      ));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 사용자의 모든 슬롯 가져오기 (Stream)
  Stream<List<VitaminSlot>> getUserSlotsStream() {
    return _firestore
        .collection('happiness_slots')
        .where('userId', isEqualTo: userId)
        .orderBy('slotIndex')
        .snapshots()
        .map((snapshot) {
      // 예전에 같은 번호 슬롯이 여러 개 생긴 경우, 빈 슬롯 복사본만 숨깁니다.
      // 내용이 있는 슬롯은 하나도 숨기지 않습니다.
      final groups = <int, List<VitaminSlot>>{};
      for (final doc in snapshot.docs) {
        final slot = VitaminSlot.fromFirestore(doc);
        groups.putIfAbsent(slot.slotIndex, () => []).add(slot);
      }
      final slots = <VitaminSlot>[];
      for (final index in groups.keys.toList()..sort()) {
        final group = groups[index]!;
        final filled = group.where((slot) => !slot.isEmpty).toList();
        slots.addAll(filled.isNotEmpty ? filled : [group.first]);
      }
      return slots;
    });
  }

  /// 이 앱에서 진행 중인 슬롯 초기화(두 화면이 동시에 불러도 한 번만 실행)
  static Future<void>? _initializing;

  /// 빈 슬롯 초기화
  Future<void> initializeEmptySlots(int slotCount) {
    final running = _initializing;
    if (running != null) return running;
    final future = _initializeEmptySlots(slotCount);
    _initializing = future;
    return future.whenComplete(() => _initializing = null);
  }

  Future<void> _initializeEmptySlots(int slotCount) async {
    try {
      final existingSlots = await _firestore
          .collection('happiness_slots')
          .where('userId', isEqualTo: userId)
          .get();

      final existingIndices = existingSlots.docs
          .map((doc) => doc.data()['slotIndex'] as int)
          .toSet();

      final batch = _firestore.batch();

      for (int i = 0; i < slotCount; i++) {
        if (!existingIndices.contains(i)) {
          final slotRef = _firestore.collection('happiness_slots').doc();
          batch.set(slotRef, {
            'userId': userId,
            'slotIndex': i,
            'type': VitaminSlotType.empty.name,
            'title': '',
            'isEmpty': true,
            'content': {},
            'colorIndex': i % 8,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to initialize slots: $e');
    }
  }

  /// 이미지 선택 및 업로드
  Future<Map<String, String>?> pickAndUploadImage(String slotId) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        // 스토리지 규칙 한도(5MB) 안에 들도록 미리 줄입니다
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );

      if (pickedFile == null) return null;

      final file = File(pickedFile.path);
      final fileSize = await file.length();

      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('Image size must be less than 5MB');
      }

      return await _uploadImage(file, slotId);
    } catch (e) {
      throw Exception('Failed to pick and upload image: $e');
    }
  }

  /// 이미지 업로드
  Future<Map<String, String>> _uploadImage(File imageFile, String slotId) async {
    try {
      final basePath = 'users/$userId/happiness_photos';

      final compressedRef = _storage.ref('$basePath/${slotId}_compressed.jpg');
      await compressedRef.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // 썸네일을 따로 만들 도구가 없어, 같은 파일을 두 번 올리지 않고 본 이미지 주소를 씁니다
      final compressedUrl = await compressedRef.getDownloadURL();
      final thumbnailUrl = compressedUrl;

      return {
        'storageUrl':
            'gs://${_storage.bucket}/$basePath/${slotId}_compressed.jpg',
        'thumbnailUrl': thumbnailUrl,
        'imageUrl': compressedUrl,
      };
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// 영상 선택 및 업로드
  Future<Map<String, dynamic>?> pickAndUploadVideo(String slotId) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (pickedFile == null) return null;

      final file = File(pickedFile.path);
      final fileSize = await file.length();

      if (fileSize > 50 * 1024 * 1024) {
        throw Exception('Video size must be less than 50MB');
      }

      return await _uploadVideo(file, slotId);
    } catch (e) {
      throw Exception('Failed to pick and upload video: $e');
    }
  }

  /// 영상 업로드
  Future<Map<String, dynamic>> _uploadVideo(File videoFile, String slotId) async {
    try {
      final basePath = 'users/$userId/happiness_videos';

      final compressedRef = _storage.ref('$basePath/${slotId}_compressed.mp4');
      await compressedRef.putFile(
        videoFile,
        SettableMetadata(contentType: 'video/mp4'),
      );

      // 전에는 올리지 않은 썸네일 주소를 읽어 업로드가 늘 실패했습니다.
      // 영상 썸네일은 만들 도구가 없으므로 비워 둡니다(화면은 썸네일이 없으면 그리지 않음).
      final compressedUrl = await compressedRef.getDownloadURL();
      const String? thumbnailUrl = null;

      return {
        'storageUrl':
            'gs://${_storage.bucket}/$basePath/${slotId}_compressed.mp4',
        'compressedUrl': compressedUrl,
        'thumbnailUrl': thumbnailUrl,
        'duration': 0,
        'width': 0,
        'height': 0,
        'fileSize': await videoFile.length(),
      };
    } catch (e) {
      throw Exception('Failed to upload video: $e');
    }
  }

  /// 슬롯에 콘텐츠 추가 (AI 명언 생성 포함)
  Future<void> addContentToSlot({
    required String slotId,
    required VitaminSlotType type,
    required String title,
    required VitaminContent content,
  }) async {
    try {
      // 1. 슬롯에 콘텐츠 저장
      await _firestore.collection('happiness_slots').doc(slotId).update({
        'type': type.name,
        'title': title,
        'isEmpty': false,
        'content': content.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. 텍스트가 있고 AI 명언이 없으면 백그라운드에서 생성
      if (content.text != null &&
          content.text!.isNotEmpty &&
          (content.aiQuote == null || content.aiQuote!.isEmpty)) {
        _generateQuoteInBackground(slotId, content.text!, content);
      }
    } catch (e) {
      throw Exception('Failed to add content to slot: $e');
    }
  }

  /// AI 글귀 만들기(서버 함수 vitaminGenerateQuote, 무료·하루 횟수 제한)
  ///
  /// 서버가 슬롯의 상태(pending → generated)와 글귀를 직접 저장합니다.
  Future<void> _generateQuoteInBackground(
      String slotId, String userText, VitaminContent content) async {
    try {
      await ShopFunctions.call('vitaminGenerateQuote', {'slotId': slotId});
    } catch (e) {
      // 실패해도 슬롯 내용은 그대로입니다. 다음에 수정하면 다시 만듭니다.
    }
  }

  /// 슬롯 수정
  Future<void> updateSlot({
    required String slotId,
    String? title,
    VitaminContent? content,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (title != null) updates['title'] = title;
      if (content != null) {
        updates['content'] = content.toMap();
        
        // 텍스트가 변경되고 AI 명언이 없으면 재생성
        if (content.text != null &&
            content.text!.isNotEmpty &&
            (content.aiQuote == null || content.aiQuote!.isEmpty)) {
          _generateQuoteInBackground(slotId, content.text!, content);
        }
      }

      await _firestore.collection('happiness_slots').doc(slotId).update(updates);
    } catch (e) {
      throw Exception('Failed to update slot: $e');
    }
  }

  /// 슬롯 콘텐츠 삭제
  Future<void> clearSlotContent(String slotId) async {
    try {
      final slot =
          await _firestore.collection('happiness_slots').doc(slotId).get();

      if (!slot.exists) {
        throw Exception('Slot not found');
      }

      final data = slot.data()!;
      final content = VitaminContent.fromMap(data['content'] ?? {});

      // Storage에서 파일 삭제
      if (content.storageUrl != null) {
        try {
          final ref = _storage.refFromURL(content.storageUrl!);
          await ref.delete();

          if (content.thumbnailUrl != null) {
            try {
              final thumbnailRef = _storage.refFromURL(content.thumbnailUrl!);
              await thumbnailRef.delete();
            } catch (e) {
              // 썸네일 삭제 실패는 무시
            }
          }
        } catch (e) {
          // 파일 삭제 실패는 무시
        }
      }

      // Firestore에서 콘텐츠 비우기
      await _firestore.collection('happiness_slots').doc(slotId).update({
        'type': VitaminSlotType.empty.name,
        'title': '',
        'isEmpty': true,
        'content': {},
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to clear slot content: $e');
    }
  }

  /// 슬롯 개수 확인 및 초기화
  Future<void> ensureSlotsInitialized() async {
    try {
      final slotInfo = await getUserSlotInfo();
      final slotCount = slotInfo['slotCount']!;
      await initializeEmptySlots(slotCount);
    } catch (e) {
      // 초기화 실패는 무시
    }
  }

  /// 랜덤 슬롯 가져오기
  Future<VitaminSlot?> getRandomSlot() async {
    try {
      final slots = await _firestore
          .collection('happiness_slots')
          .where('userId', isEqualTo: userId)
          .where('isEmpty', isEqualTo: false)
          .get();

      if (slots.docs.isEmpty) return null;

      final random = DateTime.now().millisecondsSinceEpoch % slots.docs.length;
      return VitaminSlot.fromFirestore(slots.docs[random]);
    } catch (e) {
      return null;
    }
  }
}


// lib/models/base_model.dart

/// 모든 모델의 기본 클래스
abstract class BaseModel {
  final String id;

  BaseModel({required this.id});

  Map<String, dynamic> toMap();

  // Firestore 변환 메서드 (필요시 하위 클래스에서 재정의)
  Map<String, dynamic> toFirestore() => toMap();
}

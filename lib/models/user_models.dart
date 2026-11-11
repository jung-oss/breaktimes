// lib/models/user_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'base_model.dart';

/// 사용자 권한 정의
enum UserRole {
  user,
  superAdmin,
  contentManager,
  analyst;

  String get displayName {
    switch (this) {
      case UserRole.user:
        return '일반 사용자';
      case UserRole.superAdmin:
        return '최고 관리자';
      case UserRole.contentManager:
        return '콘텐츠 관리자';
      case UserRole.analyst:
        return '데이터 분석가';
    }
  }
}

/// 사용자 모델
class UserModel extends BaseModel {
  final String? email;
  final String? displayName;
  final String? photoURL;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final Map<String, dynamic>? settings;
  final UserRole role;
  final int heartCount;
  final String? lastHeartDate;

  UserModel({
    required super.id,
    this.email,
    this.displayName,
    this.photoURL,
    this.createdAt,
    this.lastLoginAt,
    this.settings,
    this.role = UserRole.user,
    this.heartCount = 0,
    this.lastHeartDate,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'createdAt': createdAt,
      'lastLoginAt': lastLoginAt,
      'settings': settings,
      'role': role.index,
      'heartCount': heartCount,
      'lastHeartDate': lastHeartDate,
    };
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'lastLoginAt':
          lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'settings': settings,
      'role': role.index,
      'heartCount': heartCount,
      'lastHeartDate': lastHeartDate,
    };
  }

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserModel(
      id: doc.id,
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      photoURL: data['photoURL'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      settings: data['settings'] as Map<String, dynamic>?,
      role: UserRole.values[data['role'] as int? ?? 0],
      heartCount: data['heartCount'] as int? ?? 0,
      lastHeartDate: data['lastHeartDate'] as String?,
    );
  }

  factory UserModel.fromFirebaseUser(firebase_auth.User user) {
    return UserModel(
      id: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoURL: user.photoURL,
      createdAt: user.metadata.creationTime,
      lastLoginAt: user.metadata.lastSignInTime,
    );
  }

  UserModel copyWith({
    String? email,
    String? displayName,
    String? photoURL,
    DateTime? lastLoginAt,
    Map<String, dynamic>? settings,
    UserRole? role,
    int? heartCount,
    String? lastHeartDate,
  }) {
    return UserModel(
      id: id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      settings: settings ?? this.settings,
      role: role ?? this.role,
      heartCount: heartCount ?? this.heartCount,
      lastHeartDate: lastHeartDate ?? this.lastHeartDate,
    );
  }
}

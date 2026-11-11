// lib/happiness_shop_2/categories/vitamin/models/vitamin_slot.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'vitamin_content.dart';

enum VitaminSlotType {
  music,
  photo,
  video,
  videoUrl,
  quote,
  empty,
}

class VitaminSlot {
  final String id;
  final String userId;
  final int slotIndex;
  final VitaminSlotType type;
  final String title;
  final bool isEmpty;
  final VitaminContent content;
  final int colorIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  VitaminSlot({
    required this.id,
    required this.userId,
    required this.slotIndex,
    required this.type,
    required this.title,
    this.isEmpty = true,
    required this.content,
    required this.colorIndex,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VitaminSlot.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VitaminSlot(
      id: doc.id,
      userId: data['userId'] ?? '',
      slotIndex: data['slotIndex'] ?? 0,
      type: _parseSlotType(data['type'] ?? 'empty'),
      title: data['title'] ?? '',
      isEmpty: data['isEmpty'] ?? true,
      content: VitaminContent.fromMap(data['content'] ?? {}),
      colorIndex: data['colorIndex'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static VitaminSlotType _parseSlotType(String type) {
    switch (type) {
      case 'music':
        return VitaminSlotType.music;
      case 'photo':
        return VitaminSlotType.photo;
      case 'video':
        return VitaminSlotType.video;
      case 'videoUrl':
        return VitaminSlotType.videoUrl;
      case 'quote':
        return VitaminSlotType.quote;
      case 'empty':
      default:
        return VitaminSlotType.empty;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'slotIndex': slotIndex,
      'type': type.name,
      'title': title,
      'isEmpty': isEmpty,
      'content': content.toMap(),
      'colorIndex': colorIndex,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  VitaminSlot copyWith({
    String? title,
    VitaminSlotType? type,
    bool? isEmpty,
    VitaminContent? content,
    DateTime? updatedAt,
    String? aiQuote,
    DateTime? aiQuoteGeneratedAt,
    String? aiQuoteStatus,
    String? aiQuoteModel,
  }) {
    VitaminContent updatedContent = content ?? this.content;
    if (aiQuote != null ||
        aiQuoteGeneratedAt != null ||
        aiQuoteStatus != null ||
        aiQuoteModel != null) {
      updatedContent = updatedContent.copyWith(
        aiQuote: aiQuote,
        aiQuoteGeneratedAt: aiQuoteGeneratedAt,
        aiQuoteStatus: aiQuoteStatus,
        aiQuoteModel: aiQuoteModel,
      );
    }

    return VitaminSlot(
      id: id,
      userId: userId,
      slotIndex: slotIndex,
      type: type ?? this.type,
      title: title ?? this.title,
      isEmpty: isEmpty ?? this.isEmpty,
      content: updatedContent,
      colorIndex: colorIndex,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}


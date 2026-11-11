// lib/happiness_shop_2/categories/vitamin/models/vitamin_content.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class VitaminContent {
  // 공통
  final String? url;
  final String? text;
  final String? author;

  // 사진
  final String? storageUrl;
  final String? thumbnailUrl;
  final String? imageUrl;

  // 영상
  final String? compressedUrl;
  final int? duration;
  final int? width;
  final int? height;
  final int? fileSize;

  // AI 명언
  final String? aiQuote;
  final DateTime? aiQuoteGeneratedAt;
  final String? aiQuoteStatus;
  final String? aiQuoteModel;

  VitaminContent({
    this.url,
    this.text,
    this.author,
    this.storageUrl,
    this.thumbnailUrl,
    this.imageUrl,
    this.compressedUrl,
    this.duration,
    this.width,
    this.height,
    this.fileSize,
    this.aiQuote,
    this.aiQuoteGeneratedAt,
    this.aiQuoteStatus,
    this.aiQuoteModel,
  });

  factory VitaminContent.fromMap(Map<String, dynamic> map) {
    return VitaminContent(
      url: map['url'],
      text: map['text'],
      author: map['author'],
      storageUrl: map['storageUrl'],
      thumbnailUrl: map['thumbnailUrl'],
      imageUrl: map['imageUrl'],
      compressedUrl: map['compressedUrl'],
      duration: map['duration'],
      width: map['width'],
      height: map['height'],
      fileSize: map['fileSize'],
      aiQuote: map['aiQuote'],
      aiQuoteGeneratedAt: map['aiQuoteGeneratedAt'] is Timestamp
          ? (map['aiQuoteGeneratedAt'] as Timestamp).toDate()
          : map['aiQuoteGeneratedAt'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['aiQuoteGeneratedAt'])
              : null,
      aiQuoteStatus: map['aiQuoteStatus'],
      aiQuoteModel: map['aiQuoteModel'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (url != null) 'url': url,
      if (text != null) 'text': text,
      if (author != null) 'author': author,
      if (storageUrl != null) 'storageUrl': storageUrl,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (compressedUrl != null) 'compressedUrl': compressedUrl,
      if (duration != null) 'duration': duration,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (fileSize != null) 'fileSize': fileSize,
      if (aiQuote != null) 'aiQuote': aiQuote,
      if (aiQuoteGeneratedAt != null)
        'aiQuoteGeneratedAt': Timestamp.fromDate(aiQuoteGeneratedAt!),
      if (aiQuoteStatus != null) 'aiQuoteStatus': aiQuoteStatus,
      if (aiQuoteModel != null) 'aiQuoteModel': aiQuoteModel,
    };
  }

  VitaminContent copyWith({
    String? url,
    String? text,
    String? author,
    String? storageUrl,
    String? thumbnailUrl,
    String? imageUrl,
    String? compressedUrl,
    int? duration,
    int? width,
    int? height,
    int? fileSize,
    String? aiQuote,
    DateTime? aiQuoteGeneratedAt,
    String? aiQuoteStatus,
    String? aiQuoteModel,
  }) {
    return VitaminContent(
      url: url ?? this.url,
      text: text ?? this.text,
      author: author ?? this.author,
      storageUrl: storageUrl ?? this.storageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      compressedUrl: compressedUrl ?? this.compressedUrl,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
      fileSize: fileSize ?? this.fileSize,
      aiQuote: aiQuote ?? this.aiQuote,
      aiQuoteGeneratedAt: aiQuoteGeneratedAt ?? this.aiQuoteGeneratedAt,
      aiQuoteStatus: aiQuoteStatus ?? this.aiQuoteStatus,
      aiQuoteModel: aiQuoteModel ?? this.aiQuoteModel,
    );
  }
}


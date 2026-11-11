// lib/happiness_shop_2/categories/vitamin/screens/vitamin_add_screen.dart
import 'package:flutter/material.dart';
import '../models/vitamin_slot.dart';
import '../models/vitamin_content.dart';
import '../services/vitamin_service.dart';

class VitaminAddScreen extends StatefulWidget {
  final VitaminSlot slot;
  final VitaminSlotType type;
  final VitaminService service;

  const VitaminAddScreen({
    super.key,
    required this.slot,
    required this.type,
    required this.service,
  });

  @override
  State<VitaminAddScreen> createState() => _VitaminAddScreenState();
}

class _VitaminAddScreenState extends State<VitaminAddScreen> {
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _textController = TextEditingController();
  final _authorController = TextEditingController();
  final _memoController = TextEditingController(); // 메모용 컨트롤러
  bool _isLoading = false;
  bool _isUploading = false;
  Map<String, dynamic>? _uploadedImageData; // 업로드된 이미지 데이터
  Map<String, dynamic>? _uploadedVideoData; // 업로드된 영상 데이터

  @override
  void initState() {
    super.initState();
    if (!widget.slot.isEmpty) {
      _titleController.text = widget.slot.title;
      _urlController.text = widget.slot.content.url ?? '';
      _textController.text = widget.slot.content.text ?? '';
      _authorController.text = widget.slot.content.author ?? '';
      // 메모 로드: 명언 타입이 아닌 경우에만 text 필드에서 메모 로드
      if (widget.slot.type != VitaminSlotType.quote) {
        _memoController.text = widget.slot.content.text ?? '';
      } else {
        // 명언 타입의 경우 author 필드에 메모가 저장되어 있을 수 있음
        // (출처와 메모를 구분하기 어려우므로, 명언 타입에서는 메모를 저장하지 않거나
        // author 필드에 "출처 | 메모" 형식으로 저장)
        _memoController.text = '';
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _textController.dispose();
    _authorController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  /// 사진/영상 선택 및 업로드
  Future<void> _pickAndUploadMedia() async {
    final languageCode = Localizations.localeOf(context).languageCode;
    final isKorean = languageCode == 'ko';

    setState(() {
      _isUploading = true;
    });

    try {
      switch (widget.type) {
        case VitaminSlotType.photo:
          final imageData =
              await widget.service.pickAndUploadImage(widget.slot.id);
          if (imageData == null) {
            setState(() {
              _isUploading = false;
            });
            return;
          }
          setState(() {
            _uploadedImageData = imageData;
            _isUploading = false;
          });
          break;

        case VitaminSlotType.video:
          final videoData =
              await widget.service.pickAndUploadVideo(widget.slot.id);
          if (videoData == null) {
            setState(() {
              _isUploading = false;
            });
            return;
          }
          setState(() {
            _uploadedVideoData = videoData;
            _isUploading = false;
          });
          break;

        default:
          setState(() {
            _isUploading = false;
          });
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isKorean ? '업로드 중 오류가 발생했습니다: $e' : 'Upload error: $e',
            ),
          ),
        );
      }
    }
  }

  /// 최종 저장
  Future<void> _saveContent() async {
    final languageCode = Localizations.localeOf(context).languageCode;
    final isKorean = languageCode == 'ko';

    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isKorean ? '제목을 입력해주세요' : 'Please enter a title',
          ),
        ),
      );
      return;
    }

    // 사진/영상의 경우 업로드가 완료되어야 함
    if ((widget.type == VitaminSlotType.photo && _uploadedImageData == null) ||
        (widget.type == VitaminSlotType.video && _uploadedVideoData == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isKorean
                ? '사진 또는 영상을 먼저 선택해주세요'
                : 'Please select a photo or video first',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      VitaminContent content;

      switch (widget.type) {
        case VitaminSlotType.photo:
          content = VitaminContent(
            storageUrl: _uploadedImageData!['storageUrl'],
            thumbnailUrl: _uploadedImageData!['thumbnailUrl'],
            imageUrl: _uploadedImageData!['imageUrl'],
            text: _memoController.text.trim().isEmpty
                ? null
                : _memoController.text.trim(), // 메모 추가
          );
          break;

        case VitaminSlotType.video:
          content = VitaminContent(
            storageUrl: _uploadedVideoData!['storageUrl'],
            compressedUrl: _uploadedVideoData!['compressedUrl'],
            thumbnailUrl: _uploadedVideoData!['thumbnailUrl'],
            duration: _uploadedVideoData!['duration'],
            width: _uploadedVideoData!['width'],
            height: _uploadedVideoData!['height'],
            fileSize: _uploadedVideoData!['fileSize'],
            text: _memoController.text.trim().isEmpty
                ? null
                : _memoController.text.trim(), // 메모 추가
          );
          break;

        case VitaminSlotType.music:
        case VitaminSlotType.videoUrl:
          if (_urlController.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isKorean ? 'URL을 입력해주세요' : 'Please enter a URL',
                ),
              ),
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }
          content = VitaminContent(
            url: _urlController.text,
            text: _memoController.text.trim().isEmpty
                ? null
                : _memoController.text.trim(), // 메모 추가
          );
          break;

        case VitaminSlotType.quote:
          if (_textController.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isKorean ? '명언을 입력해주세요' : 'Please enter a quote',
                ),
              ),
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }
          content = VitaminContent(
            text: _textController.text,
            author:
                _authorController.text.isEmpty ? null : _authorController.text,
          );
          break;

        case VitaminSlotType.empty:
          setState(() {
            _isLoading = false;
          });
          return;
      }

      await widget.service.addContentToSlot(
        slotId: widget.slot.id,
        type: widget.type,
        title: _titleController.text,
        content: content,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isKorean ? '콘텐츠가 추가되었습니다! ✨' : 'Content added! ✨',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isKorean ? '오류가 발생했습니다: $e' : 'An error occurred: $e',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final isKorean = languageCode == 'ko';

    return Scaffold(
      appBar: AppBar(
        title: Text(isKorean ? '콘텐츠 추가' : 'Add Content'),
        actions: [
          if (_isLoading || _isUploading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
          // 사진/영상의 경우 업로드 완료 후에만 저장 버튼 표시
          if ((widget.type == VitaminSlotType.photo &&
                  _uploadedImageData != null) ||
              (widget.type == VitaminSlotType.video &&
                  _uploadedVideoData != null) ||
              (widget.type != VitaminSlotType.photo &&
                  widget.type != VitaminSlotType.video))
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveContent,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: isKorean ? '제목' : 'Title',
                border: const OutlineInputBorder(),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            // 메모 입력 필드 (항상 표시)
            TextField(
              controller: _memoController,
              decoration: InputDecoration(
                labelText: isKorean ? '메모 (선택사항)' : 'Memo (Optional)',
                hintText: isKorean
                    ? '이 콘텐츠에 대한 간단한 메모를 작성해주세요...'
                    : 'Write a brief memo about this content...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.note),
              ),
              maxLines: 5,
              enabled: !_isLoading,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 16),
            _buildTypeSpecificFields(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSpecificFields() {
    final languageCode = Localizations.localeOf(context).languageCode;
    final isKorean = languageCode == 'ko';

    switch (widget.type) {
      case VitaminSlotType.photo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 사진 선택 버튼
            if (_uploadedImageData == null)
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickAndUploadMedia,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image),
                label: Text(
                  _isUploading
                      ? (isKorean ? '업로드 중...' : 'Uploading...')
                      : (isKorean
                          ? '갤러리에서 사진 선택'
                          : 'Select Photo from Gallery'),
                ),
              )
            else
              // 업로드된 사진 미리보기 및 메모 입력
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _uploadedImageData!['imageUrl'] ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.image, size: 64),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 다시 선택 버튼
                  OutlinedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _uploadedImageData = null;
                              _memoController.clear();
                            });
                          },
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      isKorean ? '다시 선택' : 'Select Again',
                    ),
                  ),
                ],
              ),
          ],
        );

      case VitaminSlotType.video:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 영상 선택 버튼
            if (_uploadedVideoData == null)
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickAndUploadMedia,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.videocam),
                label: Text(
                  _isUploading
                      ? (isKorean ? '업로드 중...' : 'Uploading...')
                      : (isKorean
                          ? '갤러리에서 영상 선택'
                          : 'Select Video from Gallery'),
                ),
              )
            else
              // 업로드된 영상 미리보기 및 메모 입력
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      color: Colors.grey.shade200,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 썸네일이 있으면 표시
                        if (_uploadedVideoData!['thumbnailUrl'] != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _uploadedVideoData!['thumbnailUrl'] ?? '',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(Icons.videocam, size: 64),
                                );
                              },
                            ),
                          )
                        else
                          const Icon(Icons.videocam, size: 64),
                        // 재생 아이콘
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 다시 선택 버튼
                  OutlinedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _uploadedVideoData = null;
                              _memoController.clear();
                            });
                          },
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      isKorean ? '다시 선택' : 'Select Again',
                    ),
                  ),
                ],
              ),
          ],
        );

      case VitaminSlotType.music:
      case VitaminSlotType.videoUrl:
        return TextField(
          controller: _urlController,
          decoration: InputDecoration(
            labelText: isKorean ? 'URL' : 'URL',
            hintText: isKorean
                ? 'https://youtube.com/...'
                : 'https://youtube.com/...',
            border: const OutlineInputBorder(),
          ),
          enabled: !_isLoading,
          keyboardType: TextInputType.url,
        );

      case VitaminSlotType.quote:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: isKorean ? '명언/메시지' : 'Quote/Message',
                border: const OutlineInputBorder(),
              ),
              maxLines: 5,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _authorController,
              decoration: InputDecoration(
                labelText: isKorean ? '출처 (선택사항)' : 'Author (Optional)',
                border: const OutlineInputBorder(),
              ),
              enabled: !_isLoading,
            ),
          ],
        );

      case VitaminSlotType.empty:
        return const SizedBox.shrink();
    }
  }
}

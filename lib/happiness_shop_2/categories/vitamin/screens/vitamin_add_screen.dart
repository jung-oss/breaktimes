// lib/happiness_shop_2/categories/vitamin/screens/vitamin_add_screen.dart
import 'package:flutter/material.dart';
import '../models/vitamin_slot.dart';
import '../models/vitamin_content.dart';
import '../services/vitamin_service.dart';
import '../../../common/theme/shop_tokens.dart';
import '../../../common/widgets/shop_widgets.dart';

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
        showShopToast(
          context,
          isKorean
              ? '잠시 문제가 생겼어요. 다시 시도해 주세요.'
              : 'Something went wrong. Please try again.',
        );
      }
    }
  }

  /// 최종 저장
  Future<void> _saveContent() async {
    final languageCode = Localizations.localeOf(context).languageCode;
    final isKorean = languageCode == 'ko';

    if (_titleController.text.isEmpty) {
      showShopToast(
        context,
        isKorean ? '제목을 입력해 주세요' : 'Please enter a title',
      );
      return;
    }

    // 사진/영상의 경우 업로드가 완료되어야 함
    if ((widget.type == VitaminSlotType.photo && _uploadedImageData == null) ||
        (widget.type == VitaminSlotType.video && _uploadedVideoData == null)) {
      showShopToast(
        context,
        isKorean
            ? '사진 또는 영상을 먼저 선택해 주세요'
            : 'Please select a photo or video first',
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
            showShopToast(
              context,
              isKorean ? '링크(URL)를 입력해 주세요' : 'Please enter a URL',
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
            showShopToast(
              context,
              isKorean ? '명언을 입력해 주세요' : 'Please enter a quote',
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
        showShopToast(
          context,
          isKorean ? '콘텐츠를 담았어요' : 'Content added',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        showShopToast(
          context,
          isKorean
              ? '잠시 문제가 생겼어요. 다시 시도해 주세요.'
              : 'Something went wrong. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final isKorean = languageCode == 'ko';
    final t = ShopTokens.of(context);

    return Scaffold(
      backgroundColor: t.ground,
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
              tooltip: isKorean ? '저장' : 'Save',
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
              decoration: _inputDecoration(
                context,
                labelText: isKorean ? '제목' : 'Title',
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            // 메모 입력 필드 (항상 표시)
            TextField(
              controller: _memoController,
              decoration: _inputDecoration(
                context,
                labelText: isKorean ? '메모 (선택사항)' : 'Memo (Optional)',
                hintText: isKorean
                    ? '이 콘텐츠에 대한 간단한 메모를 작성해주세요...'
                    : 'Write a brief memo about this content...',
                prefixIcon: const Icon(Icons.sticky_note_2_outlined),
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

  /// 입력칸 모양: 모서리 14, 고르면 coralDeep 테두리
  InputDecoration _inputDecoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
  }) {
    final t = ShopTokens.of(context);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShopShape.button),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: t.surface,
      labelStyle: TextStyle(fontSize: 16, color: t.ink2),
      floatingLabelStyle: TextStyle(color: t.coralDeep),
      hintStyle: TextStyle(fontSize: 15, color: t.ink2),
      prefixIconColor: t.ink2,
      border: border(t.line),
      enabledBorder: border(t.line),
      disabledBorder: border(t.line),
      focusedBorder: border(t.coralDeep, 1.5),
    );
  }

  /// 사진·영상 고르기 버튼(사랑하기를 쓰지 않습니다)
  Widget _buildPickButton({required IconData icon, required String label}) {
    final t = ShopTokens.of(context);
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isUploading ? null : _pickAndUploadMedia,
        icon: _isUploading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: t.ink2,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: t.coral,
          foregroundColor: t.onCoral,
          disabledBackgroundColor: t.line,
          disabledForegroundColor: t.ink2,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShopShape.button),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildTypeSpecificFields() {
    final languageCode = Localizations.localeOf(context).languageCode;
    final isKorean = languageCode == 'ko';
    final t = ShopTokens.of(context);

    switch (widget.type) {
      case VitaminSlotType.photo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 사진 선택 버튼
            if (_uploadedImageData == null)
              _buildPickButton(
                icon: Icons.image,
                label: (_isUploading
                    ? (isKorean ? '업로드 중...' : 'Uploading...')
                    : (isKorean ? '갤러리에서 사진 선택' : 'Select Photo from Gallery')),
              )
            else
              // 업로드된 사진 미리보기 및 메모 입력
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: t.line,
                      borderRadius: BorderRadius.circular(ShopShape.card),
                      border: Border.all(color: t.line),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(ShopShape.card),
                      child: Image.network(
                        _uploadedImageData!['imageUrl'] ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(Icons.image, size: 64, color: t.ink2),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 다시 선택 버튼
                  ShopOutlineButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _uploadedImageData = null;
                              _memoController.clear();
                            });
                          },
                    icon: Icons.refresh,
                    label: isKorean ? '다시 선택' : 'Select Again',
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
              _buildPickButton(
                icon: Icons.videocam,
                label: (_isUploading
                    ? (isKorean ? '업로드 중...' : 'Uploading...')
                    : (isKorean ? '갤러리에서 영상 선택' : 'Select Video from Gallery')),
              )
            else
              // 업로드된 영상 미리보기 및 메모 입력
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ShopShape.card),
                      border: Border.all(color: t.line),
                      color: t.line,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 썸네일이 있으면 표시
                        if (_uploadedVideoData!['thumbnailUrl'] != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(ShopShape.card),
                            child: Image.network(
                              _uploadedVideoData!['thumbnailUrl'] ?? '',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(Icons.videocam,
                                      size: 64, color: t.ink2),
                                );
                              },
                            ),
                          )
                        else
                          Icon(Icons.videocam, size: 64, color: t.ink2),
                        // 재생 아이콘(영상 위 표시라 어두운 막을 둡니다)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(153),
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
                  const SizedBox(height: 12),
                  // 다시 선택 버튼
                  ShopOutlineButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _uploadedVideoData = null;
                              _memoController.clear();
                            });
                          },
                    icon: Icons.refresh,
                    label: isKorean ? '다시 선택' : 'Select Again',
                  ),
                ],
              ),
          ],
        );

      case VitaminSlotType.music:
      case VitaminSlotType.videoUrl:
        return TextField(
          controller: _urlController,
          decoration: _inputDecoration(
            context,
            labelText: isKorean ? 'URL' : 'URL',
            hintText: isKorean
                ? 'https://youtube.com/...'
                : 'https://youtube.com/...',
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
              decoration: _inputDecoration(
                context,
                labelText: isKorean ? '명언/메시지' : 'Quote/Message',
              ),
              maxLines: 5,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _authorController,
              decoration: _inputDecoration(
                context,
                labelText: isKorean ? '출처 (선택사항)' : 'Author (Optional)',
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

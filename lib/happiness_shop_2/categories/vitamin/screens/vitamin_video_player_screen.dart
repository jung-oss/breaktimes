// lib/happiness_shop_2/categories/vitamin/screens/vitamin_video_player_screen.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 비타민 슬롯 영상 재생 화면
///
/// 영상 위에서 쓰므로 바탕은 테마와 상관없이 검은색입니다.
class VitaminVideoPlayerScreen extends StatefulWidget {
  const VitaminVideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.isKorean,
  });

  final String videoUrl;
  final String title;
  final bool isKorean;

  static Route<void> route({
    required String videoUrl,
    required String title,
    required bool isKorean,
  }) =>
      MaterialPageRoute(
        builder: (_) => VitaminVideoPlayerScreen(
          videoUrl: videoUrl,
          title: title,
          isKorean: isKorean,
        ),
      );

  @override
  State<VitaminVideoPlayerScreen> createState() =>
      _VitaminVideoPlayerScreenState();
}

class _VitaminVideoPlayerScreenState extends State<VitaminVideoPlayerScreen> {
  late final VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller.addListener(_onUpdate);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _controller.play();
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  void _onUpdate() {
    if (!mounted) return;
    if (_controller.value.hasError && !_failed) {
      setState(() => _failed = true);
      return;
    }
    // 재생/멈춤 상태와 진행 막대를 다시 그립니다
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final value = _controller.value;
    if (!value.isInitialized) return;
    if (value.isPlaying) {
      _controller.pause();
    } else {
      // 끝까지 봤으면 처음부터 다시 재생합니다
      if (value.position >= value.duration) {
        _controller.seekTo(Duration.zero);
      }
      _controller.play();
    }
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0
        ? '${d.inHours}:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.value;
    final isKorean = widget.isKorean;

    Widget body;
    if (_failed) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined,
                color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            Text(
              isKorean
                  ? '영상을 불러오지 못했어요.\n연결을 확인하고 다시 열어 주세요.'
                  : 'Could not load the video.\nCheck your connection and try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, height: 1.5),
            ),
          ],
        ),
      );
    } else if (!value.isInitialized) {
      body = const CircularProgressIndicator(color: Colors.white);
    } else {
      body = GestureDetector(
        onTap: _togglePlay,
        child: AspectRatio(
          aspectRatio: value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller),
              if (!value.isPlaying)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(153),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow,
                      color: Colors.white, size: 48),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: Center(child: body)),
            if (value.isInitialized && !_failed)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 16, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _togglePlay,
                      tooltip: value.isPlaying
                          ? (isKorean ? '멈춤' : 'Pause')
                          : (isKorean ? '재생' : 'Play'),
                      icon: Icon(
                        value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Color(0xFFFFB59E),
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white12,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_format(value.position)} / ${_format(value.duration)}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

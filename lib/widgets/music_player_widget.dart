//music_player_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';

class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({Key? key}) : super(key: key);

  @override
  AudioPlayerScreenState createState() => AudioPlayerScreenState();
}

class AudioPlayerScreenState extends State<AudioPlayerScreen> {
  // MusicProvider에 접근하기 위한 변수
  late MusicProvider _musicProvider;

  // 현재 상태를 나타내는 변수들
  bool get isPlaying => _musicProvider.isPlaying;
  bool get isLoading => _musicProvider.isLoading;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MusicProvider 인스턴스 가져오기
    _musicProvider = Provider.of<MusicProvider>(context, listen: false);
  }

  // 재생/일시정지 토글 메서드
  Future<void> togglePlay() async {
    await _musicProvider.togglePlay();
    // setState는 호출할 필요 없음 - MusicProvider가 이미 notifyListeners()를 호출함
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('음악 플레이어'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                    musicProvider.isLooping ? Icons.repeat_one : Icons.repeat),
                onPressed: musicProvider.toggleLoopMode,
                tooltip: musicProvider.isLooping ? '무한 재생 켜짐' : '무한 재생 꺼짐',
              ),
            ],
          ),
          body: musicProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // 현재 재생 중인 트랙 정보 표시
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (musicProvider.currentTrack != null) ...[
                              Text(
                                '현재 트랙: ${musicProvider.currentTrack?.title}',
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 30),

                              // 재생 컨트롤
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // 이전 트랙 버튼
                                  IconButton(
                                    icon: const Icon(Icons.skip_previous,
                                        size: 40),
                                    onPressed: musicProvider.playPreviousTrack,
                                  ),

                                  // 재생/일시정지 버튼
                                  IconButton(
                                    icon: Icon(
                                      musicProvider.isPlaying
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_filled,
                                      size: 64,
                                    ),
                                    onPressed: musicProvider.togglePlay,
                                  ),

                                  // 다음 트랙 버튼
                                  IconButton(
                                    icon: const Icon(Icons.skip_next, size: 40),
                                    onPressed: musicProvider.playNextTrack,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // 재생 상태 표시
                              Text(
                                musicProvider.isPlaying ? '재생 중...' : '일시 정지됨',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: musicProvider.isPlaying
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),

                              if (musicProvider.isLooping)
                                const Text(
                                  '무한 재생 모드',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ] else
                              const Text('재생 가능한 트랙이 없습니다.'),
                          ],
                        ),
                      ),
                    ),

                    // 트랙 목록
                    if (musicProvider.tracks.isNotEmpty)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                '트랙 목록',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: musicProvider.tracks.length,
                                itemBuilder: (context, index) {
                                  final track = musicProvider.tracks[index];
                                  final isCurrentTrack =
                                      index == musicProvider.currentTrackIndex;

                                  return ListTile(
                                    leading: isCurrentTrack &&
                                            musicProvider.isPlaying
                                        ? const Icon(Icons.music_note,
                                            color: Colors.green)
                                        : const Icon(Icons.music_note_outlined),
                                    title: Text(
                                      track.title,
                                      style: TextStyle(
                                        fontWeight: isCurrentTrack
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color:
                                            isCurrentTrack ? Colors.blue : null,
                                      ),
                                    ),
                                    onTap: () => musicProvider.playTrack(index),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

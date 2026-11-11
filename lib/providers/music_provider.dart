import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:developer' as developer;

class MusicTrack {
  final String id;
  final String title;
  final String url;
  final bool isAsset; // 애셋인지 여부 추가

  MusicTrack({
    required this.id,
    required this.title,
    required this.url,
    this.isAsset = false, // 기본값은 false (Firebase URL)
  });
}

class MusicProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool isPlaying = false;
  bool isLoading = false;
  bool isLooping = false;
  int currentTrackIndex = 0;

  List<MusicTrack> _tracks = [];
  List<MusicTrack> get tracks => _tracks;

  MusicTrack? get currentTrack =>
      _tracks.isNotEmpty && currentTrackIndex < _tracks.length
          ? _tracks[currentTrackIndex]
          : null;

  MusicProvider() {
    _init();
  }

  Future<void> _init() async {
    // 먼저 로컬 에셋으로 시작
    await _loadLocalAssetMusic();
    // 그 다음에 Firebase 음악 로드 - 있으면 리스트에 추가
    await _loadTracksFromFirebase();
    _setupAudioPlayer();

    // 기본적으로 첫 트랙(로컬 에셋) 자동 재생 시작
    //if (_tracks.isNotEmpty) {
    //  _playCurrentTrack();
    //}
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerComplete.listen((event) {
      if (isLooping) {
        // 무한 재생 모드 - 현재 트랙 다시 재생
        _playCurrentTrack();
      } else {
        // 일반 모드 - 다음 트랙 재생
        playNextTrack();
      }
    });
  }

  // Firebase Storage에서 음악 목록 가져오기
  Future<void> _loadTracksFromFirebase() async {
    isLoading = true;
    notifyListeners();

    try {
      // _loadTracksFromFirebase() 메소드 내부에 추가
// Firebase Storage의 'music' 폴더 참조 가져오기
      final storageRef = _storage.ref().child('music');
      developer.log('Storage 참조 경로: ${storageRef.fullPath}');

// 폴더 내 모든 항목 가져오기
      final ListResult result = await storageRef.listAll();
      developer.log('Storage 결과 항목 수: ${result.items.length}');
      developer.log('Storage 결과 폴더 수: ${result.prefixes.length}');

      // 임시 트랙 목록
      List<MusicTrack> loadedTracks = [];

      // 각 파일에 대해 처리
      for (var item in result.items) {
        // 다운로드 URL 가져오기
        final String downloadUrl = await item.getDownloadURL();

        // 파일 이름에서 확장자 제거
        final String fileName = item.name;
        final String title = fileName.split('.').first;

        // 트랙 객체 생성 및 목록에 추가
        loadedTracks.add(MusicTrack(
          id: item.name,
          title: title.replaceAll('_', ' '),
          url: downloadUrl,
          isAsset: false,
        ));
      }

      // 로드된 트랙이 있으면 로컬 트랙을 유지하면서 Firebase 트랙 추가
      if (loadedTracks.isNotEmpty) {
        // 기존 로컬 트랙 유지하면서 Firebase 트랙 추가
        _tracks.addAll(loadedTracks);
        // 로컬 트랙이 있으면 무한 재생 모드 비활성화 (다른 트랙도 재생 가능하므로)
        if (_tracks.length > 1) {
          isLooping = false;
        }
        developer.log('Firebase에서 음악 트랙 ${loadedTracks.length}개 로드됨');
      } else {
        developer.log('Firebase에서 음악 트랙을 찾을 수 없습니다.');
        // 로컬 트랙만 사용하는 경우, 무한 재생 모드 유지
      }
    } catch (e) {
      developer.log('Firebase에서 음악 로드 중 오류: $e');
      // 오류 발생 시 로컬 트랙만 사용하는 경우, 무한 재생 모드 유지
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 로컬 에셋에서 음악 로드 (항상 먼저 호출)
  Future<void> _loadLocalAssetMusic() async {
    isLoading = true;
    notifyListeners();

    try {
      // 로컬 에셋 경로 - assets/ 접두사 제외
      const String assetPath1 = 'music/Breaktime_sound_01.mp3';
      const String assetPath2 = 'music/Breaktime_sound_02.mp3';
      const String assetPath3 = 'music/Breaktime_sound_03.mp3';

      // 기존 트랙 목록 비우기
      _tracks = [];

      // 로컬 에셋 트랙 추가
      _tracks.add(MusicTrack(
        id: 'local_asset_1',
        title: 'music/Breaktime_sound_01.mp3',
        url: assetPath1,
        isAsset: true, // 애셋 플래그 설정
      ));

      _tracks.add(MusicTrack(
        id: 'local_asset_2',
        title: 'music/Breaktime_sound_02.mp3',
        url: assetPath2,
        isAsset: true, // 애셋 플래그 설정
      ));

      _tracks.add(MusicTrack(
        id: 'local_asset_3',
        title: 'Breaktime_sound_03',
        url: assetPath3,
        isAsset: true, // 애셋 플래그 설정
      ));

      // 기본적으로 무한 재생 모드 활성화
      isLooping = true;

      developer.log('로컬 에셋 음악 로드: $assetPath1, $assetPath2, $assetPath3');
    } catch (e) {
      developer.log('로컬 에셋 음악 로드 중 오류: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 음악 재생/일시정지 토글
  Future<void> togglePlay() async {
    if (_tracks.isEmpty) {
      developer.log('재생할 트랙이 없습니다.');
      return;
    }

    try {
      if (isPlaying) {
        //일시정지 전에 상태 변경
        isPlaying = false;
        notifyListeners();

        await _audioPlayer.pause();
      } else {
        // 재생 시도 전에 상태 변경하지 않고
        // 성공적으로 재생된 후에만 상태 변경
        final result = await _playCurrentTrack();

        // 재생이 성공한 경우에만 상태 변경
        if (result) {
          isPlaying = true;
          notifyListeners();
        }
      }
    } catch (e) {
      developer.log('음악 재생 토글 중 오류: $e');
    }
  }

  // 현재 트랙 재생
  Future<bool> _playCurrentTrack() async {
    if (_tracks.isEmpty) return false;

    try {
      final track = _tracks[currentTrackIndex];

      // 애셋인지 URL인지에 따라 다른 방식으로 재생
      if (track.isAsset) {
        // 애셋 파일 재생
        await _audioPlayer.play(AssetSource(track.url));
      } else {
        // URL 재생 (Firebase에서 가져온 경우)
        await _audioPlayer.play(UrlSource(track.url));
      }

      isPlaying = true;
      notifyListeners();
      return true;
    } catch (e) {
      developer.log('트랙 재생 중 오류: $e');
      isPlaying = false;
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 다음 트랙 재생
  Future<void> playNextTrack() async {
    if (_tracks.isEmpty) return;

    currentTrackIndex = (currentTrackIndex + 1) % _tracks.length;
    await _playCurrentTrack();
    notifyListeners();
  }

  // 이전 트랙 재생
  Future<void> playPreviousTrack() async {
    if (_tracks.isEmpty) return;

    currentTrackIndex =
        (currentTrackIndex - 1 + _tracks.length) % _tracks.length;
    await _playCurrentTrack();
    notifyListeners();
  }

  // 무한 재생 모드 토글
  void toggleLoopMode() {
    isLooping = !isLooping;
    notifyListeners();
  }

  // 특정 트랙으로 이동하여 재생
  Future<void> playTrack(int index) async {
    if (index >= 0 && index < _tracks.length) {
      currentTrackIndex = index;
      await _playCurrentTrack();
    }
  }

  // 볼륨 설정
  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume);
  }

  // 리소스 해제
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

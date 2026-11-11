// lib/utils/notification_content_manager.dart
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// 알림을 위한 휴식 메시지를 관리하는 클래스
class NotificationContentManager {
  // 한국어 휴식 메시지 목록
  static final List<String> koreanMessages = [
    '휴식, 당신이 아무것도 하지 않은 시간이 언제였는지 기억할 시간입니다.',
    '쉼은 시계바늘이 흐르는 소리만 들리고, 창밖으로 스쳐가는 구름의 모양을 바라보던 순간을 찾아줍니다.',
    '당신의 영혼이 몸을 따라잡을 시간. 당신은 휴식이 필요합니다.',
    '가장 단단한 결심은 휴식 후에 찾아옵니다.',
    '쉬는 동안, 세상은 당신을 위해 준비합니다.',
    '고양이처럼 게으르게, 바람처럼 자유롭게 - 당신만의 쉼표를 찍을 시간입니다.',
    '때로는 아무것도 하지 않는 것이 모든 것을 하는 것보다 더 어렵습니다.',
    '두 손을 모아 깊게 숨을 들이마신 후, 천천히 내쉬면서 손을 가슴에 얹고 휴식을 가져보세요.',
    '휴식은 당신의 삶을 더욱 풍요롭게 만들어줍니다.',
    '지금 이 순간, 당신이 있는 곳을 알 수 있는 방법은 휴식입니다.',
    '쉼, 지금, 여기, 이순간에 온전히 머물러 보세요.',
    '커피 한 잔과 쉼과 기록. 그 글을 통해 마음에 간직해보세요.',
    '쉬는 동안 당신의 목소리를 작게 내보세요.',
    '그 진동이 당신의 몸을 통해 퍼지는 것을 느껴보세요.',
    '오늘 하루, 당신이 흘린 모든 땀방울을 떠올려보세요. 그 노력이 당신을 한 걸음 더 성장시켰고 지금은 휴식이 필요합니다.',
    '창밖의 바람을 느껴보세요. 그 바람이 어디에서 오고 어디로 가는지 상상해보세요. 휴식은 그렇게 여유를 줍니다.',

    // 새로 추가된 한국어 휴식 메시지
    '오늘은 잠시 멈추고 당신의 호흡에 집중할 시간입니다. 깊은 숨을 들이마시고 내쉬며 그 감각을 느껴보세요.',
    '창밖으로 스쳐가는 구름의 모양을 바라보는 여유를 가져보세요. 그 순간의 느낌을 마음에 담아보세요.',
    '당신의 영혼이 몸을 따라잡을 시간입니다. 오늘의 감정을 하나씩 알아차려보세요.',
    '고요함 속에서 들리는 작은 소리들에 귀 기울여보세요. 세상은 늘 당신에게 말을 걸고 있습니다.',
    '당신이 쉬는 동안, 세상은 당신을 위해 준비합니다. 오늘 발견한 작은 행복을 기억해보세요.',
    '두 손을 모아 깊게 숨을 들이마신 후, 천천히 내쉬세요. 지금 이 순간에 집중해보세요.',
    '오늘의 햇살이 창문을 통해 들어오는 모습을 바라보세요. 그 따스함을 느껴보세요.',
    '지금 이 순간, 당신이 있는 공간의 작은 소리들을 들어보세요. 그 소리들이 전하는 메시지를 느껴보세요.',
    '커피 한 잔의 향기를 천천히 음미하며, 그 향이 불러일으키는 기억을 떠올려보세요.',
    '당신의 손가락으로 반대편 손바닥을 천천히 문질러보세요. 그 감각이 전하는 현재의 순간을 느껴보세요.',
    '창밖의 하늘 색깔을 관찰하고, 그 색이 당신에게 주는 느낌을 알아차려보세요.',
    '오늘 당신의 발걸음이 만든 리듬을 기억해보세요. 그 리듬이 말해주는 하루의 이야기를 들어보세요.',
    '햇살이 피부에 닿는 감각을 느껴보세요. 그 따스함이 전해주는 위로를 받아들여보세요.',
    '바람이 머리카락을 스치는 감각을 느껴보세요. 그 자유로움을 온전히 경험해보세요.',
    '물 한 잔을 천천히 마시며 그 시원함이 목을 타고 내려가는 감각을 느껴보세요.',
    '오늘 하루를 색으로 표현한다면 어떤 색일까요? 그 색이 지닌 의미를 생각해보세요.',
    '창문을 열고 들어오는 바람을 느껴보세요. 그 바람이 전하는 계절의 메시지를 듣고 있나요?',
    '당신의 심장 박동에 귀를 기울여보세요. 그 리듬이 말해주는 삶의 이야기를 들어보세요.',
    '손바닥을 펼쳐 그 선들을 따라가보세요. 당신의 인생 선이 이야기하는 순간들을 떠올려보세요.',
    '오늘 하루를 마무리하며, 가장 인상 깊었던 순간을 되새겨보세요.',
    '눈을 감고 깊은 숨을 세 번 들이마셨다 내쉬고, 마음에 떠오르는 첫 번째 생각을 알아차려보세요.',
    '당신이 좋아하는 음악 한 곡을 생각하며, 그 멜로디가 불러일으키는 감정을 느껴보세요.',
    '오늘의 하늘이 당신에게 속삭이는 메시지가 있다면, 그것을 들어보세요.',
    '두 눈을 감고 가장 먼저 떠오르는 풍경을 상상해보세요. 그 풍경이 담고 있는 이야기를 느껴보세요.',
    '당신의 호흡이 만드는 파도 소리에 귀 기울이세요. 그 파도가 데려다 주는 평화를 경험해보세요.',
  ];

  // 영어 휴식 메시지 목록 (한국어 메시지의 번역)
  static final List<String> englishMessages = [
    'Rest - it\'s time to remember when you last took a moment to do nothing.',
    'Stillness brings moments where you can hear the ticking of the clock and observe the clouds drifting by.',
    'Time for your soul to catch up with your body. You need rest.',
    'The strongest resolutions come after moments of rest.',
    'While you rest, the world prepares for you.',
    'Lazy like a cat, free like the wind - time to create your own pause.',
    'Sometimes doing nothing is harder than doing everything.',
    'Fold your hands, take a deep breath, then exhale slowly with your hands on your chest. Find your rest.',
    'Rest enriches your life.',
    'In this moment, rest is how you can know where you are.',
    'Rest - be fully present in this moment, here and now.',
    'A cup of coffee, rest, and reflection. Cherish these thoughts.',
    'During your rest, speak softly to yourself.',
    'Feel those vibrations resonating through your body.',
    'Today, recall all the effort you\'ve made. That effort has helped you grow, and now you need rest.',
    'Feel the breeze outside. Imagine where it comes from and where it goes. Rest gives you that space.',

    // 새로 추가된 영어 휴식 메시지 (한국어 메시지 번역)
    'Today, take a moment to pause and focus on your breath. Feel the sensation as you inhale deeply and exhale.',
    'Take time to watch the clouds drift by outside your window. Embrace the feeling of that moment.',
    'It\'s time for your soul to catch up with your body. Notice each emotion you feel today.',
    'Listen to the small sounds in the silence. The world is always speaking to you.',
    'While you rest, the world prepares for you. Remember the small joys you discovered today.',
    'Bring your hands together, take a deep breath, and slowly exhale. Focus on this present moment.',
    'Observe the sunlight coming through your window. Feel its warmth.',
    'In this moment, listen to the subtle sounds in your space. Feel the messages they convey.',
    'Slowly savor the aroma of a cup of coffee, recalling the memories its fragrance evokes.',
    'Gently rub the palm of your opposite hand with your fingers. Experience the sensation of the present moment.',
    'Observe the color of the sky outside, and notice how it makes you feel.',
    'Remember the rhythm of your footsteps today. Listen to the story of your day told through that rhythm.',
    'Feel the sensation of sunlight touching your skin. Accept the comfort it brings.',
    'Notice the feeling of wind brushing through your hair. Fully experience that freedom.',
    'Drink a glass of water slowly, feeling its coolness as it travels down your throat.',
    'If today were a color, what would it be? Consider the meaning behind that color.',
    'Feel the breeze coming through an open window. Can you hear the message of the season it carries?',
    'Listen to your heartbeat. Hear the story of life it tells.',
    'Open your palm and trace its lines. Recall the moments your life line speaks of.',
    'As you end your day, reflect on your most memorable moment.',
    'Close your eyes, take three deep breaths, and notice the first thought that comes to mind.',
    'Think of a song you love and feel the emotions its melody evokes.',
    'If today\'s sky were whispering a message to you, listen to what it might be saying.',
    'Close your eyes and imagine the first landscape that comes to mind. Feel the story it holds.',
    'Listen to the wave-like sound of your breathing. Experience the peace these waves bring.',
  ];

  /// 로케일에 따라 랜덤 메시지 반환
  static String getRandomMessage(String locale) {
    final random = Random();
    if (locale.startsWith('ko')) {
      return koreanMessages[random.nextInt(koreanMessages.length)];
    } else {
      return englishMessages[random.nextInt(englishMessages.length)];
    }
  }

  /// 인덱스로 메시지 가져오기 (언어 간 일관성 유지)
  static String getMessageByIndex(String locale, int index) {
    // 인덱스가 범위를 벗어나지 않도록 조정
    final validIndex = index % koreanMessages.length;
    if (locale.startsWith('ko')) {
      return koreanMessages[validIndex];
    } else {
      return englishMessages[validIndex];
    }
  }

  /// 다음 메시지 인덱스 저장
  static Future<void> storeNextMessageIndex(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('next_notification_message_index', index);
    } catch (e) {
      print('다음 메시지 인덱스 저장 오류: $e');
    }
  }

  /// 다음 메시지 인덱스 가져오기
  static Future<int> getNextMessageIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt('next_notification_message_index') ?? 0;

      // 다음 인덱스로 증가시키고 저장
      final nextIndex = (index + 1) % koreanMessages.length;
      await storeNextMessageIndex(nextIndex);

      return index;
    } catch (e) {
      print('다음 메시지 인덱스 가져오기 오류: $e');
      return 0;
    }
  }
}

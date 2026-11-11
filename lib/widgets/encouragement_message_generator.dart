// lib/widgets/encouragement_message_generator.dart
import 'dart:math';
import 'package:flutter/material.dart';

/// 완료율에 따른 격려 메시지를 생성하는 유틸리티 클래스
class EncouragementMessageGenerator {
  static final Random _random = Random();

  /// 완료율에 따른 격려 메시지 생성
  /// [completion] - 완료율 (0-100)
  /// [isKorean] - true: 한국어, false: 영어
  static String generateMessage(double completion, bool isKorean) {
    if (isKorean) {
      return _getKoreanMessage(completion);
    } else {
      return _getEnglishMessage(completion);
    }
  }

  /// 한국어 격려 메시지 생성
  static String _getKoreanMessage(double completion) {
    final List<String> messages;

    if (completion == 0) {
      messages = _koreanZeroMessages;
    } else if (completion < 30) {
      messages = _koreanLowMessages;
    } else if (completion < 70) {
      messages = _koreanMidMessages;
    } else if (completion < 100) {
      messages = _koreanHighMessages;
    } else {
      messages = _koreanCompleteMessages;
    }

    // 명언도 함께 표시할 확률 (50%)
    final shouldAddQuote = _random.nextBool();
    final String message = messages[_random.nextInt(messages.length)];

    if (shouldAddQuote) {
      final quote = _koreanQuotes[_random.nextInt(_koreanQuotes.length)];
      // 명언은 문구 앞에 추가
      return '"$quote"\n\n$message';
    }

    return message;
  }

  /// 영어 격려 메시지 생성
  static String _getEnglishMessage(double completion) {
    final List<String> messages;

    if (completion == 0) {
      messages = _englishZeroMessages;
    } else if (completion < 30) {
      messages = _englishLowMessages;
    } else if (completion < 70) {
      messages = _englishMidMessages;
    } else if (completion < 100) {
      messages = _englishHighMessages;
    } else {
      messages = _englishCompleteMessages;
    }

    // 명언도 함께 표시할 확률 (50%)
    final shouldAddQuote = _random.nextBool();
    final String message = messages[_random.nextInt(messages.length)];

    if (shouldAddQuote) {
      final quote = _englishQuotes[_random.nextInt(_englishQuotes.length)];
      // 명언은 문구 앞에 추가
      return '"$quote"\n\n$message';
    }

    return message;
  }

  // 한국어 메시지 모음 (각 10개)
  static const List<String> _koreanZeroMessages = [
    "오늘의 미션이 기다리고 있어요! 첫 발걸음을 내딛어 보는 건 어떨까요? 완전 럭키비키짱~! 💖",
    "아직 시작하지 않았어도 괜찮아요! 지금부터 시작해봐요. 여러분은 할 수 있어요! 완전 럭키비키짱~! 💖",
    "새로운 하루, 새로운 시작이에요! 작은 것부터 차근차근 시작해볼까요? 완전 럭키비키짱~! 💖",
    "아직 미션을 시작하지 않았군요! 천천히 시작해도 괜찮아요. 오늘 하루도 파이팅! 완전 럭키비키짱~! 💖",
    "준비는 됐나요? 오늘의 미션이 당신을 기다리고 있어요! 지금 시작해볼까요? 완전 럭키비키짱~! 💖",
    "도전은 첫 걸음부터 시작돼요! 오늘의 미션에 도전해보세요. 당신은 할 수 있어요! 완전 럭키비키짱~! 💖",
    "미션을 시작하는 첫 순간이 가장 중요해요! 지금 당장 시작해보세요. 완전 럭키비키짱~! 💖",
    "하루의 시작, 소중한 순간이에요! 오늘도 행복한 하루를 만들어봐요. 완전 럭키비키짱~! 💖",
    "첫 미션을 시작할 준비가 되었나요? 당신의 첫 걸음을 응원할게요! 완전 럭키비키짱~! 💖",
    "시작이 없으면 성공도 없어요! 지금 바로 시작해 보는 건 어떨까요? 완전 럭키비키짱~! 💖"
  ];

  static const List<String> _koreanLowMessages = [
    "조금씩 나아가고 있어요! 작은 발걸음도 소중한 진전이에요. 포기하지 말고 계속해요! 완전 럭키비키짱~! 💖",
    "시작이 반이라고 했어요! 이미 미션을 시작했네요. 조금씩 더 나아가 보아요! 완전 럭키비키짱~! 💖",
    "작은 성취도 축하받을 가치가 있어요! 계속 나아가다 보면 어느새 큰 변화가 찾아올 거예요. 완전 럭키비키짱~! 💖",
    "한 걸음 한 걸음이 모여 큰 여정이 되어요! 지금처럼만 꾸준히 해보아요. 완전 럭키비키짱~! 💖",
    "노력하는 모습이 아름다워요! 오늘 하루도 화이팅입니다. 완전 럭키비키짱~! 💖",
    "시작한 당신이 정말 멋져요! 첫 미션을 완료한 것을 축하해요. 계속 도전해봐요! 완전 럭키비키짱~! 💖",
    "진행 중인 미션이 있다는 것, 그것만으로도 대단해요! 천천히 진행해도 괜찮아요. 완전 럭키비키짱~! 💖",
    "작은 진전도 성장이에요! 오늘의 작은 노력이 내일의 큰 변화를 만들어요. 완전 럭키비키짱~! 💖",
    "꾸준함은 가장 강력한 힘이에요! 조금씩 해나가다 보면 어느새 목표에 도달할 거예요. 완전 럭키비키짱~! 💖",
    "지금 이 순간의 노력이 미래의 당신을 만들어요! 조금씩 앞으로 나아가요. 완전 럭키비키짱~! 💖"
  ];

  static const List<String> _koreanMidMessages = [
    "절반 넘게 완료했어요! 정말 잘하고 있어요. 남은 미션도 화이팅! 완전 럭키비키짱~! 💖",
    "꾸준한 노력이 빛을 발하고 있어요! 이 페이스라면 목표 달성도 눈앞이네요. 완전 럭키비키짱~! 💖",
    "균형 잡힌 생활을 위한 노력이 보여요! 오늘 하루도 멋지게 보내고 있네요. 완전 럭키비키짱~! 💖",
    "중간 지점을 넘어섰어요! 이제 조금만 더 노력하면 목표를 달성할 수 있어요. 완전 럭키비키짱~! 💖",
    "꾸준함이 빛나는 순간이에요! 지금처럼 계속 행복한 하루 보내세요. 완전 럭키비키짱~! 💖",
    "벌써 절반 이상을 해냈어요! 당신의 의지력이 정말 대단해요. 남은 미션도 화이팅! 완전 럭키비키짱~! 💖",
    "꾸준한 진전을 보여주고 있어요! 물 흐르듯 자연스럽게 계속 해보세요. 완전 럭키비키짱~! 💖",
    "중간 고비를 잘 넘기고 있어요! 이 기세라면 곧 목표 달성이 가능할 거예요. 완전 럭키비키짱~! 💖",
    "좋은 페이스를 유지하고 있어요! 지치지 말고 계속 달려봐요. 완전 럭키비키짱~! 💖",
    "진행 상황이 너무 좋아요! 이 열정을 끝까지 유지해주세요. 완전 럭키비키짱~! 💖"
  ];

  static const List<String> _koreanHighMessages = [
    "거의 다 왔어요! 대단해요. 마지막까지 화이팅! 오늘의 나, 어제의 나보다 한 걸음 더 성장했어요. 완전 럭키비키짱~! 💖",
    "목표가 눈앞에 있어요! 포기하지 않고 여기까지 온 당신이 정말 자랑스러워요. 완전 럭키비키짱~! 💖",
    "와우! 거의 완료했어요. 당신의 의지력이 빛나는 순간이에요! 완전 럭키비키짱~! 💖",
    "끝이 보여요! 이제 조금만 더 힘내서 완벽하게 마무리해봐요. 완전 럭키비키짱~! 💖",
    "대단해요! 거의 모든 미션을 완료했네요. 오늘 하루도 승리를 향해 달려가고 있어요! 완전 럭키비키짱~! 💖",
    "곧 성공의 문을 열게 될 거예요! 마지막까지 최선을 다해보세요. 완전 럭키비키짱~! 💖",
    "결승선이 보여요! 지금까지 해온 노력이 곧 결실을 맺을 거예요. 완전 럭키비키짱~! 💖",
    "성취의 기쁨이 코앞에 있어요! 마지막 미션까지 화이팅! 완전 럭키비키짱~! 💖",
    "멋진 성과를 이루어가고 있어요! 마지막까지 집중력을 잃지 마세요. 완전 럭키비키짱~! 💖",
    "정말 훌륭해요! 이제 마지막 고비만 넘으면 완벽한 성공이에요. 완전 럭키비키짱~! 💖"
  ];

  static const List<String> _koreanCompleteMessages = [
    "모든 미션 완료! 오늘 하루도 성공적으로 마무리했어요. 당신은 정말 최고예요! 완전 럭키비키짱~! 💖",
    "100% 달성! 대단해요. 오늘의 성취가 내일의 자신감이 될 거예요. 완전 럭키비키짱~! 💖",
    "완벽한 하루! 모든 미션을 완료한 당신은 오늘의 챔피언이에요. 완전 럭키비키짱~! 💖",
    "축하해요! 모든 미션을 성공적으로 마쳤어요. 오늘의 성취를 자랑스러워하세요! 완전 럭키비키짱~! 💖",
    "와우! 100% 달성이에요. 당신의 열정과 끈기가 빛나는 순간입니다. 완전 럭키비키짱~! 💖",
    "미션 올 클리어! 당신의 노력이 완벽한 결실을 맺었어요. 축하합니다! 완전 럭키비키짱~! 💖",
    "모든 미션 성공! 오늘 하루를 완벽하게 마무리했어요. 자신에게 선물을 주세요! 완전 럭키비키짱~! 💖",
    "100% 완벽해요! 당신의 의지력과 실천력이 만든 멋진 결과예요. 완전 럭키비키짱~! 💖",
    "목표 달성 완료! 스스로를 정말 자랑스럽게 생각해도 좋아요. 완전 럭키비키짱~! 💖",
    "성공적인 하루! 모든 미션을 완료한 당신은 진정한 승리자예요. 완전 럭키비키짱~! 💖"
  ];

  // 영어 메시지 모음 (각 10개)
  static const List<String> _englishZeroMessages = [
    "Today's missions are waiting for you! How about taking the first step? Super lucky viki-chang~! 💖",
    "It's okay if you haven't started yet! Let's begin now. You can do it! Super lucky viki-chang~! 💖",
    "New day, new beginning! Shall we start with something small? Super lucky viki-chang~! 💖",
    "I see you haven't started your missions yet! It's okay to start slowly. Fighting for today! Super lucky viki-chang~! 💖",
    "Are you ready? Today's missions are waiting for you! Let's start now? Super lucky viki-chang~! 💖",
    "Challenges begin with the first step! Try today's missions. You can do it! Super lucky viki-chang~! 💖",
    "The first moment of starting a mission is the most important! Start right now. Super lucky viki-chang~! 💖",
    "The beginning of the day is a precious moment! Let's make today a happy day. Super lucky viki-chang~! 💖",
    "Ready to start your first mission? I'll cheer for your first step! Super lucky viki-chang~! 💖",
    "Without a start, there's no success! How about starting right now? Super lucky viki-chang~! 💖"
  ];

  static const List<String> _englishLowMessages = [
    "You're making progress bit by bit! Even small steps are valuable progress. Don't give up and keep going! Super lucky viki-chang~! 💖",
    "Well begun is half done! You've already started your missions. Let's move forward a little more! Super lucky viki-chang~! 💖",
    "Even small achievements deserve celebration! As you keep moving forward, big changes will come before you know it. Super lucky viki-chang~! 💖",
    "Step by step becomes a great journey! Just keep going steadily like now. Super lucky viki-chang~! 💖",
    "Your effort looks beautiful! Fighting for today too. Super lucky viki-chang~! 💖",
    "You're amazing for starting! Congratulations on completing your first mission. Keep challenging yourself! Super lucky viki-chang~! 💖",
    "Having missions in progress is great in itself! It's okay to proceed slowly. Super lucky viki-chang~! 💖",
    "Even small progress is growth! Today's little efforts create tomorrow's big changes. Super lucky viki-chang~! 💖",
    "Consistency is the most powerful force! If you keep going little by little, you'll reach your goal before you know it. Super lucky viki-chang~! 💖",
    "The effort in this moment creates your future self! Let's move forward little by little. Super lucky viki-chang~! 💖"
  ];

  static const List<String> _englishMidMessages = [
    "Over halfway done! You're doing great. Fighting for the remaining missions! Super lucky viki-chang~! 💖",
    "Your consistent efforts are shining! At this pace, achieving your goal is just around the corner. Super lucky viki-chang~! 💖",
    "I can see your efforts for a balanced life! You're having a wonderful day today. Super lucky viki-chang~! 💖",
    "You've passed the midpoint! Just a little more effort and you can achieve your goal. Super lucky viki-chang~! 💖",
    "This is the moment when consistency shines! Keep having a happy day like now. Super lucky viki-chang~! 💖",
    "You've already done more than half! Your willpower is really amazing. Fighting for the remaining missions! Super lucky viki-chang~! 💖",
    "You're showing steady progress! Keep going naturally like flowing water. Super lucky viki-chang~! 💖",
    "You're overcoming the middle hurdle well! At this rate, you'll soon achieve your goal. Super lucky viki-chang~! 💖",
    "You're maintaining a good pace! Keep running without getting tired. Super lucky viki-chang~! 💖",
    "Your progress is looking great! Please maintain this passion until the end. Super lucky viki-chang~! 💖"
  ];

  static const List<String> _englishHighMessages = [
    "Almost there! You're amazing. Fighting until the end! Today's you has grown one step further than yesterday's you. Super lucky viki-chang~! 💖",
    "The goal is right in front of you! I'm really proud of you for not giving up and coming this far. Super lucky viki-chang~! 💖",
    "Wow! Almost completed. This is the moment when your willpower shines! Super lucky viki-chang~! 💖",
    "The end is in sight! Let's put in a little more effort to finish perfectly. Super lucky viki-chang~! 💖",
    "Amazing! You've completed almost all missions. You're racing towards victory today too! Super lucky viki-chang~! 💖",
    "You'll soon open the door to success! Do your best until the very end. Super lucky viki-chang~! 💖",
    "The finish line is in sight! All your efforts so far will soon bear fruit. Super lucky viki-chang~! 💖",
    "The joy of achievement is just ahead! Fighting until the last mission! Super lucky viki-chang~! 💖",
    "You're achieving great results! Don't lose your focus until the end. Super lucky viki-chang~! 💖",
    "You're doing excellently! Just overcome this last hurdle for perfect success. Super lucky viki-chang~! 💖"
  ];

  static const List<String> _englishCompleteMessages = [
    "All missions complete! You've successfully wrapped up another day. You're truly the best! Super lucky viki-chang~! 💖",
    "100% achieved! You're amazing. Today's achievement will become tomorrow's confidence. Super lucky viki-chang~! 💖",
    "Perfect day! You who completed all missions are today's champion. Super lucky viki-chang~! 💖",
    "Congratulations! You've successfully completed all missions. Be proud of today's achievements! Super lucky viki-chang~! 💖",
    "Wow! 100% achievement. This is the moment when your passion and perseverance shine. Super lucky viki-chang~! 💖",
    "Mission all clear! Your efforts have borne perfect fruit. Congratulations! Super lucky viki-chang~! 💖",
    "All missions successful! You've wrapped up today perfectly. Give yourself a present! Super lucky viki-chang~! 💖",
    "100% perfect! This is a great result created by your willpower and execution. Super lucky viki-chang~! 💖",
    "Goal achievement complete! You can be really proud of yourself. Super lucky viki-chang~! 💖",
    "Successful day! You who completed all missions are a true winner. Super lucky viki-chang~! 💖"
  ];

  // 한국어 격려 명언 100개
  static const List<String> _koreanQuotes = [
    "성공한 사람이 되려고 노력하기보다 가치있는 사람이 되려고 노력하라. -알버트 아인슈타인",
    "당신이 할 수 있다고 믿든 할 수 없다고 믿든, 믿는 대로 될 것이다. -헨리 포드",
    "승자는 시간을 관리하며 살고 패자는 시간에 끌려 산다. -J. 하버드",
    "마음만을 가지고 있어서는 안된다. 반드시 실천하여야 한다. -이소룡",
    "인생에서 실패한 사람들의 대부분은 포기할 때 자신이 성공에서 얼마나 가까이 있었는지 깨닫지 못한다. -토마스 에디슨",
    "모든 성취의 시작점은 열망이다. -나폴레온 힐",
    "당신이 헤쳐나가야 할 길은 이미 많은 이들이 걸어간 길이다. 절대 홀로 걷는 것이 아니다. -전옥표",
    "인생은 자전거를 타는 것과 같다. 균형을 유지하려면 계속 움직여야 한다. -알버트 아인슈타인",
    "미루는 습관은 시간을 죽이고 활력을 파괴한다. -에드워드 영",
    "나약한 태도는 성격도 나약하게 만든다. -알버트 아인슈타인",
    "할 수 있다고 믿는 사람은 그렇게 되고, 할 수 없다고 믿는 사람도 역시 그렇게 된다. -샤를 드골",
    "태도는 작은 것이지만 큰 차이를 만든다. -윈스턴 처칠",
    "자신의 능력을 믿어야 한다. 그리고 그 능력을 까먹지 말아야 한다. -스탠리 큐브릭",
    "성공이란 열정을 잃지 않고 실패를 거듭할 수 있는 능력이다. -윈스턴 처칠",
    "성공한 사람을 볼 때 당신은 대중에게 보이는 영광만 보지, 그 영광을 얻기 위해 그 사람이 겪었던 고통은 보지 않는다. -바바라 코클랜드",
    "큰 목표를 이루고 싶으면, 허락을 구하지 마라. -미상",
    "나는 실패한 게 아니다. 나는 잘 되지 않는 방법 1만 가지를 발견한 것이다. -토마스 에디슨",
    "성공하려면 당신을 찾아오는 모든 도전을 다 받아들여야 한다. 어떤 방식으로든 당신을 개선시킬 수 있는 것이라면 무엇이든 붙잡아라. -마이크 가프카",
    "오늘 하루는 인생의 축소판이고, 태도는 내 인생의 예고편이다. -천상병",
    "중요한 건 당신이 어디서 왔는가가 아니라 어디로 가고 있는가다. -엘라 피츠제럴드",
    "때로는 바다 한가운데에 있는 것처럼 고독하고 방향이 없을 때가 있다. 그래도 항구는 거기 있다. -카츠미 노리하코",
    "평범한 노력으로는 평범한 결과를 얻는다. -알렉스 크루",
    "훌륭한 성과를 얻으려면 한 걸음 한 걸음이 힘차고 충실해야 한다. -미상",
    "행복한 가정을 이룬 사람들은 가정에서 좋은 것을 찾고, 불행한 가정을 이룬 사람들은 결점을 찾는다. -헬렌 롤랜드",
    "포기하면, 그 순간이 바로 게임 종료예요. -리처드 닉슨",
    "성공은 열심히 노력하며 기다리면 찾아오는 것이 아니라 노력하면서 만들어 가는 것이다. -윌마 루돌프",
    "무슨 일을 하기 전에는 그 일에 대해 기대를 가져야 한다. -마이클 조던",
    "성공은 매일 반복한 작은 노력들의 합이다. -로버트 콜리어",
    "일단 시작해라. 나중에 완벽해지면 된다. -론 무어",
    "게으른 천재가 근면한 바보보다 낫지 못하다. -헨리 와드 비처",
    "성공하기 위해서는 목표를 높게 잡아라. 그리고 성취할 때까지 멈추지 마라. -보 잭슨",
    "꿈을 이루려 노력해도 이루지 못할 수 있다. 그러나 노력하지 않는다면 아무것도 이룰 수 없다. -크리스 에버트",
    "당신은 지금 어디에 있는가와는 상관없이 원하는 곳으로 갈 수 있다. -고든 B. 힝클리",
    "걱정이 마치 의자 흔들듯 늘 당신을 바쁘게 만들지만 어디로도 데려다주지 않는다. -글렌 터너",
    "오늘 할 수 있는 일을 내일로 미루지 마라. -벤자민 프랭클린",
    "모든 것을 잃고 희망을 품을 수 있다면, 당신은 행복한 사람이다. -앤 프랭크",
    "꿈은 도망가지 않아. 도망가는 것은 언제나 자신이야. -미상",
    "당신이 그토록 간절히 바라는 것은 분명히 당신이 좋아하는 일일 것이다. -오프라 윈프리",
    "인생을 바꾸는 시간은 지금이 가장 빠르다. -미상",
    "실패란 것은 넘어지는 것이 아니라 넘어진 자리에 머무는 것이다. -레이디 메리 워틀리 몬터규",
    "계획이 없으면 목표는 한낱 꿈에 불과하다. -앙투안 드 생텍쥐페리",
    "좋은 것을 찾으면, 더 좋은 것이 있는지 둘러보아라. -존 록펠러",
    "나보다 뛰어난 선수들이 있다는 것은 알아요. 하지만 난 그들보다 열심히 노력할 자신이 있어요. -미셸 크완",
    "나는 내가 더 노력할수록 운이 더 좋아진다는 것을 발견했다. -토마스 제퍼슨",
    "세상은 고통으로 가득하지만, 그것을 극복하는 사람들로도 가득하다. -헬렌 켈러",
    "자신의 부족함을 인정하는 것이 성숙함의 시작이다. -칼 샌드버그",
    "좋은 성과를 얻으려면 한 걸음 한 걸음이 힘차고 충실해야 한다. -체호프",
    "언제나 현재에 집중할 수 있다면 행복할 것이다. -파울로 코엘료",
    "선수들은 심판이 할 수 있는 위치에서만 반칙을 하라고 배운다. -미상",
    "일을 맡아서 하라. 해놓으면 복이다. -공자",
    "위대한 것을 이루려고 애쓰지 마라. 단지 당신 앞에 놓인 일을 바르게 하여라. -헨리 롱펠로우",
    "위대한 사람은 기회가 없다고 원망하지 않는다. -에머슨",
    "삶의 질은 당신의 선택에 의해 결정됩니다. -앤 안드레스",
    "여러 날을, 몇 년을 헤매고 다니다가 이윽고 찾아낸 끝에는, 이들은 처음부터 그냥 곁에 있었다는 것을 알게 된다. -레베카 솔닛",
    "시간을 선택할 순 없어도 무엇을 심을지는 선택할 수 있다. -찰스 리플",
    "실패에서부터 성공을 만들어 내라. 좌절과 실패는 성공으로 가는 가장 확실한 디딤돌이다. -데일 카네기",
    "위대한 것은 하루 아침에 이루어지지 않는다. -윌리엄 셰익스피어",
    "여행은 목적지에 도착하는 것이 아니라, 기나긴 목적지를 향해 떠나는 과정이다. -어니스트 헤밍웨이",
    "사람은 세 가지 방법으로 지혜를 얻는다. 첫째, 생각으로 얻는 방법이 가장 고상하다. 둘째, 모방으로 얻는 방법이 가장 쉽다. 셋째, 경험으로 얻는 방법이 가장 괴롭다. -공자",
    "오늘 나무 그늘에서 쉴 수 있는 이유는 예전에 누군가가 나무를 심었기 때문이다. -워런 버핏",
    "인생은 자전거를 타는 것과 같다. 균형을 유지하려면 계속 움직여야 한다. -알버트 아인슈타인",
    "오늘 누군가의 꿈이 내일의 현실이 된다. -아미르 마흐무드 라피",
    "가장 큰 영광은 넘어지지 않는 것에 있는 것이 아니라 넘어질 때마다 일어서는 데 있다. -공자",
    "행복하게 살기 위해 중요한 것은 남들이 나를 어떻게 생각하는가가 아니라 내가 나를 어떻게 생각하는가이다. -법정 스님",
    "얻기 어려운 것을 시도하지 않는 사람은 아무것도 얻지 못할 것이다. -요한 볼프강 폰 괴테",
    "불가능한 것을 가능하게 만드는 것, 그것이 우리에게 주어진 도전이다. -토니 로빈스",
    "당신이 포기할 때, 그것이 바로 게임이 끝나는 때이다. -스티브 하비",
    "인생은 당신이 꿈꾸는 대로 살기에는 너무 짧다. 그러니 당신이 살고 싶은 대로 살아라. -웨인 다이어",
    "기회는 일어나는 것이 아니라 만들어내는 것이다. -크리스 그로서",
    "성공은 매일 반복한 작은 노력들의 합이다. -로버트 콜리어",
    "성공적인 삶이란 자신의 생각과 행동을 일치시키는 것이다. -간디",
    "나는 천천히 걷는다. 하지만 절대 뒤로 걷지는 않는다. -에이브러햄 링컨",
    "큰 도전은 더 큰 성취에 이르는 길이다. -미상",
    "하루하루를 마지막 날처럼 살아라. -스티브 잡스",
    "내가 좋아하는 것을 선택한 것이 아니라, 내가 선택한 것을 좋아하게 되었다. -이기주",
    "자신을 믿고 충분히 긴 시간을 견뎌라. 그러면 성공할 것이다. -나폴레온 힐",
    "삶은 위험을 감수할 때 비로소 빛난다. -헬렌 켈러",
    "기회의 문은 항상 닫혀 있지만, 그 문을 언제든지 열 수 있는 것이 바로 당신의 의지이다. -브라이언 트레이시",
    "당신이 이루고자 하는 것에 집중하라. 그러면 당신은 그것을 얻게 될 것이다. -마하트마 간디",
    "고통 없이는 얻는 것도 없다. -변성환",
    "시간은 당신을 기다려주지 않는다. 지금이 바로 당신의 시간이다. -미상",
    "승리하는 게 다가 아니라 지는 걸 이겨내는 게 더 중요하다. -존 우든",
    "자신이 가지고 있는 열정을 믿어라. 그 열정은 널 절대 실망시키지 않을 것이다. -켈로그",
    "늦었다고 생각했을 때가 가장 빠른 때이다. -박명수",
    "무엇을 선택하느냐가 중요한 것이 아니라, 선택한 것에 최선을 다하느냐가 중요하다. -보이드 K. 패커",
    "새로운 시작을 위해 어제를 잊고 내일을 꿈꾸세요. -엘리자베스 스콧",
    "모든 성공한 사람들은 실패를 경험한다. 그러나 그들은 포기하지 않는다. -미상",
    "너무 바쁘게 살다 보면 인생을 사는 목적을 잊게 된다. -미상",
    "오늘의 나는 어제의 나보다 한 단계 더 성장했다. -미상",
    "위대한 것을 이루고자 한다면 먼저 작은 것부터 시작하라. -스티브 잡스",
    "실패를 두려워하지 마라. 그것은 성공으로 가는 첫걸음이다. -미상",
    "당신이 가진 작은 것을 소중히 여기세요. 그것이 크게 자랄 것입니다. -켈빈 쿨리지",
    "어제와 똑같이 살면서 다른 미래를 기대하는 것은 정신병의 한 증상이다. -알버트 아인슈타인",
    "나는 천재가 아니다. 다만 많이 실패해왔을 뿐이다. -리차드 브랜슨",
    "위대한 업적은 결코 짧은 시간 안에 이루어지지 않는다. -헨리 포드",
    "성공은 매일 어제보다 나아지는 것이다. -미상",
    "책상 위에 놓인 돋보기가 태양 빛을, 한 점에 모을 때까지 아무런 위력이 없는 것처럼 사람의 능력도 집중되지 않으면 큰 성과를 거둘 수 없다. -데일 카네기",
    "실패란 새로 시작하는 기회일 뿐이다. -헨리 포드",
    "영감은 기다리는 것이 아니라 찾아가는 것이다. -파블로 피카소",
    "노력이 없으면 우연도 없다. -미상",
    "할 수 있다고 믿는 사람은 결국 그렇게 된다. -샤를 드골",
    "성공이란 넘어진 횟수보다 한번 더 일어선 횟수가 많은 것이다. -윈스턴 처칠",
    "원하는 것이 있다면 온 에너지를 집중해라. 그리고 도움이 필요하면 도움을 청해라. -데일 카네기"
  ];

  // 영어 격려 명언 100개
  static const List<String> _englishQuotes = [
    "The way to get started is to quit talking and begin doing. -Walt Disney",
    "Life is what happens when you're busy making other plans. -John Lennon",
    "The future belongs to those who believe in the beauty of their dreams. -Eleanor Roosevelt",
    "In three words I can sum up everything I've learned about life: it goes on. -Robert Frost",
    "The only way to do great work is to love what you do. -Steve Jobs",
    "If you look at what you have in life, you'll always have more. If you look at what you don't have in life, you'll never have enough. -Oprah Winfrey",
    "The best time to plant a tree was 20 years ago. The second best time is now. -Chinese Proverb",
    "The only person you are destined to become is the person you decide to be. -Ralph Waldo Emerson",
    "You miss 100% of the shots you don't take. -Wayne Gretzky",
    "Whether you think you can or you think you can't, you're right. -Henry Ford",
    "I've learned that people will forget what you said, people will forget what you did, but people will never forget how you made them feel. -Maya Angelou",
    "Twenty years from now you will be more disappointed by the things that you didn't do than by the ones you did do. -Mark Twain",
    "The mind is everything. What you think you become. -Buddha",
    "The best revenge is massive success. -Frank Sinatra",
    "Challenges are what make life interesting and overcoming them is what makes life meaningful. -Joshua J. Marine",
    "If you want to lift yourself up, lift up someone else. -Booker T. Washington",
    "Happiness is not something ready-made. It comes from your own actions. -Dalai Lama",
    "The only limit to our realization of tomorrow will be our doubts of today. -Franklin D. Roosevelt",
    "The journey of a thousand miles begins with one step. -Lao Tzu",
    "In the end, it's not the years in your life that count. It's the life in your years. -Abraham Lincoln",
    "Life is 10% what happens to me and 90% of how I react to it. -Charles Swindoll",
    "If you do what you've always done, you'll get what you've always gotten. -Tony Robbins",
    "The most common way people give up their power is by thinking they don't have any. -Alice Walker",
    "The most difficult thing is the decision to act, the rest is merely tenacity. -Amelia Earhart",
    "It does not matter how slowly you go as long as you do not stop. -Confucius",
    "Success is not final, failure is not fatal: it is the courage to continue that counts. -Winston Churchill",
    "Our greatest glory is not in never falling, but in rising every time we fall. -Confucius",
    "Believe you can and you're halfway there. -Theodore Roosevelt",
    "Everything you've ever wanted is on the other side of fear. -George Addair",
    "We can easily forgive a child who is afraid of the dark; the real tragedy of life is when men are afraid of the light. -Plato",
    "Nothing will work unless you do. -Maya Angelou",
    "I alone cannot change the world, but I can cast a stone across the water to create many ripples. -Mother Teresa",
    "What we achieve inwardly will change outer reality. -Plutarch",
    "Control your own destiny or someone else will. -Jack Welch",
    "It always seems impossible until it's done. -Nelson Mandela",
    "Keep your face always toward the sunshine, and shadows will fall behind you. -Walt Whitman",
    "Setting goals is the first step in turning the invisible into the visible. -Tony Robbins",
    "If you want to make your dreams come true, the first thing you have to do is wake up. -J.M. Power",
    "The only place where success comes before work is in the dictionary. -Vidal Sassoon",
    "Don't watch the clock; do what it does. Keep going. -Sam Levenson",
    "The harder I work, the luckier I get. -Gary Player",
    "Opportunity is missed by most people because it is dressed in overalls and looks like work. -Thomas Edison",
    "Change your thoughts and you change your world. -Norman Vincent Peale",
    "The difference between ordinary and extraordinary is that little extra. -Jimmy Johnson",
    "Even if you're on the right track, you'll get run over if you just sit there. -Will Rogers",
    "Start where you are. Use what you have. Do what you can. -Arthur Ashe",
    "The secret of getting ahead is getting started. -Mark Twain",
    "If you're going through hell, keep going. -Winston Churchill",
    "You don't have to be great to start, but you have to start to be great. -Zig Ziglar",
    "Dream big and dare to fail. -Norman Vaughan",
    "Your time is limited, don't waste it living someone else's life. -Steve Jobs",
    "The purpose of our lives is to be happy. -Dalai Lama",
    "Life shrinks or expands in proportion to one's courage. -Anais Nin",
    "The two most important days in your life are the day you are born and the day you find out why. -Mark Twain",
    "Whatever you can do, or dream you can, begin it. Boldness has genius, power and magic in it. -Johann Wolfgang von Goethe",
    "The question isn't who is going to let me; it's who is going to stop me. -Ayn Rand",
    "We must believe that we are gifted for something, and that this thing, at whatever cost, must be attained. -Marie Curie",
    "Life is not measured by the number of breaths we take, but by the moments that take our breath away. -Maya Angelou",
    "If you want to lift yourself up, lift up someone else. -Booker T. Washington",
    "Too many of us are not living our dreams because we are living our fears. -Les Brown",
    "Strive not to be a success, but rather to be of value. -Albert Einstein",
    "Our lives begin to end the day we become silent about things that matter. -Martin Luther King Jr.",
    "Remember that not getting what you want is sometimes a wonderful stroke of luck. -Dalai Lama",
    "You can't use up creativity. The more you use, the more you have. -Maya Angelou",
    "A person who never made a mistake never tried anything new. -Albert Einstein",
    "The person who says it cannot be done should not interrupt the person who is doing it. -Chinese Proverb",
    "There is only one way to avoid criticism: do nothing, say nothing, and be nothing. -Aristotle",
    "Ask and it will be given to you; search, and you will find; knock and the door will be opened for you. -Jesus",
    "When everything seems to be going against you, remember that the airplane takes off against the wind, not with it. -Henry Ford",
    "The most beautiful experience we can have is the mysterious. It is the fundamental emotion that stands at the cradle of true art and true science. -Albert Einstein",
    "It is our choices that show what we truly are, far more than our abilities. -J.K. Rowling",
    "Don't judge each day by the harvest you reap but by the seeds that you plant. -Robert Louis Stevenson",
    "The real opportunity for success lies within the person and not in the job. -Zig Ziglar",
    "If you don't design your own life plan, chances are you'll fall into someone else's plan. And guess what they have planned for you? Not much. -Jim Rohn",
    "What lies behind us and what lies before us are tiny matters compared to what lies within us. -Ralph Waldo Emerson",
    "Be yourself; everyone else is already taken. -Oscar Wilde",
    "You can never cross the ocean until you have the courage to lose sight of the shore. -Christopher Columbus",
    "The greatest glory in living lies not in never falling, but in rising every time we fall. -Nelson Mandela",
    "Live as if you were to die tomorrow. Learn as if you were to live forever. -Mahatma Gandhi",
    "The road to success and the road to failure are almost exactly the same. -Colin R. Davis",
    "Success is not how high you have climbed, but how you make a positive difference to the world. -Roy T. Bennett",
    "Don't be pushed around by the fears in your mind. Be led by the dreams in your heart. -Roy T. Bennett",
    "It's not whether you get knocked down, it's whether you get up. -Vince Lombardi",
    "If you want to achieve greatness stop asking for permission. -Anonymous",
    "Things work out best for those who make the best of how things work out. -John Wooden",
    "To live a creative life, we must lose our fear of being wrong. -Anonymous",
    "If you are not willing to risk the usual you will have to settle for the ordinary. -Jim Rohn",
    "All our dreams can come true if we have the courage to pursue them. -Walt Disney",
    "A ship is always safe at the shore - but that is NOT what it is built for. -Albert Einstein",
    "Challenges are gifts that force us to search for a new center of gravity. Don't fight them. Just find a new way to stand. -Oprah Winfrey",
    "We must let go of the life we planned so as to accept the one that is waiting for us. -Joseph Campbell",
    "Always do your best. What you plant now, you will harvest later. -Og Mandino",
    "Aim for the moon. If you miss, you may hit a star. -W. Clement Stone",
    "Never give up, for that is just the place and time that the tide will turn. -Harriet Beecher Stowe",
    "Don't let yesterday take up too much of today. -Will Rogers",
    "You learn more from failure than from success. Don't let it stop you. Failure builds character. -Unknown",
    "It's not about perfect. It's about effort. And when you bring that effort every single day, that's where transformation happens. That's how change occurs. -Jillian Michaels",
    "The only limit to our realization of tomorrow will be our doubts of today. -Franklin D. Roosevelt",
    "Some people dream of success, while other people get up every morning and make it happen. -Wayne Huizenga",
    "Nobody ever wrote down a plan to be broke, fat, lazy, or stupid. Those things are what happen when you don't have a plan. -Larry Winget",
    "The successful warrior is the average man, with laser-like focus. -Bruce Lee",
    "The starting point of all achievement is desire. -Napoleon Hill"
  ];
}

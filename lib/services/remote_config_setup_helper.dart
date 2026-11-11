import 'dart:convert';
import '../utils/logger.dart';

/// Firebase Remote Config 설정을 도와주는 헬퍼 클래스
class RemoteConfigSetupHelper {
  /// Firebase Console에 추가할 Remote Config 매개변수 JSON 생성
  static String generateFirebaseConsoleJson() {
    final parameters = {
      'GEMINI_API_KEY': {
        'defaultValue': {'value': ''},
        'description': 'Google Gemini AI API 키 - AI 채팅 및 번역 기능에 사용',
        'valueType': 'STRING'
      },
      'GEMIN_API_KEY_SHOP': {
        'defaultValue': {'value': ''},
        'description': 'Google Gemini AI API 키 - 행복상점 기능에 사용',
        'valueType': 'STRING'
      },
      'KAKAO_API_KEY': {
        'defaultValue': {'value': ''},
        'description': 'Kakao SDK API 키 - 소셜 로그인에 사용',
        'valueType': 'STRING'
      },
      'DEBUG_MODE': {
        'defaultValue': {'value': 'false'},
        'description': '디버그 모드 활성화 여부',
        'valueType': 'BOOLEAN'
      },
      'API_TIMEOUT': {
        'defaultValue': {'value': '30000'},
        'description': 'API 호출 타임아웃 설정 (밀리초)',
        'valueType': 'NUMBER'
      },
      'CACHE_DURATION': {
        'defaultValue': {'value': '3600'},
        'description': '캐시 유지 시간 (초)',
        'valueType': 'NUMBER'
      },
      'FEATURE_AI_CHAT': {
        'defaultValue': {'value': 'true'},
        'description': 'AI 채팅 기능 활성화 여부',
        'valueType': 'BOOLEAN'
      },
      'FEATURE_TRANSLATION': {
        'defaultValue': {'value': 'true'},
        'description': '텍스트 번역 기능 활성화 여부',
        'valueType': 'BOOLEAN'
      },
      'MAX_RETRY_COUNT': {
        'defaultValue': {'value': '3'},
        'description': 'API 호출 최대 재시도 횟수',
        'valueType': 'NUMBER'
      }
    };

    return JsonEncoder.withIndent('  ').convert(parameters);
  }

  /// Firebase CLI 명령어 생성
  static List<String> generateFirebaseCLICommands() {
    final commands = [
      '# Firebase Remote Config 매개변수 설정 CLI 명령어',
      '',
      '# 1. API 키 설정',
      'firebase remoteconfig:set GEMINI_API_KEY "your_actual_gemini_api_key_here" --description "Google Gemini AI API 키"',
      'firebase remoteconfig:set GEMIN_API_KEY_SHOP "your_actual_gemini_api_key_here" --description "Google Gemini AI API 키 - 행복상점"',
      'firebase remoteconfig:set KAKAO_API_KEY "your_actual_kakao_api_key_here" --description "Kakao SDK API 키"',
      '',
      '# 2. 앱 설정',
      'firebase remoteconfig:set DEBUG_MODE false --description "디버그 모드 활성화 여부"',
      'firebase remoteconfig:set API_TIMEOUT 30000 --description "API 호출 타임아웃 (밀리초)"',
      'firebase remoteconfig:set CACHE_DURATION 3600 --description "캐시 유지 시간 (초)"',
      '',
      '# 3. 기능 플래그',
      'firebase remoteconfig:set FEATURE_AI_CHAT true --description "AI 채팅 기능 활성화"',
      'firebase remoteconfig:set FEATURE_TRANSLATION true --description "번역 기능 활성화"',
      '',
      '# 4. 기타 설정',
      'firebase remoteconfig:set MAX_RETRY_COUNT 3 --description "최대 재시도 횟수"',
      '',
      '# 5. 설정 게시',
      'firebase remoteconfig:publish',
    ];

    return commands;
  }

  /// 콘솔에 설정 가이드 출력
  static void printSetupGuide() {
    Logger.info('=== Firebase Remote Config 설정 가이드 ===');
    Logger.info('');
    Logger.info('🔧 방법 1: Firebase Console 사용');
    Logger.info('1. Firebase Console (https://console.firebase.google.com) 접속');
    Logger.info('2. 프로젝트 선택 > Remote Config 메뉴');
    Logger.info('3. "매개변수 추가" 버튼 클릭');
    Logger.info('4. 아래 매개변수들을 각각 추가:');
    Logger.info('');

    final parameters = [
      {
        'key': 'GEMINI_API_KEY',
        'type': 'String',
        'desc': 'Google Gemini AI API 키'
      },
      {
        'key': 'GEMIN_API_KEY_SHOP',
        'type': 'String',
        'desc': 'Google Gemini AI API 키 - 행복상점'
      },
      {'key': 'KAKAO_API_KEY', 'type': 'String', 'desc': 'Kakao SDK API 키'},
      {
        'key': 'DEBUG_MODE',
        'type': 'Boolean',
        'desc': '디버그 모드',
        'default': 'false'
      },
      {
        'key': 'API_TIMEOUT',
        'type': 'Number',
        'desc': 'API 타임아웃',
        'default': '30000'
      },
      {
        'key': 'CACHE_DURATION',
        'type': 'Number',
        'desc': '캐시 시간',
        'default': '3600'
      },
      {
        'key': 'FEATURE_AI_CHAT',
        'type': 'Boolean',
        'desc': 'AI 채팅 기능',
        'default': 'true'
      },
      {
        'key': 'FEATURE_TRANSLATION',
        'type': 'Boolean',
        'desc': '번역 기능',
        'default': 'true'
      },
      {
        'key': 'MAX_RETRY_COUNT',
        'type': 'Number',
        'desc': '최대 재시도',
        'default': '3'
      },
    ];

    for (var param in parameters) {
      Logger.info('   • ${param['key']} (${param['type']}) - ${param['desc']}');
      if (param.containsKey('default')) {
        Logger.info('     기본값: ${param['default']}');
      }
    }

    Logger.info('');
    Logger.info('5. 모든 매개변수 추가 후 "변경사항 게시" 클릭');
    Logger.info('');
    Logger.info('💻 방법 2: Firebase CLI 사용');
    Logger.info('Firebase CLI가 설치되어 있다면 다음 명령어들을 실행:');
    Logger.info('');

    final commands = generateFirebaseCLICommands();
    for (String command in commands) {
      Logger.info(command);
    }

    Logger.info('');
    Logger.info('✅ 설정 완료 후 앱에서 확인');
    Logger.info('1. 앱 재시작');
    Logger.info('2. 환경 변수 설정 화면에서 "수동 업데이트" 버튼 클릭');
    Logger.info('3. 새로운 값들이 적용되는지 확인');
    Logger.info('');
    Logger.info('🔄 자동 업데이트');
    Logger.info('- Remote Config는 1시간마다 자동으로 새 값을 확인합니다');
    Logger.info('- 앱 시작 시에도 백그라운드에서 업데이트를 시도합니다');
    Logger.info('- 네트워크가 없어도 캐시된 값을 사용하여 정상 작동합니다');
    Logger.info('==========================================');
  }

  /// Remote Config 템플릿 파일 생성 (개발용)
  static String generateTemplateFile() {
    final template = {
      'conditions': [],
      'parameters': {},
      'version': {
        'versionNumber': '1',
        'updateTime': DateTime.now().toIso8601String(),
        'updateUser': {'email': 'developer@example.com'},
        'updateOrigin': 'CONSOLE',
        'updateType': 'INCREMENTAL_UPDATE'
      }
    };

    // 매개변수 추가
    final parameters = {
      'GEMINI_API_KEY': {
        'defaultValue': {'value': ''},
        'description': 'Google Gemini AI API 키'
      },
      'GEMIN_API_KEY_SHOP': {
        'defaultValue': {'value': ''},
        'description': 'Google Gemini AI API 키 - 행복상점'
      },
      'KAKAO_API_KEY': {
        'defaultValue': {'value': ''},
        'description': 'Kakao SDK API 키'
      },
      'DEBUG_MODE': {
        'defaultValue': {'value': 'false'},
        'description': '디버그 모드 활성화'
      },
      'API_TIMEOUT': {
        'defaultValue': {'value': '30000'},
        'description': 'API 호출 타임아웃 (밀리초)'
      },
      'CACHE_DURATION': {
        'defaultValue': {'value': '3600'},
        'description': '캐시 유지 시간 (초)'
      },
      'FEATURE_AI_CHAT': {
        'defaultValue': {'value': 'true'},
        'description': 'AI 채팅 기능 활성화'
      },
      'FEATURE_TRANSLATION': {
        'defaultValue': {'value': 'true'},
        'description': '번역 기능 활성화'
      },
      'MAX_RETRY_COUNT': {
        'defaultValue': {'value': '3'},
        'description': '최대 재시도 횟수'
      }
    };

    template['parameters'] = parameters;

    return JsonEncoder.withIndent('  ').convert(template);
  }
}

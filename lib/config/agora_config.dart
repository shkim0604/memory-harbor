/// Agora RTC 설정
///
/// Agora Console (https://console.agora.io)에서 App ID를 발급받으세요.
///
/// 프로덕션 환경에서는 토큰 서버를 구축하여 사용해야 합니다.
/// - Token 없이 테스트: appId만 설정, token은 빈 문자열
/// - Token 사용: 서버에서 토큰을 발급받아 joinChannel 시 전달
class AgoraConfig {
  static const String appId = '00291e4156b64729b1b7c1e3a3646e90';

  // API base URL (token/recording) - 맥미니 서버
  static const String apiBaseUrl = 'https://memory-harbor.delight-house.org';

  // Default channel settings
  static const int defaultUid = 0; // 0 = auto-assign
  static const int recordingBotUid = 999999;
  static const bool enableRecording = true;
}

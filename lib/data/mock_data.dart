import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/time_utils.dart';

class ResidenceUiMeta {
  final IconData icon;
  final Color color;

  const ResidenceUiMeta({required this.icon, required this.color});
}

/// ============================================================
/// Mock 데이터 - 개발용 더미 데이터
/// ============================================================
class MockData {
  MockData._();

  static final Group group = Group(
    groupId: 'group_1',
    name: 'MemHarbor 가족',
    careGiverUserIds: const [
      'user_me',
      'user_minsu',
      'user_younghee',
      'user_jihoon',
      'user_sujin',
    ],
    receiverId: 'receiver_1',
    stats: GroupStats(
      totalCalls: 44,
      lastCallAt: DateTime(2026, 1, 28),
      lastCallId: 'call_20260128_me',
    ),
  );

  // ----------------------------------------------------------
  // 케어리시버 정보
  // ----------------------------------------------------------
  static final CareReceiver careReceiver = CareReceiver(
    receiverId: 'receiver_1',
    groupId: group.groupId,
    name: '김순자 할머니',
    profileImage: 'assets/images/logo.png',
    majorResidences: residences,
  );

  // ----------------------------------------------------------
  // 사용자(케어기버) 정보
  // ----------------------------------------------------------
  static final List<AppUser> caregivers = [
    AppUser(
      uid: 'user_minsu',
      name: '박민수',
      email: 'minsu@example.com',
      profileImage: '',
      groupIds: [group.groupId],
      createdAt: DateTime(2025, 12, 20),
    ),
    AppUser(
      uid: 'user_younghee',
      name: '이영희',
      email: 'younghee@example.com',
      profileImage: '',
      groupIds: [group.groupId],
      createdAt: DateTime(2025, 12, 22),
    ),
    AppUser(
      uid: 'user_jihoon',
      name: '최지훈',
      email: 'jihoon@example.com',
      profileImage: '',
      groupIds: [group.groupId],
      createdAt: DateTime(2025, 12, 24),
    ),
    AppUser(
      uid: 'user_sujin',
      name: '김수진',
      email: 'sujin@example.com',
      profileImage: '',
      groupIds: [group.groupId],
      createdAt: DateTime(2025, 12, 26),
    ),
  ];

  static final Map<String, AppUser> _caregiverById = {
    for (final user in caregivers) user.uid: user,
  };

  // ----------------------------------------------------------
  // 시대별 거주지 데이터
  // ----------------------------------------------------------
  static const List<Residence> residences = [
    Residence(
      residenceId: 'res_1950s_andong',
      era: '1950~1960',
      location: '경상북도 안동시',
      detail: '태어난 곳, 어린 시절',
    ),
    Residence(
      residenceId: 'res_1960s_jongno',
      era: '1960~1975',
      location: '서울 종로구',
      detail: '학창시절, 결혼 전',
    ),
    Residence(
      residenceId: 'res_1975s_gangnam',
      era: '1975~1990',
      location: '서울 강남구',
      detail: '신혼, 자녀 양육기',
    ),
    Residence(
      residenceId: 'res_1990s_bundang',
      era: '1990~2010',
      location: '경기도 분당',
      detail: '자녀 독립 후',
    ),
    Residence(
      residenceId: 'res_2010s_seocho',
      era: '2010~현재',
      location: '서울 서초구',
      detail: '현재 거주지',
    ),
  ];

  static const ResidenceUiMeta _defaultResidenceUi = ResidenceUiMeta(
    icon: Icons.home,
    color: Colors.grey,
  );

  static const Map<String, ResidenceUiMeta> residenceUiById = {
    'res_1950s_andong': ResidenceUiMeta(
      icon: Icons.child_care,
      color: Color(0xFFFFB74D),
    ),
    'res_1960s_jongno': ResidenceUiMeta(
      icon: Icons.school,
      color: Color(0xFF64B5F6),
    ),
    'res_1975s_gangnam': ResidenceUiMeta(
      icon: Icons.family_restroom,
      color: Color(0xFF81C784),
    ),
    'res_1990s_bundang': ResidenceUiMeta(
      icon: Icons.park,
      color: Color(0xFFBA68C8),
    ),
    'res_2010s_seocho': ResidenceUiMeta(
      icon: Icons.home,
      color: Color(0xFF4DB6AC),
    ),
  };

  static final Map<String, ResidenceStats> residenceStatsById = {
    'res_1950s_andong': ResidenceStats(
      groupId: group.groupId,
      receiverId: careReceiver.receiverId,
      residenceId: 'res_1950s_andong',
      keywords: const ['하회마을', '안동찜닭', '탈춤', '서당', '한옥', '낙동강', '유교문화'],
      totalCalls: 12,
      lastCallAt: DateTime(2026, 1, 15),
      aiSummary: '',
      humanComments: const [
        '하회마을에서 탈춤 구경하며 놀았던 기억이 가장 생생하셨대요.',
        '마을 서당에서 한문을 배우며 훈장 선생님이 엄하셨던 추억.',
        '여름이면 낙동강에서 친구들과 물놀이하던 이야기.',
      ],
    ),
    'res_1960s_jongno': ResidenceStats(
      groupId: group.groupId,
      receiverId: careReceiver.receiverId,
      residenceId: 'res_1960s_jongno',
      keywords: const ['경복궁', '인사동', '광화문', '청계천', '종로3가', '낙원상가', '보신각'],
      totalCalls: 8,
      lastCallAt: DateTime(2026, 1, 27),
      aiSummary: '',
      humanComments: const [
        '학교 끝나고 종로 분식집에서 떡볶이를 먹던 기억.',
        '광화문에서 처음 만났던 데이트 이야기.',
        '주말마다 청계천 산책하며 시장 간식 먹던 추억.',
      ],
    ),
    'res_1975s_gangnam': ResidenceStats(
      groupId: group.groupId,
      receiverId: careReceiver.receiverId,
      residenceId: 'res_1975s_gangnam',
      keywords: const ['압구정', '신사동', '학원가', '아파트', '한강', '테헤란로', '코엑스'],
      totalCalls: 15,
      lastCallAt: DateTime(2026, 1, 25),
      aiSummary: '',
      humanComments: const [
        '강남 첫 이사 때 아파트 생활이 낯설었던 기억.',
        '아이들 학원 보내느라 바빴던 시절.',
        '주말마다 한강에서 자전거 타던 이야기.',
      ],
    ),
    'res_1990s_bundang': ResidenceStats(
      groupId: group.groupId,
      receiverId: careReceiver.receiverId,
      residenceId: 'res_1990s_bundang',
      keywords: const ['중앙공원', '서현역', '정자동', '율동공원', '신도시', '분당선', '불곡산'],
      totalCalls: 6,
      lastCallAt: DateTime(2026, 1, 20),
      aiSummary: '',
      humanComments: const [
        '분당 신도시로 이사하면서 공원이 많아 좋았다고 하셨어요.',
        '율동공원에서 산책하며 만난 친구들 이야기.',
      ],
    ),
    'res_2010s_seocho': ResidenceStats(
      groupId: group.groupId,
      receiverId: careReceiver.receiverId,
      residenceId: 'res_2010s_seocho',
      keywords: const ['예술의전당', '서래마을', '반포', '고속터미널', '양재천', '우면산', '법원'],
      totalCalls: 3,
      lastCallAt: DateTime(2026, 1, 28),
      aiSummary: '',
      humanComments: const ['예술의전당 클래식 공연을 좋아하신다고.', '저녁마다 양재천 산책이 일과라는 이야기.'],
    ),
  };

  // ----------------------------------------------------------
  // 통화 기록 데이터
  // ----------------------------------------------------------
  static final List<Call> myCallHistory = [
    Call(
      callId: 'call_20260128_me',
      channelId: 'channel_20260128_me',
      groupId: group.groupId,
      receiverId: careReceiver.receiverId,
      caregiverUserId: 'user_me',
      groupNameSnapshot: group.name,
      giverNameSnapshot: '나',
      receiverNameSnapshot: careReceiver.name,
      startedAt: DateTime(2026, 1, 28, 14, 30),
      durationSec: 15 * 60,
      humanSummary: '어린 시절 안동 이야기, 탈춤 축제 추억',
      mentionedResidences: const [
        Residence(
          residenceId: 'res_1950s_andong',
          era: '1950~1960',
          location: '경상북도 안동시',
          detail: '태어난 곳, 어린 시절',
        ),
      ],
    ),
    Call(
      callId: 'call_20260125_me',
      channelId: 'channel_20260125_me',
      groupId: group.groupId,
      receiverId: careReceiver.receiverId,
      caregiverUserId: 'user_me',
      groupNameSnapshot: group.name,
      giverNameSnapshot: '나',
      receiverNameSnapshot: careReceiver.name,
      startedAt: DateTime(2026, 1, 25, 10, 15),
      durationSec: 22 * 60,
      humanSummary: '손자 이야기, 요즘 드시는 약 확인',
      mentionedResidences: const [
        Residence(
          residenceId: 'res_2010s_seocho',
          era: '2010~현재',
          location: '서울 서초구',
          detail: '현재 거주지',
        ),
      ],
    ),
    Call(
      callId: 'call_20260122_me',
      channelId: 'channel_20260122_me',
      groupId: group.groupId,
      receiverId: careReceiver.receiverId,
      caregiverUserId: 'user_me',
      groupNameSnapshot: group.name,
      giverNameSnapshot: '나',
      receiverNameSnapshot: careReceiver.name,
      startedAt: DateTime(2026, 1, 22, 16, 0),
      durationSec: 18 * 60,
      humanSummary: '좋아하시는 음식, 건강 상태 체크',
      mentionedResidences: const [
        Residence(
          residenceId: 'res_1990s_bundang',
          era: '1990~2010',
          location: '경기도 분당',
          detail: '자녀 독립 후',
        ),
      ],
    ),
  ];

  static final List<Call> communityCallHistory = [
    Call(
      callId: 'call_20260127_minsu',
      channelId: 'channel_20260127_minsu',
      groupId: group.groupId,
      receiverId: careReceiver.receiverId,
      caregiverUserId: 'user_minsu',
      groupNameSnapshot: group.name,
      giverNameSnapshot: '박민수',
      receiverNameSnapshot: careReceiver.name,
      startedAt: DateTime(2026, 1, 27, 11, 0),
      durationSec: 20 * 60,
      humanSummary: '종로 시절 학창시절 이야기',
      mentionedResidences: const [
        Residence(
          residenceId: 'res_1960s_jongno',
          era: '1960~1975',
          location: '서울 종로구',
          detail: '학창시절, 결혼 전',
        ),
      ],
    ),
    Call(
      callId: 'call_20260126_younghee',
      channelId: 'channel_20260126_younghee',
      groupId: group.groupId,
      receiverId: careReceiver.receiverId,
      caregiverUserId: 'user_younghee',
      groupNameSnapshot: group.name,
      giverNameSnapshot: '이영희',
      receiverNameSnapshot: careReceiver.name,
      startedAt: DateTime(2026, 1, 26, 15, 30),
      durationSec: 15 * 60,
      humanSummary: '손녀 결혼 준비 이야기',
      mentionedResidences: const [
        Residence(
          residenceId: 'res_1975s_gangnam',
          era: '1975~1990',
          location: '서울 강남구',
          detail: '신혼, 자녀 양육기',
        ),
      ],
    ),
    Call(
      callId: 'call_20260124_jihoon',
      channelId: 'channel_20260124_jihoon',
      groupId: group.groupId,
      receiverId: careReceiver.receiverId,
      caregiverUserId: 'user_jihoon',
      groupNameSnapshot: group.name,
      giverNameSnapshot: '최지훈',
      receiverNameSnapshot: careReceiver.name,
      startedAt: DateTime(2026, 1, 24, 9, 0),
      durationSec: 25 * 60,
      humanSummary: '분당 생활, 공원 산책 이야기',
      mentionedResidences: const [
        Residence(
          residenceId: 'res_1990s_bundang',
          era: '1990~2010',
          location: '경기도 분당',
          detail: '자녀 독립 후',
        ),
      ],
    ),
  ];

  static final List<Call> _locationHistoryCalls = [
    Call(
      callId: 'call_20260115_andong',
      channelId: 'channel_20260115_andong',
      groupId: group.groupId,
      receiverId: careReceiver.receiverId,
      caregiverUserId: 'user_minsu',
      groupNameSnapshot: group.name,
      giverNameSnapshot: '박민수',
      receiverNameSnapshot: careReceiver.name,
      startedAt: DateTime(2026, 1, 15, 10, 0),
      durationSec: 18 * 60,
      humanSummary: '하회마을 탈춤 이야기, 어린 시절 친구들',
      mentionedResidences: const [
        Residence(
          residenceId: 'res_1950s_andong',
          era: '1950~1960',
          location: '경상북도 안동시',
          detail: '태어난 곳, 어린 시절',
        ),
      ],
    ),
    Call(
      callId: 'call_20260110_andong',
      channelId: 'channel_20260110_andong',
      groupId: group.groupId,
      receiverId: careReceiver.receiverId,
      caregiverUserId: 'user_younghee',
      groupNameSnapshot: group.name,
      giverNameSnapshot: '이영희',
      receiverNameSnapshot: careReceiver.name,
      startedAt: DateTime(2026, 1, 10, 13, 0),
      durationSec: 22 * 60,
      humanSummary: '서당에서 한문 배우던 이야기',
      mentionedResidences: const [
        Residence(
          residenceId: 'res_1950s_andong',
          era: '1950~1960',
          location: '경상북도 안동시',
          detail: '태어난 곳, 어린 시절',
        ),
      ],
    ),
    Call(
      callId: 'call_20260105_andong',
      channelId: 'channel_20260105_andong',
      groupId: group.groupId,
      receiverId: careReceiver.receiverId,
      caregiverUserId: 'user_jihoon',
      groupNameSnapshot: group.name,
      giverNameSnapshot: '최지훈',
      receiverNameSnapshot: careReceiver.name,
      startedAt: DateTime(2026, 1, 5, 9, 0),
      durationSec: 15 * 60,
      humanSummary: '명절 음식, 송편 빚던 추억',
      mentionedResidences: const [
        Residence(
          residenceId: 'res_1950s_andong',
          era: '1950~1960',
          location: '경상북도 안동시',
          detail: '태어난 곳, 어린 시절',
        ),
      ],
    ),
    Call(
      callId: 'call_20260127_jongno',
      channelId: 'channel_20260127_jongno',
      groupId: group.groupId,
      receiverId: careReceiver.receiverId,
      caregiverUserId: 'user_minsu',
      groupNameSnapshot: group.name,
      giverNameSnapshot: '박민수',
      receiverNameSnapshot: careReceiver.name,
      startedAt: DateTime(2026, 1, 27, 17, 0),
      durationSec: 15 * 60,
      humanSummary: '종로 분식집 떡볶이 이야기',
      mentionedResidences: const [
        Residence(
          residenceId: 'res_1960s_jongno',
          era: '1960~1975',
          location: '서울 종로구',
          detail: '학창시절, 결혼 전',
        ),
      ],
    ),
    Call(
      callId: 'call_20260122_jongno',
      channelId: 'channel_20260122_jongno',
      groupId: group.groupId,
      receiverId: careReceiver.receiverId,
      caregiverUserId: 'user_sujin',
      groupNameSnapshot: group.name,
      giverNameSnapshot: '김수진',
      receiverNameSnapshot: careReceiver.name,
      startedAt: DateTime(2026, 1, 22, 19, 0),
      durationSec: 20 * 60,
      humanSummary: '광화문 첫 데이트 이야기',
      mentionedResidences: const [
        Residence(
          residenceId: 'res_1960s_jongno',
          era: '1960~1975',
          location: '서울 종로구',
          detail: '학창시절, 결혼 전',
        ),
      ],
    ),
    Call(
      callId: 'call_20260125_gangnam',
      channelId: 'channel_20260125_gangnam',
      groupId: group.groupId,
      receiverId: careReceiver.receiverId,
      caregiverUserId: 'user_younghee',
      groupNameSnapshot: group.name,
      giverNameSnapshot: '이영희',
      receiverNameSnapshot: careReceiver.name,
      startedAt: DateTime(2026, 1, 25, 12, 0),
      durationSec: 22 * 60,
      humanSummary: '아이들 학원 데려다주던 이야기',
      mentionedResidences: const [
        Residence(
          residenceId: 'res_1975s_gangnam',
          era: '1975~1990',
          location: '서울 강남구',
          detail: '신혼, 자녀 양육기',
        ),
      ],
    ),
    Call(
      callId: 'call_20260118_gangnam',
      channelId: 'channel_20260118_gangnam',
      groupId: group.groupId,
      receiverId: careReceiver.receiverId,
      caregiverUserId: 'user_jihoon',
      groupNameSnapshot: group.name,
      giverNameSnapshot: '최지훈',
      receiverNameSnapshot: careReceiver.name,
      startedAt: DateTime(2026, 1, 18, 11, 0),
      durationSec: 17 * 60,
      humanSummary: '한강 자전거 타던 추억',
      mentionedResidences: const [
        Residence(
          residenceId: 'res_1975s_gangnam',
          era: '1975~1990',
          location: '서울 강남구',
          detail: '신혼, 자녀 양육기',
        ),
      ],
    ),
    Call(
      callId: 'call_20260120_bundang',
      channelId: 'channel_20260120_bundang',
      groupId: group.groupId,
      receiverId: careReceiver.receiverId,
      caregiverUserId: 'user_sujin',
      groupNameSnapshot: group.name,
      giverNameSnapshot: '김수진',
      receiverNameSnapshot: careReceiver.name,
      startedAt: DateTime(2026, 1, 20, 15, 0),
      durationSec: 12 * 60,
      humanSummary: '율동공원 산책 친구들 이야기',
      mentionedResidences: const [
        Residence(
          residenceId: 'res_1990s_bundang',
          era: '1990~2010',
          location: '경기도 분당',
          detail: '자녀 독립 후',
        ),
      ],
    ),
    Call(
      callId: 'call_20260128_seocho',
      channelId: 'channel_20260128_seocho',
      groupId: group.groupId,
      receiverId: careReceiver.receiverId,
      caregiverUserId: 'user_minsu',
      groupNameSnapshot: group.name,
      giverNameSnapshot: '박민수',
      receiverNameSnapshot: careReceiver.name,
      startedAt: DateTime(2026, 1, 28, 20, 0),
      durationSec: 10 * 60,
      humanSummary: '양재천 산책, 날씨 이야기',
      mentionedResidences: const [
        Residence(
          residenceId: 'res_2010s_seocho',
          era: '2010~현재',
          location: '서울 서초구',
          detail: '현재 거주지',
        ),
      ],
    ),
  ];

  static List<Call> get allCalls => [
    ...myCallHistory,
    ...communityCallHistory,
    ..._locationHistoryCalls,
  ];

  // ----------------------------------------------------------
  // 헬퍼 메서드
  // ----------------------------------------------------------
  static ResidenceUiMeta getResidenceUi(Residence residence) {
    return residenceUiById[residence.residenceId] ?? _defaultResidenceUi;
  }

  static ResidenceStats? getResidenceStats(Residence residence) {
    return residenceStatsById[residence.residenceId];
  }

  static List<String> getKeywordsByResidenceId(String residenceId) {
    return residenceStatsById[residenceId]?.keywords ?? const [];
  }

  static List<String> getStoryCommentsByResidenceId(String residenceId) {
    return residenceStatsById[residenceId]?.humanComments ?? const [];
  }

  static List<Call> getCallHistoryByResidenceId(String residenceId) {
    final calls = allCalls
        .where(
          (call) => call.mentionedResidences.any(
            (residence) => residence.residenceId == residenceId,
          ),
        )
        .toList();
    calls.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return calls;
  }

  static String? getCaregiverProfileImage(String userId) {
    final image = _caregiverById[userId]?.profileImage;
    return image != null && image.isNotEmpty ? image : null;
  }

  static int get thisWeekCalls => 3;

  static int get connectedPeople => group.careGiverUserIds.length;

  static String formatDate(DateTime dateTime) {
    final et = TimeUtils.toEt(dateTime);
    return '${et.year}.${_two(et.month)}.${_two(et.day)}';
  }

  static String formatTime(DateTime dateTime) {
    final et = TimeUtils.toEt(dateTime);
    return '${_two(et.hour)}:${_two(et.minute)}';
  }

  static String formatDuration(int? seconds) {
    if (seconds == null) return '';
    final duration = Duration(seconds: seconds);
    final totalMinutes = duration.inMinutes;
    if (totalMinutes < 60) {
      return '${totalMinutes}분';
    }
    final hours = duration.inHours;
    final minutes = totalMinutes % 60;
    if (minutes == 0) {
      return '${hours}시간';
    }
    return '${hours}시간 ${minutes}분';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

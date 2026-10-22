/// 파트너 채팅: Firestore `chats/{pairId}/messages`.
/// pairId는 두 uid를 정렬해 '_'로 이은 값이라 양쪽이 같은 방을 본다.
library;

String chatPairId(String a, String b) => (a.compareTo(b) <= 0) ? '${a}_$b' : '${b}_$a';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.at,
    this.text = '',
    this.emoji = '',
    this.burst = 0,
  });

  final String id;
  final String fromUid;
  final String fromName;
  final DateTime at;
  final String text;

  /// 이모티콘 메시지. [burst]가 1보다 크면 화면에 그만큼 쏟아진다.
  final String emoji;
  final int burst;

  bool get isEmoji => emoji.isNotEmpty;

  factory ChatMessage.fromJson(String id, Map<String, dynamic> j) => ChatMessage(
        id: id,
        fromUid: (j['fromUid'] as String?) ?? '',
        fromName: (j['fromName'] as String?) ?? '',
        at: _ts(j['at']),
        text: (j['text'] as String?) ?? '',
        emoji: (j['emoji'] as String?) ?? '',
        burst: (j['burst'] as num?)?.toInt() ?? 0,
      );

  static DateTime _ts(dynamic v) {
    if (v == null) return DateTime.now();
    try {
      // cloud_firestore Timestamp
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {}
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime.now();
  }
}

/// 루미큐브처럼 고르는 후보 멘트. 상황별로 묶어 둔다.
const chatPresets = <String, List<String>>{
  '약속': ['오늘 헬스장 가자', '몇 시에 갈래?', '나 먼저 가 있을게', '도착했어', '10분 늦어', '오늘은 못 가 ㅠ'],
  '운동 중': ['한 세트만 더', '무게 올리자', '폼 좀 봐줘', '나 지금 죽는다', '스팟 좀', '휴식 끝, 가자'],
  '리액션': ['오늘 컨디션 최고', '하체 하기 싫다', '단백질 먹었냐', '잘했어 👏', '내일은 쉬자', '다음 주도 같이 하자'],
};

/// 이모티콘 폭탄 후보.
const chatEmojis = ['🔥', '💪', '😤', '🥵', '👏', '😂', '🫠', '🏋️', '🍗', '😴'];

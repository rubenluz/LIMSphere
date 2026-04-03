// lab_message.dart - LabMessage data model: message text, author email,
// channel id, timestamp, reply_to reference, context tags; fromMap.

class LabMessage {
  final int id;
  final String? userAuthUid;
  final int? userId;
  final String channel;
  final String? contextType;
  final int? contextId;
  final String body;
  final bool edited;
  final DateTime? editedAt;
  final int? parentId;
  final bool pinned;
  final int? pinnedBy;
  final DateTime createdAt;
  final bool deleted;

  // Populated from a join / local augmentation
  final String? userName;
  final List<LabMessage> replies;

  LabMessage({
    required this.id,
    this.userAuthUid,
    this.userId,
    required this.channel,
    this.contextType,
    this.contextId,
    required this.body,
    this.edited = false,
    this.editedAt,
    this.parentId,
    this.pinned = false,
    this.pinnedBy,
    required this.createdAt,
    this.deleted = false,
    this.userName,
    this.replies = const [],
  });

  factory LabMessage.fromJson(Map<String, dynamic> json) {
    return LabMessage(
      id: json['message_id'] as int,
      userAuthUid: json['message_user_uid'] as String?,
      userId: (json['message_user_id'] ?? json['user_id']) as int?,
      channel: json['message_channel'] as String? ?? 'general',
      contextType: json['message_context_type'] as String?,
      contextId: json['message_context_id'] as int?,
      body: json['message_body'] as String,
      edited: json['message_edited'] as bool? ?? false,
      editedAt: json['message_edited_at'] != null
          ? DateTime.parse(json['message_edited_at'] as String) : null,
      parentId: json['message_parent_id'] as int?,
      pinned: json['message_pinned'] as bool? ?? false,
      pinnedBy: json['message_pinned_by'] as int?,
      createdAt: DateTime.parse(json['message_created_at'] as String),
      deleted: json['message_deleted'] as bool? ?? false,
      userName: json['user_name'] as String?,
    );
  }

  Map<String, dynamic> toInsertMap({
    required String channel,
    String? contextType,
    int? contextId,
    int? parentId,
  }) =>
      {
        'message_body': body,
        'message_channel': channel,
        'message_context_type': ?contextType,
        'message_context_id': ?contextId,
        'message_parent_id': ?parentId,
      };

  LabMessage copyWith({
    String? body,
    bool? edited,
    DateTime? editedAt,
    bool? pinned,
    bool? deleted,
    List<LabMessage>? replies,
  }) =>
      LabMessage(
        id: id,
        userAuthUid: userAuthUid,
        userId: userId,
        channel: channel,
        contextType: contextType,
        contextId: contextId,
        body: body ?? this.body,
        edited: edited ?? this.edited,
        editedAt: editedAt ?? this.editedAt,
        parentId: parentId,
        pinned: pinned ?? this.pinned,
        pinnedBy: pinnedBy,
        createdAt: createdAt,
        deleted: deleted ?? this.deleted,
        userName: userName,
        replies: replies ?? this.replies,
      );

  bool get isTopLevel => parentId == null;
  String get senderKey =>
      userAuthUid ?? (userId?.toString() ?? 'message_$id');
  String get displayName => userName ?? 'Unknown User';
}

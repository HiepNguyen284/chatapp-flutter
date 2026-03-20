import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/attachment_model.dart';
import '../models/message_receive_model.dart';
import '../models/user_with_avatar_model.dart';
import 'app_avatar.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.onLongPress,
    this.deliveryStatus,
    this.seenByUsers = const [],
  });

  final MessageReceiveModel message;
  final bool isMine;
  final VoidCallback onLongPress;
  final String? deliveryStatus;
  final List<UserWithAvatarModel> seenByUsers;

  void _openImageViewer(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenImageView(imageUrl: imageUrl),
      ),
    );
  }

  bool _isImageAttachment(AttachmentModel attachment) {
    if (attachment.type == AttachmentType.image) {
      return true;
    }

    final source = attachment.source?.toLowerCase() ?? '';
    return source.endsWith('.png') ||
        source.endsWith('.jpg') ||
        source.endsWith('.jpeg') ||
        source.endsWith('.gif') ||
        source.endsWith('.webp') ||
        source.endsWith('.bmp') ||
        source.endsWith('.svg') ||
        source.endsWith('.heic') ||
        source.endsWith('.heif');
  }

  @override
  Widget build(BuildContext context) {
    final sentOn = message.sentOn;
    final imageUrls = message.attachments
        .where(_isImageAttachment)
        .map((item) => item.source)
        .whereType<String>()
        .where((source) => source.isNotEmpty)
        .toList();
    final hasText = (message.message ?? '').isNotEmpty;
    final hasVisibleImages = imageUrls.isNotEmpty;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: onLongPress,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
              constraints: const BoxConstraints(maxWidth: 280),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? const Color(0xFF168AFF) : const Color(0xFFE8EBEF),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 6),
                  bottomRight: Radius.circular(isMine ? 6 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (imageUrls.isNotEmpty)
                    ...imageUrls.map(
                      (url) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () => _openImageViewer(context, url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              url,
                              width: 220,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 220,
                                height: 120,
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: Text(
                                  'Cannot load image',
                                  style: TextStyle(
                                    color: isMine ? Colors.white70 : Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (hasText)
                    Text(
                      message.message!,
                      style: TextStyle(
                        color: isMine ? Colors.white : Colors.black87,
                        fontSize: 15,
                        height: 1.25,
                      ),
                    ),
                  if (!hasText && !hasVisibleImages)
                    Text(
                      'Tin nhan da bi xoa',
                      style: TextStyle(
                        color: isMine ? Colors.white70 : Colors.black54,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (sentOn != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      deliveryStatus == null
                          ? DateFormat('HH:mm').format(sentOn)
                          : '${DateFormat('HH:mm').format(sentOn)} • $deliveryStatus',
                      style: TextStyle(
                        color: isMine
                            ? Colors.white.withOpacity(0.85)
                            : Colors.black45,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isMine && seenByUsers.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 14, top: 1),
              height: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final viewer in seenByUsers.take(5))
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: AppAvatar(
                        url: viewer.avatar?.source,
                        name: viewer.username ?? '?',
                        radius: 7,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FullScreenImageView extends StatelessWidget {
  const _FullScreenImageView({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
                'Cannot load image',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

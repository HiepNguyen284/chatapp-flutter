import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.url,
    required this.name,
    this.radius = 24,
    this.showOnlineDot = false,
  });

  final String? url;
  final String name;
  final double radius;
  final bool showOnlineDot;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    Widget avatar;

    if (url == null || url!.isEmpty) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFDCEBFF),
        child: Text(
          initial,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: radius * 0.7,
            color: const Color(0xFF168AFF),
          ),
        ),
      );
    } else {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFDCEBFF),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Text(
              initial,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.7,
                color: const Color(0xFF168AFF),
              ),
            ),
          ),
        ),
      );
    }

    if (!showOnlineDot) {
      return avatar;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: radius * 0.45,
            height: radius * 0.45,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

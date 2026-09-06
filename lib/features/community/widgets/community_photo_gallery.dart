import 'package:flutter/material.dart';

import '../../../core/network/token_storage.dart';
import '../../../shared/models/post.dart';

class CommunityPhotoGallery extends StatelessWidget {
  const CommunityPhotoGallery({super.key, required this.photos});
  final List<CommunityPhoto> photos;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<String?>(
      future: TokenStorage().getToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return AspectRatio(
            aspectRatio: photos.length <= 2 ? 16 / 9 : 1,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final headers = snapshot.data == null
            ? null
            : {'Authorization': 'Bearer ${snapshot.data}'};
        if (photos.length == 1) {
          final photo = photos.first;
          final ratio =
              photo.width != null && photo.height != null && photo.height! > 0
                  ? (photo.width! / photo.height!)
                      .clamp(0.75, 16 / 9)
                      .toDouble()
                  : 16 / 9;
          return AspectRatio(
            aspectRatio: ratio,
            child: _Photo(photo: photo, headers: headers),
          );
        }
        return AspectRatio(
          aspectRatio: photos.length <= 2 ? 16 / 9 : 1,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
            ),
            itemCount: photos.length,
            itemBuilder: (_, index) =>
                _Photo(photo: photos[index], headers: headers),
          ),
        );
      },
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.photo, required this.headers});
  final CommunityPhoto photo;
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          photo.url,
          headers: headers,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const ColoredBox(
            color: Colors.black12,
            child: Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      );
}

import 'dart:typed_data';

import 'package:shimmer/shimmer.dart';
import 'package:skynet/dacs.dart' hide Image;
import 'package:vup/app.dart';

class UserWidget extends StatefulWidget {
  final String userId;
  final bool profilePictureOnly;
  const UserWidget(this.userId, {required this.profilePictureOnly, Key? key})
      : super(key: key);

  @override
  State<UserWidget> createState() => _UserWidgetState();
}

class _UserWidgetState extends State<UserWidget> {
  @override
  void initState() {
    _loadProfile();
    super.initState();
  }

  static Profile? profile;

  void _loadProfile() async {
    // await Future.delayed(Duration(seconds: 10));
    try {
      profile = await mySky.profileDAC.getProfile(widget.userId).timeout(
            const Duration(seconds: 10),
          );
      if (profile == null) throw '';
    } catch (e) {
      profile ??= Profile(
        version: 1,
        username: 'You',
        location: 'Using Vup',
      );
    }
    final avatarUri = profile?.getAvatarUrl() ??
        'sia://CABdyKgcVLkjdsa0HIjBfNicRv0pqU7YL-tgrfCo23DmWw';
    final avatarUrl = mySky.skynetClient.resolveSkylink(
      avatarUri,
    );

    if (globalThumbnailMemoryCache.containsKey(avatarUri)) {
      imageBytes = globalThumbnailMemoryCache[avatarUri];
      return;
    }

    final res = await mySky.skynetClient.httpClient.get(
      Uri.parse(
        avatarUrl!,
      ),
      headers: mySky.skynetClient.headers,
    );
    imageBytes = res.bodyBytes;

    if (mounted) setState(() {});

    globalThumbnailMemoryCache[avatarUri] = imageBytes!;
  }

  Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    if (widget.profilePictureOnly) return buildProfilePicture();
    return Row(
      children: [
        buildProfilePicture(),
        if (profile != null)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile!.username,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    profile!.location ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          )
      ],
    );
  }

  Widget buildProfilePicture() {
    if (imageBytes == null) {
      return SizedBox(
        width: 32,
        height: 32,
        child: Shimmer.fromColors(
          baseColor: Theme.of(context).dividerColor,
          highlightColor: Theme.of(context).dividerColor.withOpacity(0.2),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
        ),
      );
    }
/*     if (imageBytes!.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 32,
          width: 32,
          child: Image.memory(imageBytes!),
        ),
      );
    } */
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 32,
        width: 32,
        child: Image.memory(imageBytes!),
      ),
    );
  }
}

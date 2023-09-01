import 'package:flutter/material.dart';
import 'package:vup/app.dart';
import 'package:vup/widget/file_system_entity.dart';

class GalleryView extends StatefulWidget {
  final List<FileReference> images;
  final int initialIndex;
  const GalleryView({
    required this.images,
    required this.initialIndex,
    Key? key,
  }) : super(key: key);

  @override
  State<GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  int index = 0;
  @override
  void initState() {
    index = widget.initialIndex;
    super.initState();
  }

  FileReference get image => widget.images[index];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            maxScale: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (image.file.thumbnail != null)
                  ThumbnailCoverWidget(
                    thumbnail: image.file.thumbnail!,
                    isSquare: false,
                  ),
                CircularProgressIndicator(),
                // TODO Improve image loading performance

                Image.network(
                  temporaryStreamingServerService.makeFileAvailableLocalhost(
                    image,
                  ),
                  filterQuality: FilterQuality.medium,
                ),
              ],
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: Material(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(4),
                  ),
                  color: Theme.of(context).primaryColor,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      UniconsLine.times,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (index > 0)
            SafeArea(
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      index--;
                    });
                  },
                  child: Material(
                    borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                    color: Theme.of(context).primaryColor,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        UniconsLine.arrow_left,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (index < (widget.images.length - 1))
            SafeArea(
              child: Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      index++;
                    });
                  },
                  child: Material(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomLeft: Radius.circular(4),
                    ),
                    color: Theme.of(context).primaryColor,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        UniconsLine.arrow_right,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

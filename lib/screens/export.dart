import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../media.dart';
import '../widgets.dart';
import '../slide_art.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, required this.project});
  final Slideshow project;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  int _index = 0;
  Timer? _timer;
  bool _busy = false;
  String? _video;

  void _toggle() => setState(() {
    if (_timer != null) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => setState(() {
          _index = (_index + 1) % widget.project.photos.length;
        }),
      );
    }
  });

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _deliver(bool share) async {
    setState(() => _busy = true);
    try {
      final video = _video ??= await _render(widget.project);
      await native.invokeMethod<void>(
        share ? 'shareVideo' : 'saveVideo',
        video,
      );
      if (mounted && !share) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Video saved to Movies')));
      }
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Unable to export video')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to render the slideshow')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final duration = project.photos.length * 2;
    return Workspace(
      layers: [
        SlideArt(
          project,
          project.photos[_index],
          transitionKey: project.transition < 0 ? null : project.photos[_index],
        ),
        for (final item in project.decorations)
          Align(
            alignment: Alignment(
              item.position.dx * 2 - 1,
              item.position.dy * 2 - 1,
            ),
            child: SizedBox(width: 105, child: DecorationText(item)),
          ),
        PlayButton(_timer != null, _toggle),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Header(
            leading: ActionIcon(
              Icons.chevron_left,
              'Back',
              () => Navigator.pop(context),
            ),
            trailing: Pill(
              'Done',
              onTap: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ),
        ),
        Positioned(
          bottom: 5,
          left: 13,
          right: 13,
          child: Row(
            children: [
              Text(slideTime(_index * 2), style: const TextStyle(fontSize: 11)),
              Expanded(
                child: Slider(
                  value: _index.toDouble(),
                  max: math.max(project.photos.length - 1, 1).toDouble(),
                  onChanged: project.photos.length > 1
                      ? (v) => setState(() => _index = v.round())
                      : null,
                ),
              ),
              Text(slideTime(duration), style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ],
      footer: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        scrollDirection: Axis.horizontal,
        children: [
          Center(
            child: Pill(
              _busy ? 'Rendering…' : 'Download',
              onTap: _busy ? null : () => _deliver(false),
            ),
          ),
          const SizedBox(width: 8),
          for (final (label, icon, color) in const [
            ('Facebook', Icons.facebook, Color(0xff1877f2)),
            ('Snapchat', Icons.snapchat, Color(0xfffffc00)),
            ('YouTube', Icons.play_circle_fill, Color(0xffff0808)),
            ('Instagram', Icons.camera_alt_outlined, Color(0xfff20791)),
            ('TikTok', Icons.music_note, Color(0xff282828)),
            ('More', Icons.share, Color(0xff282828)),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: Center(
                child: IconButton.filled(
                  tooltip: 'Share video · $label',
                  onPressed: _busy ? null : () => _deliver(true),
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(43),
                    backgroundColor: color,
                    foregroundColor: label == 'Snapchat'
                        ? Colors.black
                        : Colors.white,
                  ),
                  icon: Icon(icon, size: 21),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<String> _render(Slideshow project) async {
  final id = await native.invokeMethod<String>('beginExport');
  if (id == null) throw StateError('Export directory unavailable');
  final ratio = project.ratio ?? 9 / 16;
  final width = ratio <= 1 ? (640 * ratio / 2).round() * 2 : 640;
  final height = ratio <= 1 ? 640 : (640 / ratio / 2).round() * 2;
  final size = Size(width.toDouble(), height.toDouble());
  try {
    for (final (index, path) in project.photos.indexed) {
      final bytes = await _rasterize(project, path, size);
      await native.invokeMethod<void>('writeFrame', {
        'id': id,
        'index': index,
        'bytes': bytes,
      });
    }
    final result = await native.invokeMethod<String>('encode', {
      'id': id,
      'width': width,
      'height': height,
      'count': project.photos.length,
      'transition': project.transition,
      'intensity': project.intensity,
      'music': project.music,
      'volume': project.volume,
    });
    if (result == null) throw StateError('Encoder returned no output');
    return result;
  } finally {
    await native.invokeMethod<void>('cleanFrames', id);
  }
}

Future<Uint8List> _rasterize(Slideshow project, String path, Size size) async {
  final source = await _loadImage(path);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final bounds = Offset.zero & size;
  canvas.drawRect(bounds, Paint()..color = Colors.black);
  canvas.save();
  canvas.translate(size.width / 2, size.height / 2);
  canvas.rotate(project.rotation * math.pi / 180);
  canvas.translate(-size.width / 2, -size.height / 2);
  final imageSize = Size(source.width.toDouble(), source.height.toDouble());
  final fit = applyBoxFit(BoxFit.cover, imageSize, size);
  canvas.drawImageRect(
    source,
    Alignment.center.inscribe(fit.source, Offset.zero & imageSize),
    bounds,
    Paint()
      ..colorFilter = ColorFilter.matrix(slideColorMatrix(project))
      ..filterQuality = FilterQuality.medium,
  );
  canvas.restore();
  final shade = project.adjustments['Vignette'] ?? .5;
  if (shade > .5) {
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          radius: .78,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: (shade - .5) * 1.6),
          ],
        ).createShader(bounds),
    );
  }
  for (final item in project.decorations) {
    final origin = Offset(
      (size.width - 105) * item.position.dx,
      (size.height - 115) * item.position.dy,
    );
    if (item.sticker && item.text.startsWith('assets/')) {
      final sticker = await _loadImage(item.text);
      final stickerSize = Size(
        sticker.width.toDouble(),
        sticker.height.toDouble(),
      );
      final slot = (origin + const Offset(14.5, 0)) & const Size.square(76);
      final fit = applyBoxFit(BoxFit.contain, stickerSize, slot.size);
      canvas.drawImageRect(
        sticker,
        Offset.zero & stickerSize,
        Alignment.center.inscribe(fit.destination, slot),
        Paint()..filterQuality = FilterQuality.medium,
      );
      sticker.dispose();
      continue;
    }
    final painter = TextPainter(
      text: TextSpan(text: item.text, style: decorationStyle(item)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 5,
      ellipsis: '…',
    )..layout(minWidth: 105, maxWidth: 105);
    painter.paint(canvas, origin);
    painter.dispose();
  }
  final picture = recorder.endRecording();
  final frame = await picture.toImage(size.width.toInt(), size.height.toInt());
  try {
    final data = await frame.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List();
  } finally {
    frame.dispose();
    picture.dispose();
    source.dispose();
  }
}

Future<ui.Image> _loadImage(String path) async {
  final provider = photo(path);
  final completer = Completer<ui.Image>();
  final stream = provider.resolve(const ImageConfiguration());
  final listener = ImageStreamListener((info, _) {
    if (!completer.isCompleted) completer.complete(info.image.clone());
    info.dispose();
  }, onError: (error, stack) => completer.completeError(error, stack));
  stream.addListener(listener);
  try {
    return await completer.future;
  } finally {
    stream.removeListener(listener);
  }
}

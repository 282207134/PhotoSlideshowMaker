import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'media.dart';
import 'widgets.dart';

String slideTime(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

class SlideArt extends StatelessWidget {
  const SlideArt(this.project, this.path, {super.key, this.transitionKey});
  final Slideshow project;
  final String path;
  final String? transitionKey;

  @override
  Widget build(BuildContext context) {
    Widget image = ColorFiltered(
      colorFilter: ColorFilter.matrix(slideColorMatrix(project)),
      child: Picture(path),
    );
    if (project.rotation != 0) {
      image = Transform.rotate(
        angle: project.rotation * math.pi / 180,
        child: image,
      );
    }
    if (project.ratio != null) {
      image = Center(
        child: AspectRatio(
          aspectRatio: project.ratio!,
          child: ClipRect(child: image),
        ),
      );
    }
    final shade = project.adjustments['Vignette'] ?? .5;
    if (shade > .5) {
      image = Stack(
        fit: StackFit.expand,
        children: [
          image,
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: .78,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: (shade - .5) * 1.6),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (transitionKey == null) return image;
    return AnimatedSwitcher(
      duration: Duration(milliseconds: (200 + project.intensity * 550).round()),
      transitionBuilder: (child, animation) => project.transition.isEven
          ? FadeTransition(opacity: animation, child: child)
          : SlideTransition(
              position: Tween(
                begin: const Offset(.25, 0),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
      child: SizedBox.expand(key: ValueKey(transitionKey), child: image),
    );
  }
}

List<double> slideColorMatrix(Slideshow project) {
  final contrast = .6 + (project.adjustments['Contrast'] ?? .5) * .8;
  final light =
      ((project.adjustments['Brightness'] ?? .5) - .5) * 105 +
      ((project.adjustments['Exposure'] ?? .5) - .5) * 85 +
      128 * (1 - contrast);
  final saturation = (project.adjustments['Saturation'] ?? .5) * 2;
  final filter = project.effect + project.preset + 2;
  final tint = filter == 0 ? 0.0 : project.intensity * 28;
  return [
    contrast * (.213 + .787 * saturation),
    contrast * (.715 - .715 * saturation),
    contrast * (.072 - .072 * saturation),
    0,
    light + (filter.isEven ? tint : -tint),
    contrast * (.213 - .213 * saturation),
    contrast * (.715 + .285 * saturation),
    contrast * (.072 - .072 * saturation),
    0,
    light,
    contrast * (.213 - .213 * saturation),
    contrast * (.715 - .715 * saturation),
    contrast * (.072 + .928 * saturation),
    0,
    light + (filter.isOdd ? tint : -tint),
    0,
    0,
    0,
    1,
    0,
  ];
}

class DecorationText extends StatelessWidget {
  const DecorationText(this.item, {super.key});
  final DecorationItem item;
  @override
  Widget build(BuildContext context) =>
      item.sticker && item.text.startsWith('assets/')
      ? Center(
          child: SizedBox.square(
            dimension: 76,
            child: Picture(item.text, fit: BoxFit.contain),
          ),
        )
      : Text(
          item.text,
          textAlign: TextAlign.center,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: decorationStyle(item),
        );
}

TextStyle decorationStyle(DecorationItem item) => TextStyle(
  fontFamily: item.sticker ? null : 'serif',
  fontStyle: item.sticker ? FontStyle.normal : FontStyle.italic,
  fontWeight: FontWeight.w800,
  color: const Color(0xffffe77a),
  fontSize: item.sticker ? 41 : 29,
  height: 1.05,
  shadows: item.sticker
      ? null
      : const [
          Shadow(color: Color(0xffa23bd0), offset: Offset(2, 2), blurRadius: 2),
        ],
);

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'media.dart';

const gold = Color(0xffffb51b);
const ink = Color(0xff101010);

void open(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

class Screen extends StatelessWidget {
  const Screen({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: child,
        ),
      ),
    ),
  );
}

class Picture extends StatelessWidget {
  const Picture(
    this.path, {
    super.key,
    this.radius = 0,
    this.fit = BoxFit.cover,
  });
  final String path;
  final double radius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Image(
      image: photo(path),
      width: double.infinity,
      height: double.infinity,
      fit: fit,
      errorBuilder: (_, _, _) => const ColoredBox(color: ink),
    ),
  );
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => FilledButton(
    style: FilledButton.styleFrom(
      foregroundColor: Colors.black,
      backgroundColor: Colors.white,
      minimumSize: const Size(62, 34),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    onPressed: onTap,
    child: Text(label),
  );
}

class ActionIcon extends StatelessWidget {
  const ActionIcon(
    this.icon,
    this.label,
    this.onTap, {
    super.key,
    this.color = Colors.white,
    this.size = 22,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    color: color,
    iconSize: size,
    onPressed: onTap,
    icon: Icon(icon),
  );
}

class Header extends StatelessWidget {
  const Header({super.key, this.title = '', this.leading, this.trailing});
  final String title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 58,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        if (leading != null) Positioned(left: 3, child: leading!),
        if (trailing != null) Positioned(right: 14, child: trailing!),
      ],
    ),
  );
}

class Workspace extends StatelessWidget {
  const Workspace({super.key, required this.layers, required this.footer});
  final List<Widget> layers;
  final Widget footer;

  @override
  Widget build(BuildContext context) => Screen(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(fit: StackFit.expand, children: layers),
            ),
          ),
          SizedBox(height: 66, child: footer),
        ],
      ),
    ),
  );
}

class Rail extends StatelessWidget {
  const Rail(this.labels, this.icons, this.active, this.onTap, {super.key});
  final List<String> labels;
  final List<IconData> icons;
  final int active;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Positioned(
    top: 56,
    right: 2,
    bottom: 0,
    width: 56,
    child: Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        child: Column(
          children: List.generate(labels.length, (index) {
            final selected = index == active;
            return Semantics(
              button: true,
              selected: selected,
              label: labels[index],
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(index),
                child: SizedBox(
                  width: 56,
                  height: 49,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 33,
                        height: 33,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? Colors.white : Colors.black26,
                          border: selected
                              ? Border.all(color: gold, width: 2)
                              : null,
                        ),
                        child: Icon(
                          icons[index],
                          color: selected ? Colors.black : Colors.white,
                          size: 20,
                        ),
                      ),
                      Text(
                        labels[index],
                        style: const TextStyle(fontSize: 8, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );
}

class PlayButton extends StatelessWidget {
  const PlayButton(this.playing, this.onTap, {super.key});
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Center(
    child: IconButton.filled(
      tooltip: playing ? 'Pause' : 'Play',
      onPressed: onTap,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(76),
        backgroundColor: const Color(0xe6000000),
        foregroundColor: Colors.white,
      ),
      icon: Icon(
        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        size: 33,
      ),
    ),
  );
}

class Timeline extends StatelessWidget {
  const Timeline(
    this.photos,
    this.active,
    this.onTap, {
    super.key,
    this.onGrid,
  });
  final List<String> photos;
  final int active;
  final ValueChanged<int> onTap;
  final VoidCallback? onGrid;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox(width: 10),
      Expanded(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 15),
          itemCount: photos.length,
          separatorBuilder: (_, _) => const SizedBox(width: 3),
          itemBuilder: (_, i) => Semantics(
            button: true,
            label: 'Slide ${i + 1}',
            selected: i == active,
            child: GestureDetector(
              onTap: () => onTap(i),
              child: SizedBox(
                width: 36,
                child: Opacity(
                  opacity: i == active ? 1 : .48,
                  child: Picture(photos[i], radius: 5),
                ),
              ),
            ),
          ),
        ),
      ),
      if (onGrid != null)
        ActionIcon(Icons.grid_view_rounded, 'Add or arrange photos', onGrid),
    ],
  );
}

class ValueSlider extends StatelessWidget {
  const ValueSlider(
    this.value,
    this.onChange, {
    super.key,
    this.centered = false,
    this.label,
  });
  final double value;
  final ValueChanged<double> onChange;
  final bool centered;
  final String? label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black87,
            border: Border.all(color: gold),
          ),
          child: Text(
            label ?? '${(value * 100).round()}',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Row(
          children: [
            ActionIcon(
              Icons.block,
              'Reset value',
              () => onChange(centered ? .5 : 0),
              size: 19,
            ),
            Expanded(
              child: Container(
                height: 29,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: CustomPaint(
                  painter: const _Ticks(),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                      thumbColor: Colors.white,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5,
                      ),
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(value: value, onChanged: onChange),
                  ),
                ),
              ),
            ),
            ActionIcon(
              Icons.tune,
              'Maximum value',
              () => onChange(1),
              size: 19,
            ),
          ],
        ),
      ],
    ),
  );
}

class _Ticks extends CustomPainter {
  const _Ticks();
  @override
  void paint(Canvas canvas, Size size) {
    final brush = Paint()..color = Colors.white30;
    for (var i = 0; i <= 48; i++) {
      final x = 8 + i * (size.width - 16) / 48;
      final h = i % 6 == 0 ? 7.0 : 3.0;
      canvas.drawLine(
        Offset(x, size.height / 2 - h),
        Offset(x, size.height / 2 + h),
        brush,
      );
    }
  }

  @override
  bool shouldRepaint(_Ticks oldDelegate) => false;
}

class Waveform extends StatelessWidget {
  const Waveform({super.key, this.progress = .42, this.height = 55});
  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: height,
    child: CustomPaint(painter: _WavePainter(progress)),
  );
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(21);
    final brush = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var x = 2.0; x < size.width; x += 5) {
      final h = size.height * (.10 + random.nextDouble() * .36);
      brush.color = x / size.width < progress ? gold : Colors.white70;
      canvas.drawLine(
        Offset(x, size.height / 2 - h),
        Offset(x, size.height / 2 + h),
        brush,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      progress != oldDelegate.progress;
}

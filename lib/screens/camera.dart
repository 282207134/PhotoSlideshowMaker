import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../media.dart';
import '../widgets.dart';

const _modes = ['Effect', 'Boomerang', 'Collage', 'Slideshow', 'Slowmo'];
const _icons = [
  Icons.auto_awesome,
  Icons.all_inclusive,
  Icons.grid_view,
  Icons.motion_photos_on,
  Icons.slow_motion_video,
];
const _examples = [6, 8, 11, 14, 17];
const _slots = [1, 2, 3, 4];

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.onEdit});
  final ValueChanged<Iterable<String>> onEdit;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  int _mode = 0;
  int _effect = -1;
  int _layout = 0;
  int _category = 0;
  int _countdown = 0;
  int _seconds = 0;
  bool _grid = false;
  bool _flash = false;
  bool _fine = false;
  bool _busy = false;
  double _amount = .6;
  Timer? _timer;
  final _shots = <String>[];

  String get _image => scene(_examples[_mode]);

  Future<void> _device(String method) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final paths = await native.invokeListMethod<String>(method) ?? [];
      if (mounted && paths.isNotEmpty) setState(() => _shots.addAll(paths));
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Media unavailable')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _capture() {
    if (_busy || _seconds > 0) return;
    if (_countdown == 0) {
      _takeSample();
      return;
    }
    setState(() => _seconds = _countdown);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _seconds--);
      if (_seconds == 0) {
        timer.cancel();
        _takeSample();
      }
    });
  }

  void _takeSample() {
    setState(() {
      if (_mode == 2 && _shots.length >= _slots[_layout]) {
        _shots.clear();
      }
      _shots.add(switch (_mode) {
        2 when _layout > 0 => asset('collage${_shots.length}'),
        3 when _shots.isNotEmpty => scene(
          _examples[_shots.length % _examples.length],
        ),
        _ => _image,
      });
    });
    if (_mode != 2 && _mode != 3) widget.onEdit(List.of(_shots));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _modeChanged(int mode) => setState(() {
    _timer?.cancel();
    _seconds = 0;
    _mode = mode;
    _effect = -1;
    _fine = false;
    _layout = 0;
    _shots.clear();
  });

  Widget _preview() {
    if (_mode != 2 || _layout == 0) return Picture(_shots.lastOrNull ?? _image);
    final slots = _slots[_layout];
    return Column(
      children: [
        for (var row = 0; row < (slots + 1) ~/ 2; row++)
          Expanded(
            child: Row(
              children: [
                for (
                  var column = 0;
                  column < 2 && row * 2 + column < slots;
                  column++
                )
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white38, width: .5),
                      ),
                      child: row * 2 + column < _shots.length
                          ? Picture(_shots[row * 2 + column])
                          : row == 0 && column == 0
                          ? Picture(asset('collage0'))
                          : const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCollection = _mode == 2 || _mode == 3;
    return Workspace(
      layers: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            _effect < 0
                ? Colors.transparent
                : [
                    Colors.amber,
                    Colors.pinkAccent,
                    Colors.lightBlue,
                    Colors.green,
                  ][(_effect + _category) % 4].withValues(alpha: _amount * .35),
            BlendMode.softLight,
          ),
          child: _preview(),
        ),
        if (_grid)
          const IgnorePointer(child: CustomPaint(painter: _GridPainter())),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ActionIcon(
                _flash ? Icons.flash_on : Icons.flash_off,
                'Flash preview',
                () => setState(() => _flash = !_flash),
                color: _flash ? gold : Colors.white,
              ),
              ActionIcon(
                Icons.grid_on,
                'Grid',
                () => setState(() => _grid = !_grid),
                color: _grid ? gold : Colors.white,
              ),
              ActionIcon(
                Icons.timer_outlined,
                'Timer',
                () => setState(() => _countdown = _countdown == 0 ? 3 : 0),
                color: _countdown > 0 ? gold : Colors.white,
              ),
              ActionIcon(Icons.close, 'Close', () => Navigator.pop(context)),
            ],
          ),
        ),
        Rail(_modes, _icons, _mode, _modeChanged),
        if (_seconds > 0)
          Center(
            child: Text(
              '$_seconds',
              style: const TextStyle(
                fontSize: 58,
                shadows: [Shadow(blurRadius: 12)],
              ),
            ),
          ),
        if (_fine)
          Positioned(
            left: 0,
            right: 0,
            bottom: 73,
            child: ValueSlider(_amount, (v) => setState(() => _amount = v)),
          ),
        Positioned(
          left: 2,
          right: 2,
          bottom: 10,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = -2; i <= 2; i++)
                if (i == 0)
                  Semantics(
                    button: true,
                    label: 'Capture sample',
                    child: GestureDetector(
                      onTap: _capture,
                      onLongPress: () => _device('capturePhoto'),
                      child: Container(
                        width: 68,
                        height: 68,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: ClipOval(
                          child: _effect >= 0
                              ? Picture(effectTile(_effect))
                              : ColoredBox(
                                  color: Colors.white,
                                  child: Icon(
                                    _mode == 1
                                        ? Icons.all_inclusive
                                        : _mode == 2
                                        ? Icons.grid_view
                                        : Icons.circle,
                                    color: _mode == 0 || _mode >= 3
                                        ? Colors.white
                                        : Colors.black,
                                    size: 30,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  )
                else
                  Opacity(
                    opacity: _effect < 0 && i < 0 ? 0 : 1,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _effect = (_effect + i + 19) % 19;
                        _fine = true;
                      }),
                      child: Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white70),
                        ),
                        child: ClipOval(
                          child: Picture(
                            effectTile(_effect + i + _category * 3 + 19),
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
      footer: Row(
        children: [
          ActionIcon(
            Icons.cameraswitch_outlined,
            'Open device camera',
            _busy ? null : () => _device('capturePhoto'),
          ),
          Expanded(
            child: _mode == 2
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final (i, icon) in [
                        Icons.crop_square,
                        Icons.view_column_outlined,
                        Icons.grid_view_outlined,
                        Icons.table_chart_outlined,
                      ].indexed)
                        ActionIcon(
                          icon,
                          'Layout ${i + 1}',
                          () => setState(() => _layout = i),
                          color: _layout == i ? gold : Colors.white70,
                          size: 19,
                        ),
                    ],
                  )
                : _mode == 3 && _shots.isNotEmpty
                ? Timeline(
                    _shots,
                    _shots.length - 1,
                    (i) => setState(() => _shots.removeAt(i)),
                  )
                : _mode == 3
                ? const SizedBox()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (final (i, label) in [
                        'NORMAL',
                        'MARU',
                        'KOREAN',
                      ].indexed)
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                          ),
                          onPressed: () => setState(() {
                            _category = i;
                            _effect = i == 0 ? -1 : i * 3;
                            _fine = i != 0;
                          }),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 9,
                              color: _category == i ? gold : Colors.white54,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          if (isCollection && (_shots.isNotEmpty || _mode == 3))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Pill(
                'Done',
                onTap: () =>
                    widget.onEdit(_shots.isEmpty ? [_image] : List.of(_shots)),
              ),
            )
          else
            ActionIcon(
              Icons.photo_library_outlined,
              'Import photos',
              _busy ? null : () => _device('pickPhotos'),
            ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white30
      ..strokeWidth = .7;
    for (final fraction in [1 / 3, 2 / 3]) {
      final x = size.width * fraction;
      final y = size.height * fraction;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

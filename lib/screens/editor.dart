import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../media.dart';
import '../widgets.dart';
import '../slide_art.dart';
import 'export.dart';

const _labels = [
  'Adjust',
  'Effect',
  'Preset',
  'Transition',
  'Music',
  'Sticker',
  'Text',
  'Canvas',
];
const _icons = [
  Icons.tune,
  Icons.auto_awesome,
  Icons.filter_vintage,
  Icons.flash_on,
  Icons.music_note,
  Icons.emoji_emotions,
  Icons.text_fields,
  Icons.crop,
];
const _examples = [19, 22, 24, 26, 29, 31, 34, 38];
const _categories = ['TRENDS', 'MARU', 'KOREAN', 'SPRING', 'SUMMER'];
const _stickerCount = 12;
const _textStyles = [
  "let’s fall in love",
  'GOOD VIBES',
  'FEEL THE DEAL',
  'EAT CAKE',
  'MAKE A WISH',
];
const _textColors = [
  Color(0xff07cad7),
  Color(0xfffa4fa1),
  Color(0xff69356d),
  Color(0xfff1b731),
  Color(0xff62c2f7),
];
const _ratios = ['9:16', '16:9', '3:4', '4:3', '1:1'];
const _ratioValues = [9 / 16, 16 / 9, 3 / 4, 4 / 3, 1.0];
const _adjustments = [
  'Exposure',
  'Contrast',
  'Brightness',
  'Saturation',
  'Vignette',
];
const _adjustIcons = [
  Icons.tonality,
  Icons.texture,
  Icons.wb_sunny,
  Icons.contrast,
  Icons.lens_blur,
];
const _tracks = [
  ('Love Runs Out', 'Martin Garrix, G-Eazy'),
  ('Love Runs Out', 'Martin Garrix, G-Eazy'),
  ('Classic Song', 'Ben'),
  ('Good Without', 'Mimi Webb'),
  ('Avalanche', 'James Arthur'),
  ('Pick Up Your Feelings', 'Slideshow'),
  ('INDUSTRY BABY', 'Lil Nas X, Jack Harlow'),
  ('Love Love Love', 'Slideshow'),
];

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.project, required this.onSave});
  final Slideshow project;
  final ValueChanged<Slideshow> onSave;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  Slideshow get project => widget.project;
  List<String> get _photos =>
      project.demo ? _examples.map(scene).toList() : project.photos;
  String get _image =>
      project.demo && !_manualSlide ? scene(_examples[_tool]) : _photos[_index];

  int _tool = 0;
  int _index = 0;
  int _category = 0;
  int _adjust = -1;
  bool _manualSlide = false;
  bool _detail = false;
  bool _rotate = false;
  DecorationItem? _selected;
  Timer? _timer;

  void _stop() {
    if (_timer != null && project.music != null) _audio('stopAudio');
    _timer?.cancel();
    _timer = null;
  }

  void _audio(String method, [Object? arguments]) => unawaited(
    native.invokeMethod<void>(method, arguments).catchError((Object _) {}),
  );

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _play() => setState(() {
    if (_timer != null) {
      _stop();
      return;
    }
    _manualSlide = true;
    if (project.music != null) {
      _audio('previewAudio', {
        'source': project.music,
        'volume': project.volume,
      });
    }
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      setState(() => _index = (_index + 1) % _photos.length);
    });
  });

  void _selectTool(int index) {
    setState(() {
      _tool = index;
      _category = 0;
      _detail = false;
      _selected = null;
    });
    if (index == 4 && project.music == null) unawaited(_music());
  }

  Future<void> _music() async {
    setState(_stop);
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => MusicScreen(backdrop: _image)),
    );
    if (mounted && result != null) setState(() => project.music = result);
  }

  Future<void> _text({DecorationItem? item, String initial = ''}) async {
    var value = item?.text ?? initial;
    setState(_stop);
    final result = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xe61c171e),
        title: const Text('Edit text'),
        content: TextFormField(
          initialValue: value,
          autofocus: true,
          minLines: 1,
          maxLines: 4,
          onChanged: (text) => value = text,
          onFieldSubmitted: (text) => Navigator.pop(dialog, text.trim()),
        ),
        actions: [
          Pill('Done', onTap: () => Navigator.pop(dialog, value.trim())),
        ],
      ),
    );
    if (!mounted || result == null || result.isEmpty) return;
    setState(() {
      if (item == null) {
        project.decorations.add(
          DecorationItem(result, const Offset(.37, .60), sticker: false),
        );
      } else {
        item.text = result;
      }
    });
  }

  void _timeline() {
    setState(_stop);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ink,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 340,
          child: StatefulBuilder(
            builder: (context, update) => Column(
              children: [
                const Text(
                  'Timeline',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: _photos.length,
                    onReorder: (from, to) {
                      if (project.demo) return;
                      if (to > from) to--;
                      setState(() {
                        project.photos.insert(
                          to,
                          project.photos.removeAt(from),
                        );
                        _index = 0;
                      });
                      update(() {});
                    },
                    itemBuilder: (_, i) => ListTile(
                      key: ValueKey(i),
                      leading: SizedBox.square(
                        dimension: 38,
                        child: Picture(_photos[i], radius: 5),
                      ),
                      title: Text('Slide ${i + 1}'),
                      trailing: project.demo || _photos.length == 1
                          ? null
                          : ActionIcon(
                              Icons.delete_outline,
                              'Remove slide',
                              () {
                                setState(() {
                                  project.photos.removeAt(i);
                                  _index = 0;
                                });
                                update(() {});
                              },
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _done() {
    setState(_stop);
    if (project.demo) project.photos.addAll(_photos);
    widget.onSave(project);
    open(context, ExportScreen(project: project));
  }

  Widget _panel() {
    switch (_tool) {
      case 0:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_adjust >= 0)
              ValueSlider(project.adjustments[_adjustments[_adjust]] ?? .5, (
                v,
              ) {
                setState(() => project.adjustments[_adjustments[_adjust]] = v);
              }, centered: true),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final (i, icon) in _adjustIcons.indexed)
                  IconButton.filled(
                    tooltip: _adjustments[i],
                    onPressed: () =>
                        setState(() => _adjust = _adjust == i ? -1 : i),
                    style: IconButton.styleFrom(
                      backgroundColor: _adjust == i ? Colors.black87 : gold,
                    ),
                    icon: Icon(icon, color: Colors.white, size: 19),
                  ),
              ],
            ),
            if (_adjust < 0)
              SizedBox(
                height: 32,
                child: Slider(
                  value: project.adjustments['Exposure'] ?? .5,
                  onChanged: (v) =>
                      setState(() => project.adjustments['Exposure'] = v),
                ),
              ),
          ],
        );
      case 4:
        return project.music == null
            ? const SizedBox.shrink()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_detail)
                    ValueSlider(project.volume, (v) {
                      setState(() => project.volume = v);
                      unawaited(native.invokeMethod<void>('volume', v));
                    }),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ActionIcon(
                        Icons.library_music_outlined,
                        'Choose music',
                        _music,
                      ),
                      ActionIcon(
                        Icons.volume_up_outlined,
                        'Volume',
                        () => setState(() => _detail = !_detail),
                      ),
                      ActionIcon(
                        Icons.delete_outline,
                        'Remove music',
                        () => setState(() => project.music = null),
                      ),
                    ],
                  ),
                  const Waveform(),
                ],
              );
      case 7:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_rotate)
              ValueSlider(
                (project.rotation + 180) / 360,
                (v) {
                  setState(() => project.rotation = v * 360 - 180);
                },
                centered: true,
                label: '${project.rotation.round()}°',
              )
            else
              _strip(
                _ratios.length,
                (i) => _Option(
                  selected: project.ratio == _ratioValues[i],
                  onTap: () => setState(() => project.ratio = _ratioValues[i]),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.crop_square_rounded, size: 26),
                      Text(_ratios[i], style: const TextStyle(fontSize: 8)),
                    ],
                  ),
                ),
              ),
            _tabs(
              ['RATIO', 'ROTATE'],
              _rotate ? 1 : 0,
              (i) => setState(() => _rotate = i == 1),
            ),
          ],
        );
      default:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_detail && _tool <= 3)
              ValueSlider(
                project.intensity,
                (v) => setState(() => project.intensity = v),
              ),
            if (_tool == 5)
              _strip(
                6,
                (i) => Column(
                  children: [
                    for (var row = 0; row < 2; row++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _Option(
                          extent: 46,
                          onTap: () {
                            final item = DecorationItem(
                              asset(
                                'sticker${(row * 6 + i + _category) % _stickerCount}',
                              ),
                              Offset(.22 + i * .1, row == 0 ? .22 : .60),
                              sticker: true,
                            );
                            setState(() {
                              project.decorations.add(item);
                              _selected = null;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Picture(
                              asset(
                                'sticker${(row * 6 + i + _category) % _stickerCount}',
                              ),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                height: 101,
              )
            else
              _strip(_tool == 6 ? _textStyles.length + 1 : 9, _tile),
            _tabs(
              _categories,
              _category,
              (i) => setState(() => _category = i),
              onSearch: _search,
            ),
          ],
        );
    }
  }

  Widget _tile(int i) {
    final selected = switch (_tool) {
      1 => project.effect == i,
      2 => project.preset == i,
      3 => project.transition == i,
      _ => false,
    };
    return _Option(
      selected: selected,
      circular: _tool == 1,
      onTap: () {
        if (_tool == 6) {
          unawaited(
            _text(initial: i == _textStyles.length ? '' : _textStyles[i]),
          );
          return;
        }
        setState(() {
          switch (_tool) {
            case 1:
              project.effect = i;
            case 2:
              project.preset = i;
            case 3:
              project.transition = i;
          }
          _detail = true;
        });
      },
      child: switch (_tool) {
        1 => Picture(effectTile(i + _category * 3)),
        2 => Stack(
          fit: StackFit.expand,
          children: [
            Picture(gallery(1, 9)[(i + _category) % 9]),
            Align(
              alignment: Alignment.topCenter,
              child: Text(
                ['MARU', 'DAZED', 'MUSE'][i % 3],
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  backgroundColor: Colors.black45,
                ),
              ),
            ),
          ],
        ),
        3 => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              [
                Icons.view_column,
                Icons.crop_square,
                Icons.call_split,
                Icons.flip,
                Icons.blur_on,
              ][i % 5],
              size: 23,
            ),
            Text('A${i + 1}', style: const TextStyle(fontSize: 8)),
          ],
        ),
        _ =>
          i == _textStyles.length
              ? const Icon(Icons.add)
              : ColoredBox(
                  color: _textColors[i],
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Text(
                        _textStyles[i],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: .95,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
      },
    );
  }

  void _search() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search categories',
                  ),
                  onSubmitted: (term) {
                    final index = _categories.indexWhere(
                      (item) => item.toLowerCase().contains(term.toLowerCase()),
                    );
                    if (index >= 0) setState(() => _category = index);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final focused = _selected != null;
    return Workspace(
      layers: [
        GestureDetector(
          onTap: focused ? () => setState(() => _selected = null) : null,
          child: SlideArt(
            project,
            _image,
            transitionKey: project.transition < 0 ? null : _image,
          ),
        ),
        if (!focused) PlayButton(_timer != null, _play),
        if (!focused)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Header(
              title:
                  '${slideTime(_index * 2)}  ${slideTime(_photos.length * 2)}',
              leading: ActionIcon(
                Icons.close,
                'Close',
                () => Navigator.pop(context),
              ),
              trailing: Pill('Done', onTap: _done),
            ),
          ),
        if (!focused) Rail(_labels, _icons, _tool, _selectTool),
        if (!focused) Positioned(left: 0, right: 0, bottom: 0, child: _panel()),
        LayoutBuilder(
          builder: (context, bounds) => Stack(
            children: [
              for (final item in project.decorations)
                Positioned(
                  left: (bounds.maxWidth - 105) * item.position.dx,
                  top: (bounds.maxHeight - 115) * item.position.dy,
                  width: 105,
                  child: GestureDetector(
                    onTap: () => setState(() => _selected = item),
                    onDoubleTap: item.sticker ? null : () => _text(item: item),
                    onPanUpdate: (drag) => setState(() {
                      _selected = item;
                      item.position = Offset(
                        (item.position.dx +
                                drag.delta.dx /
                                    math.max(bounds.maxWidth - 105, 1))
                            .clamp(0, 1),
                        (item.position.dy +
                                drag.delta.dy /
                                    math.max(bounds.maxHeight - 115, 1))
                            .clamp(0, 1),
                      );
                    }),
                    child: DecorationText(item),
                  ),
                ),
            ],
          ),
        ),
        if (focused)
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_selected!.sticker)
                  ActionIcon(
                    Icons.edit,
                    'Edit text',
                    () => _text(item: _selected),
                  ),
                ActionIcon(
                  Icons.delete_outline,
                  'Delete overlay',
                  () => setState(() {
                    project.decorations.remove(_selected);
                    _selected = null;
                  }),
                ),
                ActionIcon(
                  Icons.check,
                  'Done editing overlay',
                  () => setState(() => _selected = null),
                ),
              ],
            ),
          ),
      ],
      footer: _tool == 4 && project.music != null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: Row(
                children: [
                  ActionIcon(Icons.music_note, 'Music library', _music),
                  Expanded(
                    child: Text(
                      project.music!.split('/').last,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Text(slideTime(_index * 2)),
                ],
              ),
            )
          : Timeline(
              _photos,
              _index,
              (i) => setState(() {
                _manualSlide = true;
                _index = i;
              }),
              onGrid: _timeline,
            ),
    );
  }
}

Widget _strip(int count, Widget Function(int) builder, {double height = 65}) =>
    SizedBox(
      height: height,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, index) => Center(child: builder(index)),
      ),
    );

Widget _tabs(
  List<String> labels,
  int active,
  ValueChanged<int> onTap, {
  VoidCallback? onSearch,
}) => Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    for (final (i, label) in labels.indexed)
      Flexible(
        child: TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 33),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => onTap(i),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              color: active == i ? gold : Colors.white,
            ),
          ),
        ),
      ),
    if (onSearch != null)
      ActionIcon(Icons.search, 'Search', onSearch, size: 18),
  ],
);

class _Option extends StatelessWidget {
  const _Option({
    required this.child,
    required this.onTap,
    this.selected = false,
    this.circular = false,
    this.extent = 57,
  });
  final Widget child;
  final VoidCallback onTap;
  final bool selected;
  final bool circular;
  final double extent;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: extent,
      height: extent,
      padding: EdgeInsets.all(selected ? 2 : 0),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(circular ? 50 : 13),
        border: selected ? Border.all(color: gold, width: 2) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(circular ? 50 : 11),
        child: child,
      ),
    ),
  );
}

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key, required this.backdrop});
  final String backdrop;

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  int _tab = 0;
  int _active = -1;
  String _query = '';
  String? _imported;
  bool _searching = false;

  @override
  void dispose() {
    unawaited(native.invokeMethod<void>('stopAudio').catchError((Object _) {}));
    super.dispose();
  }

  Future<void> _import() async {
    try {
      final path = await native.invokeMethod<String>('pickAudio');
      if (mounted && path != null) {
        setState(() {
          _imported = path;
          _tab = 1;
          _active = -1;
        });
      }
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unable to import audio')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracks = _tab == 0
        ? _tracks
        : _tab == 1 && _imported != null
        ? [(_imported!.split('/').last, 'On this device')]
        : <(String, String)>[];
    return Workspace(
      layers: [
        Picture(widget.backdrop),
        const ColoredBox(color: Color(0xe6000000)),
        Column(
          children: [
            Header(
              title: 'Music',
              leading: ActionIcon(
                Icons.chevron_left,
                'Back',
                () => Navigator.pop(context),
              ),
              trailing: _tab == 1
                  ? ActionIcon(Icons.add, 'Import audio', _import)
                  : null,
            ),
            if (_searching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  autofocus: true,
                  onChanged: (query) => setState(() => _query = query),
                  decoration: const InputDecoration(hintText: 'Search music'),
                ),
              ),
            Expanded(
              child: tracks.isEmpty
                  ? Center(
                      child: _tab == 1
                          ? Pill('Import Audio', onTap: _import)
                          : const Text(
                              'Apple Music unavailable',
                              style: TextStyle(color: Colors.white54),
                            ),
                    )
                  : ListView(
                      children: [
                        for (final (i, (name, artist)) in tracks.indexed)
                          if (name.toLowerCase().contains(_query.toLowerCase()))
                            Column(
                              children: [
                                ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                  ),
                                  leading: GestureDetector(
                                    onTap: () => _preview(i),
                                    child: SizedBox.square(
                                      dimension: 40,
                                      child: Picture(
                                        effectTile(i + 4),
                                        radius: 8,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '$artist • 00:45',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white54,
                                    ),
                                  ),
                                  onTap: () => _preview(i),
                                  trailing: _active == i
                                      ? Pill(
                                          'Use',
                                          onTap: () => Navigator.pop(
                                            context,
                                            _tab == 1 ? _imported : name,
                                          ),
                                        )
                                      : ActionIcon(
                                          Icons.play_circle_outline,
                                          'Preview $name',
                                          () => _preview(i),
                                          size: 18,
                                        ),
                                ),
                                if (_active == i)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 15,
                                    ),
                                    child: Waveform(height: 39),
                                  ),
                              ],
                            ),
                      ],
                    ),
            ),
          ],
        ),
      ],
      footer: _tabs(
        ['TRENDS', 'MY MUSIC', 'APPLE MUSIC'],
        _tab,
        (i) {
          unawaited(native.invokeMethod<void>('stopAudio'));
          setState(() {
            _tab = i;
            _active = -1;
          });
        },
        onSearch: () => setState(() {
          _searching = !_searching;
          _query = '';
        }),
      ),
    );
  }

  void _preview(int i) {
    final stop = _active == i;
    setState(() => _active = stop ? -1 : i);
    unawaited(
      native
          .invokeMethod<void>(
            stop ? 'stopAudio' : 'previewAudio',
            _tab == 1 ? _imported : i,
          )
          .catchError((Object _) {}),
    );
  }
}

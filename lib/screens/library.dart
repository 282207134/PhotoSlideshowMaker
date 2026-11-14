import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../media.dart';
import '../widgets.dart';
import 'camera.dart';
import 'editor.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _projects = <Slideshow>[];
  var _projectTab = false;

  @override
  void initState() {
    super.initState();
    ProjectStore.load()
        .then((projects) {
          if (mounted) setState(() => _projects.insertAll(0, projects));
        })
        .catchError((Object _) {});
  }

  void _save(Slideshow project) {
    setState(() {
      _projects.remove(project);
      _projects.insert(0, project);
    });
    unawaited(ProjectStore.save(_projects));
  }

  void _edit(Iterable<String> photos, {double? ratio}) {
    final project = Slideshow(photos)..ratio = ratio;
    open(context, EditorScreen(project: project, onSave: _save));
  }

  void _album({bool template = false}) => open(
    context,
    AlbumScreen(
      onStart: (photos) {
        if (template) {
          open(
            context,
            PreviewScreen(
              photos: photos,
              onEdit: (slides, ratio) => _edit(slides, ratio: ratio),
            ),
          );
        } else {
          _edit(photos);
        }
      },
    ),
  );

  void _template(int index) => open(
    context,
    TemplateScreen(
      image: index == 1 ? scene(3) : gallery(0, 9)[index],
      onUse: () => _album(template: true),
    ),
  );

  void _camera() => open(context, CameraScreen(onEdit: _edit));

  @override
  Widget build(BuildContext context) {
    return Screen(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_projectTab)
            Padding(
              padding: const EdgeInsets.only(top: 62),
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 96),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 13,
                  childAspectRatio: .58,
                ),
                itemCount: _projects.length + 4,
                itemBuilder: (_, i) {
                  final project = i < _projects.length ? _projects[i] : null;
                  final sample = gallery(
                    2,
                    4,
                  )[(i - _projects.length).clamp(0, 3)];
                  return GestureDetector(
                    onTap: () => open(
                      context,
                      EditorScreen(
                        project:
                            project ??
                            Slideshow(i == _projects.length ? [] : [sample]),
                        onSave: _save,
                      ),
                    ),
                    child: Picture(
                      project?.photos.firstOrNull ?? sample,
                      radius: 13,
                    ),
                  );
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final width = bounds.maxWidth;
                  final tile = width * .443;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 95),
                    child: Column(
                      children: List.generate(
                        3,
                        (row) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: SizedBox(
                            height: tile * 1.746,
                            width: width,
                            child: ClipRect(
                              child: OverflowBox(
                                maxWidth: tile * 3 + 28,
                                minWidth: tile * 3 + 28,
                                child: SizedBox(
                                  height: tile * 1.746,
                                  child: Row(
                                    children: List.generate(3, (column) {
                                      final i = row * 3 + column;
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          right: column == 2 ? 0 : 14,
                                        ),
                                        child: SizedBox(
                                          width: tile,
                                          child: GestureDetector(
                                            onTap: () => _template(i),
                                            child: Picture(
                                              gallery(0, 9)[i],
                                              radius: 14,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          Align(
            alignment: Alignment.topCenter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: .73),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Header(
                title: _projectTab ? 'My Project' : 'Hot Template',
                leading: _projectTab
                    ? null
                    : ActionIcon(Icons.camera_alt_outlined, 'Camera', _camera),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 25, 30, 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _HomeButton(
                      Icons.play_circle_fill,
                      'Templates',
                      !_projectTab,
                      () => setState(() => _projectTab = false),
                    ),
                    _HomeButton(
                      Icons.add,
                      'Create',
                      false,
                      _create,
                      large: true,
                    ),
                    _HomeButton(
                      Icons.person,
                      'My Project',
                      _projectTab,
                      () => setState(() => _projectTab = true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _create() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ink,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (icon, label, action) in [
              (Icons.photo_library_outlined, 'Album', () => _album()),
              (Icons.camera_alt_outlined, 'Camera', _camera),
              (
                Icons.grid_view_rounded,
                'Collage',
                () => open(
                  context,
                  CollageScreen(onAdd: () => _album(), onEdit: _edit),
                ),
              ),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () {
                  Navigator.pop(sheet);
                  action();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  const _HomeButton(
    this.icon,
    this.label,
    this.selected,
    this.onTap, {
    this.large = false,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(selected ? 3 : 0),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: selected ? gold : Colors.transparent, width: 2),
    ),
    child: IconButton(
      tooltip: label,
      onPressed: onTap,
      style: IconButton.styleFrom(
        fixedSize: Size.square(large ? 76 : 49),
        backgroundColor: large ? Colors.black : Colors.white,
        foregroundColor: large ? Colors.white : Colors.black,
        side: large ? const BorderSide(color: Colors.white, width: 7) : null,
      ),
      icon: Icon(icon, size: large ? 34 : 26),
    ),
  );
}

class CollageScreen extends StatelessWidget {
  const CollageScreen({super.key, required this.onAdd, required this.onEdit});
  final VoidCallback onAdd;
  final ValueChanged<Iterable<String>> onEdit;

  @override
  Widget build(BuildContext context) => Screen(
    child: Column(
      children: [
        Header(
          title: 'Collage',
          leading: ActionIcon(
            Icons.chevron_left,
            'Back',
            () => Navigator.pop(context),
          ),
          trailing: ActionIcon(Icons.add, 'Add photos', onAdd),
        ),
        Expanded(
          child: GridView.count(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            crossAxisCount: 3,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            childAspectRatio: .57,
            children: [
              for (final image in gallery(1, 9))
                GestureDetector(
                  onTap: () => onEdit([image]),
                  child: Picture(image, radius: 11),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class TemplateScreen extends StatelessWidget {
  const TemplateScreen({super.key, required this.image, required this.onUse});
  final String image;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) => Workspace(
    layers: [
      Picture(image),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Header(
          title: 'Video Template',
          leading: ActionIcon(
            Icons.chevron_left,
            'Back',
            () => Navigator.pop(context),
          ),
        ),
      ),
    ],
    footer: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Food & Joy',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Chilling on the beach',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          Pill('Use Template', onTap: onUse),
        ],
      ),
    ),
  );
}

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key, required this.onStart});
  final ValueChanged<List<String>> onStart;
  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  final _photos = gallery(4, 28);
  final _picked = <String>[];

  Future<void> _import() async {
    try {
      final paths = await native.invokeListMethod<String>('pickPhotos') ?? [];
      if (!mounted || paths.isEmpty) return;
      setState(() {
        _photos.insertAll(0, paths);
        _picked.addAll(paths);
      });
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to import photos')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Screen(
    child: Column(
      children: [
        Header(
          title: 'Album',
          leading: ActionIcon(
            Icons.chevron_left,
            'Back',
            () => Navigator.pop(context),
          ),
          trailing: ActionIcon(
            Icons.add_photo_alternate_outlined,
            'Import from device',
            _import,
          ),
        ),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
            ),
            itemCount: _photos.length,
            itemBuilder: (_, i) {
              final path = _photos[i];
              final order = _picked.indexOf(path);
              return Semantics(
                label: 'Photo ${i + 1}',
                selected: order >= 0,
                button: true,
                child: GestureDetector(
                  onTap: () => setState(
                    () => order >= 0 ? _picked.remove(path) : _picked.add(path),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Picture(path),
                      if (order >= 0)
                        ColoredBox(
                          color: Colors.black54,
                          child: Center(
                            child: Text(
                              '${order + 1}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_picked.length} photos selected',
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
              Pill(
                'Start',
                onTap: _picked.isEmpty
                    ? null
                    : () => widget.onStart(List.of(_picked)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.photos, required this.onEdit});
  final List<String> photos;
  final void Function(List<String>, double?) onEdit;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late final _photos = List<String>.of(widget.photos);
  Timer? _timer;
  int _index = 0;
  bool _cropped = false;

  void _play() => setState(() {
    if (_timer != null) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer = Timer.periodic(const Duration(seconds: 2), (_) {
        setState(() => _index = (_index + 1) % _photos.length);
      });
    }
  });

  Future<void> _replace() async {
    final index = _index;
    try {
      final paths = await native.invokeListMethod<String>('pickPhotos') ?? [];
      if (mounted && paths.isNotEmpty) {
        setState(() => _photos[index] = paths.first);
      }
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to replace photo')),
        );
      }
    }
  }

  void _edit() {
    if (_timer != null) _play();
    widget.onEdit(List.of(_photos), _cropped ? 1 : null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Workspace(
    layers: [
      Center(
        child: _cropped
            ? AspectRatio(aspectRatio: 1, child: Picture(_photos[_index]))
            : Picture(_photos[_index]),
      ),
      PlayButton(_timer != null, _play),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Header(
          title: '00:${(_index * 2).toString().padLeft(2, '0')}',
          leading: ActionIcon(
            Icons.close,
            'Close',
            () => Navigator.pop(context),
          ),
          trailing: Pill(
            'Done',
            onTap: () {
              _edit();
            },
          ),
        ),
      ),
      Rail(
        const ['Replace', 'Crop'],
        const [Icons.swap_horiz, Icons.crop],
        -1,
        (index) {
          if (index == 0) {
            unawaited(_replace());
          } else {
            setState(() => _cropped = !_cropped);
          }
        },
      ),
      Positioned(
        left: 14,
        right: 14,
        bottom: 5,
        child: Row(
          children: [
            const Text('00:00', style: TextStyle(fontSize: 11)),
            Expanded(
              child: Slider(
                value: _index.toDouble(),
                max: (_photos.length - 1).clamp(1, 999).toDouble(),
                onChanged: _photos.length > 1
                    ? (v) => setState(() => _index = v.round())
                    : null,
              ),
            ),
            Text(
              '00:${(_photos.length * 2).toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    ],
    footer: Timeline(
      _photos,
      _index,
      (i) => setState(() => _index = i),
      onGrid: _edit,
    ),
  );
}

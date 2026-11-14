import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const native = MethodChannel('slideshow/media');

String asset(String name) => 'assets/media/$name.webp';
List<String> gallery(int group, int count) =>
    List.generate(count, (i) => asset('grid$group-$i'));
String scene(int id) => asset('scene$id');
String effectTile(int id) => asset('tile${id % 19}');

ImageProvider photo(String path) =>
    path.startsWith('assets/') ? AssetImage(path) : FileImage(File(path));

class Slideshow {
  Slideshow(Iterable<String> photos, {this.title = 'My Slideshow'})
    : photos = List.of(photos);

  final String title;
  final List<String> photos;
  final Map<String, double> adjustments = {};
  final List<DecorationItem> decorations = [];
  int effect = -1;
  int preset = -1;
  int transition = -1;
  double intensity = .6;
  double rotation = 0;
  double? ratio;
  String? music;
  double volume = .6;

  factory Slideshow.fromJson(Map<String, dynamic> json) {
    final project = Slideshow(
      (json['photos'] as List).cast<String>(),
      title: json['title'] as String,
    );
    return project
      ..adjustments.addAll((json['adjustments'] as Map).cast<String, double>())
      ..decorations.addAll(
        (json['decorations'] as List).map(
          (item) => DecorationItem(
            item['text'] as String,
            Offset(
              (item['x'] as num).toDouble(),
              (item['y'] as num).toDouble(),
            ),
            sticker: item['sticker'] as bool,
          ),
        ),
      )
      ..effect = json['effect'] as int
      ..preset = json['preset'] as int
      ..transition = json['transition'] as int
      ..intensity = (json['intensity'] as num).toDouble()
      ..rotation = (json['rotation'] as num).toDouble()
      ..ratio = (json['ratio'] as num?)?.toDouble()
      ..music = json['music'] as String?
      ..volume = (json['volume'] as num).toDouble();
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'photos': photos,
    'adjustments': adjustments,
    'decorations': [
      for (final item in decorations)
        {
          'text': item.text,
          'x': item.position.dx,
          'y': item.position.dy,
          'sticker': item.sticker,
        },
    ],
    'effect': effect,
    'preset': preset,
    'transition': transition,
    'intensity': intensity,
    'rotation': rotation,
    'ratio': ratio,
    'music': music,
    'volume': volume,
  };

  bool get demo => photos.isEmpty;
}

class DecorationItem {
  DecorationItem(this.text, this.position, {required this.sticker});

  String text;
  Offset position;
  final bool sticker;
}

class ProjectStore {
  static Future<List<Slideshow>> load() async {
    final data = await native.invokeMethod<String>('loadProjects');
    if (data == null) return [];
    return (jsonDecode(data) as List)
        .map((json) => Slideshow.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<void> save(List<Slideshow> projects) =>
      native.invokeMethod('saveProjects', jsonEncode(projects));
}

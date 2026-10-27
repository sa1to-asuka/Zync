import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'pro_photo_models.dart';

/// 非破坏性编辑配方存储。按源文件 SHA-256 关联，原图永不被修改。
class PhotoRecipeStore {
  PhotoRecipeStore._();

  static final PhotoRecipeStore instance = PhotoRecipeStore._();

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/edit_recipes');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _fileFor(String sourceHash) async {
    final dir = await _dir();
    final safe = sourceHash.isEmpty ? 'unknown' : sourceHash;
    return File('${dir.path}/$safe.json');
  }

  Future<void> save(String sourceHash, PhotoEditRecipe recipe) async {
    final file = await _fileFor(sourceHash);
    await file.writeAsString(recipe.toJsonString(), flush: true);
  }

  Future<PhotoEditRecipe?> load(String sourceHash) async {
    final file = await _fileFor(sourceHash);
    if (!await file.exists()) return null;
    try {
      return PhotoEditRecipe.fromJsonString(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String sourceHash) async {
    final file = await _fileFor(sourceHash);
    if (await file.exists()) await file.delete();
  }

  static String hashBytes(List<int> bytes) => sha256.convert(bytes).toString();

  static String toXmp(PhotoEditRecipe recipe) {
    final payload = base64Encode(utf8.encode(recipe.toJsonString()));
    return '''<?xml version="1.0" encoding="UTF-8"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/">
  <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    <rdf:Description xmlns:zync="https://zync.app/ns/1.0/" zync:version="1">
      <zync:recipe>$payload</zync:recipe>
    </rdf:Description>
  </rdf:RDF>
</x:xmpmeta>
''';
  }

  static PhotoEditRecipe? fromXmp(String xmp) {
    try {
      final match =
          RegExp(r'<zync:recipe>([^<]+)</zync:recipe>').firstMatch(xmp);
      if (match == null) return null;
      final json = utf8.decode(base64Decode(match.group(1)!.trim()));
      return PhotoEditRecipe.fromJsonString(json);
    } catch (_) {
      return null;
    }
  }
}

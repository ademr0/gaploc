// Copyright (c) 2022 Ade M Ramdani
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
import 'dart:convert';
import 'dart:io';

import 'package:gaploc/country.dart';
import 'package:gaploc/languages.dart';
import 'package:intl/intl.dart';
import 'package:intl/locale.dart';

void _eprint(String msg) {
  print('\x1B[31m$msg\x1B[0m');
  exit(1);
}

Future<T> _readJson<T>(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    _eprint('File not found: $path');
  }
  final json = await file.readAsString();
  return jsonDecode(json);
}

Future<List<String>> _getFiles(String path, String ext) async {
  final dir = Directory(path);
  if (!dir.existsSync()) {
    _eprint('Directory not found: $path');
  }
  final files = await dir.list().where((f) => f.path.endsWith(ext)).toList();
  return files.map((f) => f.path).toList();
}

List _isValidLocale(String str) {
  // if str is path, get the file name and remove the extension.
  if (str.contains('/')) {
    str = str.split('/').last.split('.').first;
  }
  Locale locale = Locale.parse(str);
  if (!languages.containsKey(locale.languageCode)) {
    return [false, 'Invalid language code: ${locale.languageCode}'];
  }
  if (locale.countryCode != null &&
      !countries.containsKey(locale.countryCode)) {
    return [false, 'Invalid country code: ${locale.countryCode}'];
  }
  return [true, Intl.canonicalizedLocale(locale.toString())];
}

Map<String, List<String>> _groupLocale(List<dynamic> locales) {
  Map<String, List<String>> map = {};
  for (String locale in locales) {
    Locale l = Locale.parse(locale);
    if (!map.containsKey(l.languageCode)) {
      map[l.languageCode] = [];
    }
    String country = l.countryCode ?? 'default';
    map[l.languageCode]!.add(country);
  }
  return map;
}

Future<void> writeToFile(String path, String content) async {
  final file = File(path);
  await file.writeAsString(content);
}

const String _localeCodeTemplate = '''
class CLASS extends EXTENDS {
  CLASS(FIRST) : super(SECOND);

CODE_BODY
}
''';

const String _mainTemplate = '''
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

INTL_IMPORT

abstract class Gaploc {
  Gaploc(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static Gaploc of(BuildContext context) {
    return Localizations.of<Gaploc>(context, Gaploc)!;
  }

  static const LocalizationsDelegate<Gaploc> delegate = _GaplocDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    delegate,
  ];

  static const List<Locale> supportedLocales = [
SUPPORTED_LOCALES
  ];

GETTERS
}

class _GaplocDelegate extends LocalizationsDelegate<Gaploc> {
  const _GaplocDelegate();

  @override
  Future<Gaploc> load(Locale locale) {
    return SynchronousFuture<Gaploc>(lookupGaploc(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[LOCALE_CODES].contains(locale.languageCode);

  @override
  bool shouldReload(_GaplocDelegate old) => false;
}

Gaploc lookupGaploc(Locale locale) {
  LOCALE_LOOKUP

  throw FlutterError(
    'Gaploc.delegate failed to load an instance of Gaploc for the locale "\$locale". '
    'This is likely because the locale provided is not supported by the application. '
    'Check the locale provided by the operating system, and check that the locale '
    'is listed by "Gaploc.delegate.supportedLocales".'
  );
}
''';

String _generateLocaleCode(String locale, Map<String, dynamic> json) {
  final className = _createClassName(locale);
  Locale l = Locale.parse(locale);
  String extendsClass = 'Gaploc';
  String constructorParams = '[String locale = \'${l.languageCode}\']';
  String superConstructorParams = 'locale';
  if (l.countryCode != null) {
    extendsClass = _createClassName(l.languageCode);
    constructorParams = '';
    superConstructorParams = '\'$locale\'';
  }

  String codeBody = '';
  json.forEach((key, value) {
    codeBody += '  @override\n';
    codeBody += '  String get $key => \'${value.toString()}\';\n\n';
  });

  // remove last newline
  codeBody = codeBody.substring(0, codeBody.length - 1);

  return __generateLocaleCode(className, extendsClass, constructorParams,
      superConstructorParams, codeBody);
}

String _generateMainCode(
    Map<String, List<String>> localeGroup, List<String> keys) {
  return _mainTemplate
      .replaceAll('INTL_IMPORT', _generateImport(localeGroup))
      .replaceAll('SUPPORTED_LOCALES', _generateSupportedLocale(localeGroup))
      .replaceAll('LOCALE_CODES', __generateLocaleCodes(localeGroup))
      .replaceAll('GETTERS', _generateagetters(keys))
      .replaceAll('LOCALE_LOOKUP', _generateLocaleLookup(localeGroup));
}

String _createClassName(String locale) {
  Locale l = Locale.parse(locale);
  String name = l.languageCode;
  // uppercase first letter and lowercase the rest
  name = name[0].toUpperCase() + name.substring(1).toLowerCase();
  if (l.countryCode != null) {
    String country = l.countryCode!;
    // uppercase first letter and lowercase the rest
    country = country[0].toUpperCase() + country.substring(1).toLowerCase();
    name += country;
  }
  return 'Gaploc$name';
}

String _generateagetters(List<String> key) {
  String code = '';
  for (var element in key) {
    code += '  String get $element;\n\n';
  }
  // remove last newline
  code = code.substring(0, code.length - 1);
  return code;
}

String _generateImport(Map<String, List<String>> localeGroup) {
  String fileNamePrefix = 'gaploc_';
  String imports = '';
  localeGroup.forEach((key, value) {
    imports += 'import \'$fileNamePrefix$key.dart\';\n';
  });
  return imports;
}

String __generateLocaleCode(String className, String extendsClass,
    String constructorParams, String superConstructorParams, String codeBody) {
  return _localeCodeTemplate
      .replaceAll('CLASS', className)
      .replaceAll('EXTENDS', extendsClass)
      .replaceAll('FIRST', constructorParams)
      .replaceAll('SECOND', superConstructorParams)
      .replaceAll('CODE_BODY', codeBody);
}

String __generateLocaleCodes(Map<String, List<String>> localeGroup) {
  String result = '';
  localeGroup.forEach((key, _) {
    result += '\'$key\', ';
  });
  return result.substring(0, result.length - 2);
}

String _generateLocaleLookup(Map<String, List<String>> localeGroup) {
  String result = '  switch (locale.languageCode) {\n';
  localeGroup.forEach((key, value) {
    result += '    case \'$key\': {\n';
    result += '      switch (locale.countryCode) {\n';
    for (var element in value) {
      if (element == 'default') {
        continue;
      }
      result += '        case \'$element\':\n';
      result += '          return ${_createClassName('$key-$element')}();\n';
    }
    result += '      }\n';
    // break if no country code
    result += '      break;\n';
    result += '    }\n';
  });
  result += '  }\n\n';
  result += '  switch (locale.languageCode) {\n';
  localeGroup.forEach((key, _) {
    result += '    case \'$key\':\n';
    result += '      return ${_createClassName(key)}();\n';
  });
  result += '  }\n';
  return result;
}

String _generateSupportedLocale(Map<String, List<String>> localeGroup) {
  String result = '';
  localeGroup.forEach((key, value) {
    for (var element in value) {
      String? country = element;
      if (country == 'default') {
        country = null;
      }
      result +=
          '    Locale(\'$key\'${country != null ? ', \'$country\'' : ''}),\n';
    }
  });
  // remove last newline
  result = result.substring(0, result.length - 1);
  return result;
}

class _Config {
  final String inputDir;
  final String outputDir;
  final String template;

  const _Config(this.inputDir, this.outputDir, this.template);

  factory _Config.fromJson(Map<String, dynamic> json) {
    return _Config(
      json['inputDir'] as String,
      json['outputDir'] as String,
      json['template'] as String,
    );
  }

  static _Config defaultConfig() {
    return _Config('lib/locale', 'lib/locale', 'en.json');
  }

  static _Config load() {
    final file = File('gaploc.json');
    if (!file.existsSync()) {
      return defaultConfig();
    }
    final json = jsonDecode(file.readAsStringSync());
    return _Config.fromJson(json);
  }
}

void main() async {
  final cfg = _Config.load();
  final files = await _getFiles(cfg.inputDir, 'json');
  final templateFile = '${cfg.inputDir}/${cfg.template}';
  if (!files.contains(templateFile)) {
    _eprint('Template file not found: $templateFile');
  }

  final validTemplateLocale = _isValidLocale(templateFile);
  if (!validTemplateLocale[0]) {
    _eprint(validTemplateLocale[1]);
  }

  final localeArr = files
      .map((f) => _isValidLocale(f))
      .where((l) => l[0])
      .map((l) => l[1])
      .toList();

  final localeGroup = _groupLocale(localeArr);
  localeGroup.forEach((key, value) {
    if (!value.contains('default')) {
      _eprint(
          'Missing fallback locale for $key, available: $value\nAdd $key.json in ${cfg.inputDir}');
    }
  });

  final template = await _readJson(templateFile);
  final templateKeys = template.keys.toList();

  Map<String, Map<String, dynamic>> localeFiles = {};

  for (String locale in localeArr) {
    final file = '${cfg.inputDir}/$locale.json';
    final json = await _readJson(file);
    final keys = json.keys.toList();
    for (String key in keys) {
      if (!templateKeys.contains(key)) {
        _eprint('Key not found in template: $key from $file');
      }
    }
    localeFiles[locale] = json;
  }

  Map<String, Map<String, String>> localeCodes = {};
  localeFiles.forEach((locale, json) {
    Locale l = Locale.parse(locale);
    if (!localeCodes.containsKey(l.languageCode)) {
      localeCodes[l.languageCode] = {};
    }
    localeCodes[l.languageCode]![locale] = _generateLocaleCode(locale, json);
    print('Generated $locale');
  });

  final outputDir = cfg.outputDir;
  // create output dir if not exists
  await Directory(outputDir).create(recursive: true);

  localeCodes.forEach((language, codes) async {
    final languageFile = '$outputDir/gaploc_$language.dart';
    String code = 'import \'gaploc.dart\';\n\n';
    // add default locale first
    code += '// The translation for ${languages[language]} (`$language`).\n';
    code += codes[language]!;
    codes.remove(language);
    codes.forEach((locale, src) {
      String country = Locale.parse(locale).countryCode!;
      code +=
          '// The translation for ${languages[language]}, as used in ${countries[country]} (`$language`)\n';
      code += src;
    });
    await writeToFile(languageFile, code);
  });

  String mainCode = _generateMainCode(localeGroup, templateKeys);
  await writeToFile('$outputDir/gaploc.dart', mainCode);
}

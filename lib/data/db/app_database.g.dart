// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, BookRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> authors =
      GeneratedColumn<String>(
        'authors',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<String>>($BooksTable.$converterauthors);
  static const VerificationMeta _seriesMeta = const VerificationMeta('series');
  @override
  late final GeneratedColumn<String> series = GeneratedColumn<String>(
    'series',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seriesNumberMeta = const VerificationMeta(
    'seriesNumber',
  );
  @override
  late final GeneratedColumn<int> seriesNumber = GeneratedColumn<int>(
    'series_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _langMeta = const VerificationMeta('lang');
  @override
  late final GeneratedColumn<String> lang = GeneratedColumn<String>(
    'lang',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _annotationMeta = const VerificationMeta(
    'annotation',
  );
  @override
  late final GeneratedColumn<String> annotation = GeneratedColumn<String>(
    'annotation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SourceFormat, String>
  sourceFormat = GeneratedColumn<String>(
    'source_format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<SourceFormat>($BooksTable.$convertersourceFormat);
  static const VerificationMeta _sourceNameMeta = const VerificationMeta(
    'sourceName',
  );
  @override
  late final GeneratedColumn<String> sourceName = GeneratedColumn<String>(
    'source_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceSizeMeta = const VerificationMeta(
    'sourceSize',
  );
  @override
  late final GeneratedColumn<int> sourceSize = GeneratedColumn<int>(
    'source_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceHashMeta = const VerificationMeta(
    'sourceHash',
  );
  @override
  late final GeneratedColumn<String> sourceHash = GeneratedColumn<String>(
    'source_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _parserVersionMeta = const VerificationMeta(
    'parserVersion',
  );
  @override
  late final GeneratedColumn<int> parserVersion = GeneratedColumn<int>(
    'parser_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordCountMeta = const VerificationMeta(
    'wordCount',
  );
  @override
  late final GeneratedColumn<int> wordCount = GeneratedColumn<int>(
    'word_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionWordMeta = const VerificationMeta(
    'positionWord',
  );
  @override
  late final GeneratedColumn<int> positionWord = GeneratedColumn<int>(
    'position_word',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _positionSectionMeta = const VerificationMeta(
    'positionSection',
  );
  @override
  late final GeneratedColumn<int> positionSection = GeneratedColumn<int>(
    'position_section',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _positionBlockMeta = const VerificationMeta(
    'positionBlock',
  );
  @override
  late final GeneratedColumn<int> positionBlock = GeneratedColumn<int>(
    'position_block',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _positionCharMeta = const VerificationMeta(
    'positionChar',
  );
  @override
  late final GeneratedColumn<int> positionChar = GeneratedColumn<int>(
    'position_char',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openedAtMeta = const VerificationMeta(
    'openedAt',
  );
  @override
  late final GeneratedColumn<DateTime> openedAt = GeneratedColumn<DateTime>(
    'opened_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _touchedAtMeta = const VerificationMeta(
    'touchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> touchedAt = GeneratedColumn<DateTime>(
    'touched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverFileMeta = const VerificationMeta(
    'coverFile',
  );
  @override
  late final GeneratedColumn<String> coverFile = GeneratedColumn<String>(
    'cover_file',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    authors,
    series,
    seriesNumber,
    lang,
    annotation,
    sourceFormat,
    sourceName,
    sourceSize,
    sourceHash,
    parserVersion,
    wordCount,
    positionWord,
    positionSection,
    positionBlock,
    positionChar,
    addedAt,
    openedAt,
    touchedAt,
    coverFile,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('series')) {
      context.handle(
        _seriesMeta,
        series.isAcceptableOrUnknown(data['series']!, _seriesMeta),
      );
    }
    if (data.containsKey('series_number')) {
      context.handle(
        _seriesNumberMeta,
        seriesNumber.isAcceptableOrUnknown(
          data['series_number']!,
          _seriesNumberMeta,
        ),
      );
    }
    if (data.containsKey('lang')) {
      context.handle(
        _langMeta,
        lang.isAcceptableOrUnknown(data['lang']!, _langMeta),
      );
    }
    if (data.containsKey('annotation')) {
      context.handle(
        _annotationMeta,
        annotation.isAcceptableOrUnknown(data['annotation']!, _annotationMeta),
      );
    }
    if (data.containsKey('source_name')) {
      context.handle(
        _sourceNameMeta,
        sourceName.isAcceptableOrUnknown(data['source_name']!, _sourceNameMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceNameMeta);
    }
    if (data.containsKey('source_size')) {
      context.handle(
        _sourceSizeMeta,
        sourceSize.isAcceptableOrUnknown(data['source_size']!, _sourceSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceSizeMeta);
    }
    if (data.containsKey('source_hash')) {
      context.handle(
        _sourceHashMeta,
        sourceHash.isAcceptableOrUnknown(data['source_hash']!, _sourceHashMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceHashMeta);
    }
    if (data.containsKey('parser_version')) {
      context.handle(
        _parserVersionMeta,
        parserVersion.isAcceptableOrUnknown(
          data['parser_version']!,
          _parserVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parserVersionMeta);
    }
    if (data.containsKey('word_count')) {
      context.handle(
        _wordCountMeta,
        wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta),
      );
    } else if (isInserting) {
      context.missing(_wordCountMeta);
    }
    if (data.containsKey('position_word')) {
      context.handle(
        _positionWordMeta,
        positionWord.isAcceptableOrUnknown(
          data['position_word']!,
          _positionWordMeta,
        ),
      );
    }
    if (data.containsKey('position_section')) {
      context.handle(
        _positionSectionMeta,
        positionSection.isAcceptableOrUnknown(
          data['position_section']!,
          _positionSectionMeta,
        ),
      );
    }
    if (data.containsKey('position_block')) {
      context.handle(
        _positionBlockMeta,
        positionBlock.isAcceptableOrUnknown(
          data['position_block']!,
          _positionBlockMeta,
        ),
      );
    }
    if (data.containsKey('position_char')) {
      context.handle(
        _positionCharMeta,
        positionChar.isAcceptableOrUnknown(
          data['position_char']!,
          _positionCharMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('opened_at')) {
      context.handle(
        _openedAtMeta,
        openedAt.isAcceptableOrUnknown(data['opened_at']!, _openedAtMeta),
      );
    }
    if (data.containsKey('touched_at')) {
      context.handle(
        _touchedAtMeta,
        touchedAt.isAcceptableOrUnknown(data['touched_at']!, _touchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_touchedAtMeta);
    }
    if (data.containsKey('cover_file')) {
      context.handle(
        _coverFileMeta,
        coverFile.isAcceptableOrUnknown(data['cover_file']!, _coverFileMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      authors: $BooksTable.$converterauthors.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}authors'],
        )!,
      ),
      series: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series'],
      ),
      seriesNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}series_number'],
      ),
      lang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lang'],
      ),
      annotation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}annotation'],
      ),
      sourceFormat: $BooksTable.$convertersourceFormat.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source_format'],
        )!,
      ),
      sourceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_name'],
      )!,
      sourceSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_size'],
      )!,
      sourceHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_hash'],
      )!,
      parserVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parser_version'],
      )!,
      wordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}word_count'],
      )!,
      positionWord: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_word'],
      )!,
      positionSection: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_section'],
      )!,
      positionBlock: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_block'],
      )!,
      positionChar: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_char'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      openedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}opened_at'],
      ),
      touchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}touched_at'],
      )!,
      coverFile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_file'],
      ),
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterauthors =
      const StringListConverter();
  static JsonTypeConverter2<SourceFormat, String, String>
  $convertersourceFormat = const EnumNameConverter<SourceFormat>(
    SourceFormat.values,
  );
}

class BookRow extends DataClass implements Insertable<BookRow> {
  /// AUTOINCREMENT: ids of deleted books are never reused, so a stale folder
  /// can't be mistaken for a new book.
  final int id;
  final String title;
  final List<String> authors;
  final String? series;
  final int? seriesNumber;
  final String? lang;
  final String? annotation;
  final SourceFormat sourceFormat;

  /// Original file name, shown in errors and details.
  final String sourceName;
  final int sourceSize;

  /// SHA-256 of the source file (hex): the duplicate check.
  final String sourceHash;

  /// Version of the parser that built the stored content; older → reparse.
  final int parserVersion;
  final int wordCount;

  /// Reading position: word index plus its anchor (ADR 0002).
  final int positionWord;
  final int positionSection;
  final int positionBlock;
  final int positionChar;
  final DateTime addedAt;
  final DateTime? openedAt;

  /// Last add, open or repeated import: the library is sorted by it, so a
  /// new book and a duplicate come on top (schema v2).
  final DateTime touchedAt;

  /// Name of the cover picture in the book folder (`cover.jpg`), or null
  /// (schema v2).
  final String? coverFile;
  const BookRow({
    required this.id,
    required this.title,
    required this.authors,
    this.series,
    this.seriesNumber,
    this.lang,
    this.annotation,
    required this.sourceFormat,
    required this.sourceName,
    required this.sourceSize,
    required this.sourceHash,
    required this.parserVersion,
    required this.wordCount,
    required this.positionWord,
    required this.positionSection,
    required this.positionBlock,
    required this.positionChar,
    required this.addedAt,
    this.openedAt,
    required this.touchedAt,
    this.coverFile,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    {
      map['authors'] = Variable<String>(
        $BooksTable.$converterauthors.toSql(authors),
      );
    }
    if (!nullToAbsent || series != null) {
      map['series'] = Variable<String>(series);
    }
    if (!nullToAbsent || seriesNumber != null) {
      map['series_number'] = Variable<int>(seriesNumber);
    }
    if (!nullToAbsent || lang != null) {
      map['lang'] = Variable<String>(lang);
    }
    if (!nullToAbsent || annotation != null) {
      map['annotation'] = Variable<String>(annotation);
    }
    {
      map['source_format'] = Variable<String>(
        $BooksTable.$convertersourceFormat.toSql(sourceFormat),
      );
    }
    map['source_name'] = Variable<String>(sourceName);
    map['source_size'] = Variable<int>(sourceSize);
    map['source_hash'] = Variable<String>(sourceHash);
    map['parser_version'] = Variable<int>(parserVersion);
    map['word_count'] = Variable<int>(wordCount);
    map['position_word'] = Variable<int>(positionWord);
    map['position_section'] = Variable<int>(positionSection);
    map['position_block'] = Variable<int>(positionBlock);
    map['position_char'] = Variable<int>(positionChar);
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || openedAt != null) {
      map['opened_at'] = Variable<DateTime>(openedAt);
    }
    map['touched_at'] = Variable<DateTime>(touchedAt);
    if (!nullToAbsent || coverFile != null) {
      map['cover_file'] = Variable<String>(coverFile);
    }
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      title: Value(title),
      authors: Value(authors),
      series: series == null && nullToAbsent
          ? const Value.absent()
          : Value(series),
      seriesNumber: seriesNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesNumber),
      lang: lang == null && nullToAbsent ? const Value.absent() : Value(lang),
      annotation: annotation == null && nullToAbsent
          ? const Value.absent()
          : Value(annotation),
      sourceFormat: Value(sourceFormat),
      sourceName: Value(sourceName),
      sourceSize: Value(sourceSize),
      sourceHash: Value(sourceHash),
      parserVersion: Value(parserVersion),
      wordCount: Value(wordCount),
      positionWord: Value(positionWord),
      positionSection: Value(positionSection),
      positionBlock: Value(positionBlock),
      positionChar: Value(positionChar),
      addedAt: Value(addedAt),
      openedAt: openedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(openedAt),
      touchedAt: Value(touchedAt),
      coverFile: coverFile == null && nullToAbsent
          ? const Value.absent()
          : Value(coverFile),
    );
  }

  factory BookRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookRow(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      authors: serializer.fromJson<List<String>>(json['authors']),
      series: serializer.fromJson<String?>(json['series']),
      seriesNumber: serializer.fromJson<int?>(json['seriesNumber']),
      lang: serializer.fromJson<String?>(json['lang']),
      annotation: serializer.fromJson<String?>(json['annotation']),
      sourceFormat: $BooksTable.$convertersourceFormat.fromJson(
        serializer.fromJson<String>(json['sourceFormat']),
      ),
      sourceName: serializer.fromJson<String>(json['sourceName']),
      sourceSize: serializer.fromJson<int>(json['sourceSize']),
      sourceHash: serializer.fromJson<String>(json['sourceHash']),
      parserVersion: serializer.fromJson<int>(json['parserVersion']),
      wordCount: serializer.fromJson<int>(json['wordCount']),
      positionWord: serializer.fromJson<int>(json['positionWord']),
      positionSection: serializer.fromJson<int>(json['positionSection']),
      positionBlock: serializer.fromJson<int>(json['positionBlock']),
      positionChar: serializer.fromJson<int>(json['positionChar']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      openedAt: serializer.fromJson<DateTime?>(json['openedAt']),
      touchedAt: serializer.fromJson<DateTime>(json['touchedAt']),
      coverFile: serializer.fromJson<String?>(json['coverFile']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'authors': serializer.toJson<List<String>>(authors),
      'series': serializer.toJson<String?>(series),
      'seriesNumber': serializer.toJson<int?>(seriesNumber),
      'lang': serializer.toJson<String?>(lang),
      'annotation': serializer.toJson<String?>(annotation),
      'sourceFormat': serializer.toJson<String>(
        $BooksTable.$convertersourceFormat.toJson(sourceFormat),
      ),
      'sourceName': serializer.toJson<String>(sourceName),
      'sourceSize': serializer.toJson<int>(sourceSize),
      'sourceHash': serializer.toJson<String>(sourceHash),
      'parserVersion': serializer.toJson<int>(parserVersion),
      'wordCount': serializer.toJson<int>(wordCount),
      'positionWord': serializer.toJson<int>(positionWord),
      'positionSection': serializer.toJson<int>(positionSection),
      'positionBlock': serializer.toJson<int>(positionBlock),
      'positionChar': serializer.toJson<int>(positionChar),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'openedAt': serializer.toJson<DateTime?>(openedAt),
      'touchedAt': serializer.toJson<DateTime>(touchedAt),
      'coverFile': serializer.toJson<String?>(coverFile),
    };
  }

  BookRow copyWith({
    int? id,
    String? title,
    List<String>? authors,
    Value<String?> series = const Value.absent(),
    Value<int?> seriesNumber = const Value.absent(),
    Value<String?> lang = const Value.absent(),
    Value<String?> annotation = const Value.absent(),
    SourceFormat? sourceFormat,
    String? sourceName,
    int? sourceSize,
    String? sourceHash,
    int? parserVersion,
    int? wordCount,
    int? positionWord,
    int? positionSection,
    int? positionBlock,
    int? positionChar,
    DateTime? addedAt,
    Value<DateTime?> openedAt = const Value.absent(),
    DateTime? touchedAt,
    Value<String?> coverFile = const Value.absent(),
  }) => BookRow(
    id: id ?? this.id,
    title: title ?? this.title,
    authors: authors ?? this.authors,
    series: series.present ? series.value : this.series,
    seriesNumber: seriesNumber.present ? seriesNumber.value : this.seriesNumber,
    lang: lang.present ? lang.value : this.lang,
    annotation: annotation.present ? annotation.value : this.annotation,
    sourceFormat: sourceFormat ?? this.sourceFormat,
    sourceName: sourceName ?? this.sourceName,
    sourceSize: sourceSize ?? this.sourceSize,
    sourceHash: sourceHash ?? this.sourceHash,
    parserVersion: parserVersion ?? this.parserVersion,
    wordCount: wordCount ?? this.wordCount,
    positionWord: positionWord ?? this.positionWord,
    positionSection: positionSection ?? this.positionSection,
    positionBlock: positionBlock ?? this.positionBlock,
    positionChar: positionChar ?? this.positionChar,
    addedAt: addedAt ?? this.addedAt,
    openedAt: openedAt.present ? openedAt.value : this.openedAt,
    touchedAt: touchedAt ?? this.touchedAt,
    coverFile: coverFile.present ? coverFile.value : this.coverFile,
  );
  BookRow copyWithCompanion(BooksCompanion data) {
    return BookRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      authors: data.authors.present ? data.authors.value : this.authors,
      series: data.series.present ? data.series.value : this.series,
      seriesNumber: data.seriesNumber.present
          ? data.seriesNumber.value
          : this.seriesNumber,
      lang: data.lang.present ? data.lang.value : this.lang,
      annotation: data.annotation.present
          ? data.annotation.value
          : this.annotation,
      sourceFormat: data.sourceFormat.present
          ? data.sourceFormat.value
          : this.sourceFormat,
      sourceName: data.sourceName.present
          ? data.sourceName.value
          : this.sourceName,
      sourceSize: data.sourceSize.present
          ? data.sourceSize.value
          : this.sourceSize,
      sourceHash: data.sourceHash.present
          ? data.sourceHash.value
          : this.sourceHash,
      parserVersion: data.parserVersion.present
          ? data.parserVersion.value
          : this.parserVersion,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
      positionWord: data.positionWord.present
          ? data.positionWord.value
          : this.positionWord,
      positionSection: data.positionSection.present
          ? data.positionSection.value
          : this.positionSection,
      positionBlock: data.positionBlock.present
          ? data.positionBlock.value
          : this.positionBlock,
      positionChar: data.positionChar.present
          ? data.positionChar.value
          : this.positionChar,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      openedAt: data.openedAt.present ? data.openedAt.value : this.openedAt,
      touchedAt: data.touchedAt.present ? data.touchedAt.value : this.touchedAt,
      coverFile: data.coverFile.present ? data.coverFile.value : this.coverFile,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('authors: $authors, ')
          ..write('series: $series, ')
          ..write('seriesNumber: $seriesNumber, ')
          ..write('lang: $lang, ')
          ..write('annotation: $annotation, ')
          ..write('sourceFormat: $sourceFormat, ')
          ..write('sourceName: $sourceName, ')
          ..write('sourceSize: $sourceSize, ')
          ..write('sourceHash: $sourceHash, ')
          ..write('parserVersion: $parserVersion, ')
          ..write('wordCount: $wordCount, ')
          ..write('positionWord: $positionWord, ')
          ..write('positionSection: $positionSection, ')
          ..write('positionBlock: $positionBlock, ')
          ..write('positionChar: $positionChar, ')
          ..write('addedAt: $addedAt, ')
          ..write('openedAt: $openedAt, ')
          ..write('touchedAt: $touchedAt, ')
          ..write('coverFile: $coverFile')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    title,
    authors,
    series,
    seriesNumber,
    lang,
    annotation,
    sourceFormat,
    sourceName,
    sourceSize,
    sourceHash,
    parserVersion,
    wordCount,
    positionWord,
    positionSection,
    positionBlock,
    positionChar,
    addedAt,
    openedAt,
    touchedAt,
    coverFile,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.authors == this.authors &&
          other.series == this.series &&
          other.seriesNumber == this.seriesNumber &&
          other.lang == this.lang &&
          other.annotation == this.annotation &&
          other.sourceFormat == this.sourceFormat &&
          other.sourceName == this.sourceName &&
          other.sourceSize == this.sourceSize &&
          other.sourceHash == this.sourceHash &&
          other.parserVersion == this.parserVersion &&
          other.wordCount == this.wordCount &&
          other.positionWord == this.positionWord &&
          other.positionSection == this.positionSection &&
          other.positionBlock == this.positionBlock &&
          other.positionChar == this.positionChar &&
          other.addedAt == this.addedAt &&
          other.openedAt == this.openedAt &&
          other.touchedAt == this.touchedAt &&
          other.coverFile == this.coverFile);
}

class BooksCompanion extends UpdateCompanion<BookRow> {
  final Value<int> id;
  final Value<String> title;
  final Value<List<String>> authors;
  final Value<String?> series;
  final Value<int?> seriesNumber;
  final Value<String?> lang;
  final Value<String?> annotation;
  final Value<SourceFormat> sourceFormat;
  final Value<String> sourceName;
  final Value<int> sourceSize;
  final Value<String> sourceHash;
  final Value<int> parserVersion;
  final Value<int> wordCount;
  final Value<int> positionWord;
  final Value<int> positionSection;
  final Value<int> positionBlock;
  final Value<int> positionChar;
  final Value<DateTime> addedAt;
  final Value<DateTime?> openedAt;
  final Value<DateTime> touchedAt;
  final Value<String?> coverFile;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.authors = const Value.absent(),
    this.series = const Value.absent(),
    this.seriesNumber = const Value.absent(),
    this.lang = const Value.absent(),
    this.annotation = const Value.absent(),
    this.sourceFormat = const Value.absent(),
    this.sourceName = const Value.absent(),
    this.sourceSize = const Value.absent(),
    this.sourceHash = const Value.absent(),
    this.parserVersion = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.positionWord = const Value.absent(),
    this.positionSection = const Value.absent(),
    this.positionBlock = const Value.absent(),
    this.positionChar = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.touchedAt = const Value.absent(),
    this.coverFile = const Value.absent(),
  });
  BooksCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required List<String> authors,
    this.series = const Value.absent(),
    this.seriesNumber = const Value.absent(),
    this.lang = const Value.absent(),
    this.annotation = const Value.absent(),
    required SourceFormat sourceFormat,
    required String sourceName,
    required int sourceSize,
    required String sourceHash,
    required int parserVersion,
    required int wordCount,
    this.positionWord = const Value.absent(),
    this.positionSection = const Value.absent(),
    this.positionBlock = const Value.absent(),
    this.positionChar = const Value.absent(),
    required DateTime addedAt,
    this.openedAt = const Value.absent(),
    required DateTime touchedAt,
    this.coverFile = const Value.absent(),
  }) : title = Value(title),
       authors = Value(authors),
       sourceFormat = Value(sourceFormat),
       sourceName = Value(sourceName),
       sourceSize = Value(sourceSize),
       sourceHash = Value(sourceHash),
       parserVersion = Value(parserVersion),
       wordCount = Value(wordCount),
       addedAt = Value(addedAt),
       touchedAt = Value(touchedAt);
  static Insertable<BookRow> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? authors,
    Expression<String>? series,
    Expression<int>? seriesNumber,
    Expression<String>? lang,
    Expression<String>? annotation,
    Expression<String>? sourceFormat,
    Expression<String>? sourceName,
    Expression<int>? sourceSize,
    Expression<String>? sourceHash,
    Expression<int>? parserVersion,
    Expression<int>? wordCount,
    Expression<int>? positionWord,
    Expression<int>? positionSection,
    Expression<int>? positionBlock,
    Expression<int>? positionChar,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? openedAt,
    Expression<DateTime>? touchedAt,
    Expression<String>? coverFile,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (authors != null) 'authors': authors,
      if (series != null) 'series': series,
      if (seriesNumber != null) 'series_number': seriesNumber,
      if (lang != null) 'lang': lang,
      if (annotation != null) 'annotation': annotation,
      if (sourceFormat != null) 'source_format': sourceFormat,
      if (sourceName != null) 'source_name': sourceName,
      if (sourceSize != null) 'source_size': sourceSize,
      if (sourceHash != null) 'source_hash': sourceHash,
      if (parserVersion != null) 'parser_version': parserVersion,
      if (wordCount != null) 'word_count': wordCount,
      if (positionWord != null) 'position_word': positionWord,
      if (positionSection != null) 'position_section': positionSection,
      if (positionBlock != null) 'position_block': positionBlock,
      if (positionChar != null) 'position_char': positionChar,
      if (addedAt != null) 'added_at': addedAt,
      if (openedAt != null) 'opened_at': openedAt,
      if (touchedAt != null) 'touched_at': touchedAt,
      if (coverFile != null) 'cover_file': coverFile,
    });
  }

  BooksCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<List<String>>? authors,
    Value<String?>? series,
    Value<int?>? seriesNumber,
    Value<String?>? lang,
    Value<String?>? annotation,
    Value<SourceFormat>? sourceFormat,
    Value<String>? sourceName,
    Value<int>? sourceSize,
    Value<String>? sourceHash,
    Value<int>? parserVersion,
    Value<int>? wordCount,
    Value<int>? positionWord,
    Value<int>? positionSection,
    Value<int>? positionBlock,
    Value<int>? positionChar,
    Value<DateTime>? addedAt,
    Value<DateTime?>? openedAt,
    Value<DateTime>? touchedAt,
    Value<String?>? coverFile,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      series: series ?? this.series,
      seriesNumber: seriesNumber ?? this.seriesNumber,
      lang: lang ?? this.lang,
      annotation: annotation ?? this.annotation,
      sourceFormat: sourceFormat ?? this.sourceFormat,
      sourceName: sourceName ?? this.sourceName,
      sourceSize: sourceSize ?? this.sourceSize,
      sourceHash: sourceHash ?? this.sourceHash,
      parserVersion: parserVersion ?? this.parserVersion,
      wordCount: wordCount ?? this.wordCount,
      positionWord: positionWord ?? this.positionWord,
      positionSection: positionSection ?? this.positionSection,
      positionBlock: positionBlock ?? this.positionBlock,
      positionChar: positionChar ?? this.positionChar,
      addedAt: addedAt ?? this.addedAt,
      openedAt: openedAt ?? this.openedAt,
      touchedAt: touchedAt ?? this.touchedAt,
      coverFile: coverFile ?? this.coverFile,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (authors.present) {
      map['authors'] = Variable<String>(
        $BooksTable.$converterauthors.toSql(authors.value),
      );
    }
    if (series.present) {
      map['series'] = Variable<String>(series.value);
    }
    if (seriesNumber.present) {
      map['series_number'] = Variable<int>(seriesNumber.value);
    }
    if (lang.present) {
      map['lang'] = Variable<String>(lang.value);
    }
    if (annotation.present) {
      map['annotation'] = Variable<String>(annotation.value);
    }
    if (sourceFormat.present) {
      map['source_format'] = Variable<String>(
        $BooksTable.$convertersourceFormat.toSql(sourceFormat.value),
      );
    }
    if (sourceName.present) {
      map['source_name'] = Variable<String>(sourceName.value);
    }
    if (sourceSize.present) {
      map['source_size'] = Variable<int>(sourceSize.value);
    }
    if (sourceHash.present) {
      map['source_hash'] = Variable<String>(sourceHash.value);
    }
    if (parserVersion.present) {
      map['parser_version'] = Variable<int>(parserVersion.value);
    }
    if (wordCount.present) {
      map['word_count'] = Variable<int>(wordCount.value);
    }
    if (positionWord.present) {
      map['position_word'] = Variable<int>(positionWord.value);
    }
    if (positionSection.present) {
      map['position_section'] = Variable<int>(positionSection.value);
    }
    if (positionBlock.present) {
      map['position_block'] = Variable<int>(positionBlock.value);
    }
    if (positionChar.present) {
      map['position_char'] = Variable<int>(positionChar.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<DateTime>(openedAt.value);
    }
    if (touchedAt.present) {
      map['touched_at'] = Variable<DateTime>(touchedAt.value);
    }
    if (coverFile.present) {
      map['cover_file'] = Variable<String>(coverFile.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('authors: $authors, ')
          ..write('series: $series, ')
          ..write('seriesNumber: $seriesNumber, ')
          ..write('lang: $lang, ')
          ..write('annotation: $annotation, ')
          ..write('sourceFormat: $sourceFormat, ')
          ..write('sourceName: $sourceName, ')
          ..write('sourceSize: $sourceSize, ')
          ..write('sourceHash: $sourceHash, ')
          ..write('parserVersion: $parserVersion, ')
          ..write('wordCount: $wordCount, ')
          ..write('positionWord: $positionWord, ')
          ..write('positionSection: $positionSection, ')
          ..write('positionBlock: $positionBlock, ')
          ..write('positionChar: $positionChar, ')
          ..write('addedAt: $addedAt, ')
          ..write('openedAt: $openedAt, ')
          ..write('touchedAt: $touchedAt, ')
          ..write('coverFile: $coverFile')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(AppSettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [books, appSettings];
}

typedef $$BooksTableCreateCompanionBuilder = BooksCompanion Function({
  Value<int> id,
  required String title,
  required List<String> authors,
  Value<String?> series,
  Value<int?> seriesNumber,
  Value<String?> lang,
  Value<String?> annotation,
  required SourceFormat sourceFormat,
  required String sourceName,
  required int sourceSize,
  required String sourceHash,
  required int parserVersion,
  required int wordCount,
  Value<int> positionWord,
  Value<int> positionSection,
  Value<int> positionBlock,
  Value<int> positionChar,
  required DateTime addedAt,
  Value<DateTime?> openedAt,
  required DateTime touchedAt,
  Value<String?> coverFile,
});
typedef $$BooksTableUpdateCompanionBuilder = BooksCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<List<String>> authors,
  Value<String?> series,
  Value<int?> seriesNumber,
  Value<String?> lang,
  Value<String?> annotation,
  Value<SourceFormat> sourceFormat,
  Value<String> sourceName,
  Value<int> sourceSize,
  Value<String> sourceHash,
  Value<int> parserVersion,
  Value<int> wordCount,
  Value<int> positionWord,
  Value<int> positionSection,
  Value<int> positionBlock,
  Value<int> positionChar,
  Value<DateTime> addedAt,
  Value<DateTime?> openedAt,
  Value<DateTime> touchedAt,
  Value<String?> coverFile,
});

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get authors => $composableBuilder(
    column: $table.authors,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get series => $composableBuilder(
    column: $table.series,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seriesNumber => $composableBuilder(
    column: $table.seriesNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get annotation => $composableBuilder(
    column: $table.annotation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SourceFormat, SourceFormat, String>
  get sourceFormat => $composableBuilder(
    column: $table.sourceFormat,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceSize => $composableBuilder(
    column: $table.sourceSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceHash => $composableBuilder(
    column: $table.sourceHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get parserVersion => $composableBuilder(
    column: $table.parserVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionWord => $composableBuilder(
    column: $table.positionWord,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionSection => $composableBuilder(
    column: $table.positionSection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionBlock => $composableBuilder(
    column: $table.positionBlock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionChar => $composableBuilder(
    column: $table.positionChar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get touchedAt => $composableBuilder(
    column: $table.touchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverFile => $composableBuilder(
    column: $table.coverFile,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authors => $composableBuilder(
    column: $table.authors,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get series => $composableBuilder(
    column: $table.series,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seriesNumber => $composableBuilder(
    column: $table.seriesNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get annotation => $composableBuilder(
    column: $table.annotation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceFormat => $composableBuilder(
    column: $table.sourceFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceSize => $composableBuilder(
    column: $table.sourceSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceHash => $composableBuilder(
    column: $table.sourceHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parserVersion => $composableBuilder(
    column: $table.parserVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionWord => $composableBuilder(
    column: $table.positionWord,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionSection => $composableBuilder(
    column: $table.positionSection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionBlock => $composableBuilder(
    column: $table.positionBlock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionChar => $composableBuilder(
    column: $table.positionChar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get touchedAt => $composableBuilder(
    column: $table.touchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverFile => $composableBuilder(
    column: $table.coverFile,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get authors =>
      $composableBuilder(column: $table.authors, builder: (column) => column);

  GeneratedColumn<String> get series =>
      $composableBuilder(column: $table.series, builder: (column) => column);

  GeneratedColumn<int> get seriesNumber => $composableBuilder(
    column: $table.seriesNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lang =>
      $composableBuilder(column: $table.lang, builder: (column) => column);

  GeneratedColumn<String> get annotation => $composableBuilder(
    column: $table.annotation,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<SourceFormat, String> get sourceFormat =>
      $composableBuilder(
        column: $table.sourceFormat,
        builder: (column) => column,
      );

  GeneratedColumn<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sourceSize => $composableBuilder(
    column: $table.sourceSize,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceHash => $composableBuilder(
    column: $table.sourceHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get parserVersion => $composableBuilder(
    column: $table.parserVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wordCount =>
      $composableBuilder(column: $table.wordCount, builder: (column) => column);

  GeneratedColumn<int> get positionWord => $composableBuilder(
    column: $table.positionWord,
    builder: (column) => column,
  );

  GeneratedColumn<int> get positionSection => $composableBuilder(
    column: $table.positionSection,
    builder: (column) => column,
  );

  GeneratedColumn<int> get positionBlock => $composableBuilder(
    column: $table.positionBlock,
    builder: (column) => column,
  );

  GeneratedColumn<int> get positionChar => $composableBuilder(
    column: $table.positionChar,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get touchedAt =>
      $composableBuilder(column: $table.touchedAt, builder: (column) => column);

  GeneratedColumn<String> get coverFile =>
      $composableBuilder(column: $table.coverFile, builder: (column) => column);
}

class $$BooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BooksTable,
          BookRow,
          $$BooksTableFilterComposer,
          $$BooksTableOrderingComposer,
          $$BooksTableAnnotationComposer,
          $$BooksTableCreateCompanionBuilder,
          $$BooksTableUpdateCompanionBuilder,
          (BookRow, BaseReferences<_$AppDatabase, $BooksTable, BookRow>),
          BookRow,
          PrefetchHooks Function()
        > {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<List<String>> authors = const Value.absent(),
                Value<String?> series = const Value.absent(),
                Value<int?> seriesNumber = const Value.absent(),
                Value<String?> lang = const Value.absent(),
                Value<String?> annotation = const Value.absent(),
                Value<SourceFormat> sourceFormat = const Value.absent(),
                Value<String> sourceName = const Value.absent(),
                Value<int> sourceSize = const Value.absent(),
                Value<String> sourceHash = const Value.absent(),
                Value<int> parserVersion = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
                Value<int> positionWord = const Value.absent(),
                Value<int> positionSection = const Value.absent(),
                Value<int> positionBlock = const Value.absent(),
                Value<int> positionChar = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> openedAt = const Value.absent(),
                Value<DateTime> touchedAt = const Value.absent(),
                Value<String?> coverFile = const Value.absent(),
              }) => BooksCompanion(
                id: id,
                title: title,
                authors: authors,
                series: series,
                seriesNumber: seriesNumber,
                lang: lang,
                annotation: annotation,
                sourceFormat: sourceFormat,
                sourceName: sourceName,
                sourceSize: sourceSize,
                sourceHash: sourceHash,
                parserVersion: parserVersion,
                wordCount: wordCount,
                positionWord: positionWord,
                positionSection: positionSection,
                positionBlock: positionBlock,
                positionChar: positionChar,
                addedAt: addedAt,
                openedAt: openedAt,
                touchedAt: touchedAt,
                coverFile: coverFile,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required List<String> authors,
                Value<String?> series = const Value.absent(),
                Value<int?> seriesNumber = const Value.absent(),
                Value<String?> lang = const Value.absent(),
                Value<String?> annotation = const Value.absent(),
                required SourceFormat sourceFormat,
                required String sourceName,
                required int sourceSize,
                required String sourceHash,
                required int parserVersion,
                required int wordCount,
                Value<int> positionWord = const Value.absent(),
                Value<int> positionSection = const Value.absent(),
                Value<int> positionBlock = const Value.absent(),
                Value<int> positionChar = const Value.absent(),
                required DateTime addedAt,
                Value<DateTime?> openedAt = const Value.absent(),
                required DateTime touchedAt,
                Value<String?> coverFile = const Value.absent(),
              }) => BooksCompanion.insert(
                id: id,
                title: title,
                authors: authors,
                series: series,
                seriesNumber: seriesNumber,
                lang: lang,
                annotation: annotation,
                sourceFormat: sourceFormat,
                sourceName: sourceName,
                sourceSize: sourceSize,
                sourceHash: sourceHash,
                parserVersion: parserVersion,
                wordCount: wordCount,
                positionWord: positionWord,
                positionSection: positionSection,
                positionBlock: positionBlock,
                positionChar: positionChar,
                addedAt: addedAt,
                openedAt: openedAt,
                touchedAt: touchedAt,
                coverFile: coverFile,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BooksTable, BookRow>(table),
                  BaseReferences<_$AppDatabase, $BooksTable, BookRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BooksTable,
      BookRow,
      $$BooksTableFilterComposer,
      $$BooksTableOrderingComposer,
      $$BooksTableAnnotationComposer,
      $$BooksTableCreateCompanionBuilder,
      $$BooksTableUpdateCompanionBuilder,
      (BookRow, BaseReferences<_$AppDatabase, $BooksTable, BookRow>),
      BookRow,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          SettingRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $AppSettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $AppSettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      SettingRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        SettingRow,
        BaseReferences<_$AppDatabase, $AppSettingsTable, SettingRow>,
      ),
      SettingRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}

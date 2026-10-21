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
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<StatusMark?, String> statusMark =
      GeneratedColumn<String>(
        'status_mark',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<StatusMark?>($BooksTable.$converterstatusMarkn);
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
    finishedAt,
    statusMark,
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
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
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
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
      statusMark: $BooksTable.$converterstatusMarkn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status_mark'],
        ),
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
  static JsonTypeConverter2<StatusMark, String, String> $converterstatusMark =
      const EnumNameConverter<StatusMark>(StatusMark.values);
  static JsonTypeConverter2<StatusMark?, String?, String?>
  $converterstatusMarkn = JsonTypeConverter2.asNullable($converterstatusMark);
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

  /// When the book was read to the end or marked read; null — not read.
  /// Cleared only by hand ("reading again"), not by reading from the start
  /// (schema v3, ADR 0005 addendum 2).
  final DateTime? finishedAt;

  /// "Queued" or "abandoned" set by hand; null — neither. Never set together
  /// with [finishedAt] (schema v4, ADR 0005 addendum 3).
  final StatusMark? statusMark;
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
    this.finishedAt,
    this.statusMark,
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
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    if (!nullToAbsent || statusMark != null) {
      map['status_mark'] = Variable<String>(
        $BooksTable.$converterstatusMarkn.toSql(statusMark),
      );
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
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      statusMark: statusMark == null && nullToAbsent
          ? const Value.absent()
          : Value(statusMark),
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
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      statusMark: $BooksTable.$converterstatusMarkn.fromJson(
        serializer.fromJson<String?>(json['statusMark']),
      ),
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
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'statusMark': serializer.toJson<String?>(
        $BooksTable.$converterstatusMarkn.toJson(statusMark),
      ),
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
    Value<DateTime?> finishedAt = const Value.absent(),
    Value<StatusMark?> statusMark = const Value.absent(),
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
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    statusMark: statusMark.present ? statusMark.value : this.statusMark,
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
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      statusMark: data.statusMark.present
          ? data.statusMark.value
          : this.statusMark,
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
          ..write('coverFile: $coverFile, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('statusMark: $statusMark')
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
    finishedAt,
    statusMark,
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
          other.coverFile == this.coverFile &&
          other.finishedAt == this.finishedAt &&
          other.statusMark == this.statusMark);
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
  final Value<DateTime?> finishedAt;
  final Value<StatusMark?> statusMark;
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
    this.finishedAt = const Value.absent(),
    this.statusMark = const Value.absent(),
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
    this.finishedAt = const Value.absent(),
    this.statusMark = const Value.absent(),
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
    Expression<DateTime>? finishedAt,
    Expression<String>? statusMark,
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
      if (finishedAt != null) 'finished_at': finishedAt,
      if (statusMark != null) 'status_mark': statusMark,
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
    Value<DateTime?>? finishedAt,
    Value<StatusMark?>? statusMark,
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
      finishedAt: finishedAt ?? this.finishedAt,
      statusMark: statusMark ?? this.statusMark,
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
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (statusMark.present) {
      map['status_mark'] = Variable<String>(
        $BooksTable.$converterstatusMarkn.toSql(statusMark.value),
      );
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
          ..write('coverFile: $coverFile, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('statusMark: $statusMark')
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

class $CollectionsTable extends Collections
    with TableInfo<$CollectionsTable, CollectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collections';
  @override
  VerificationContext validateIntegrity(
    Insertable<CollectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CollectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CollectionsTable createAlias(String alias) {
    return $CollectionsTable(attachedDatabase, alias);
  }
}

class CollectionRow extends DataClass implements Insertable<CollectionRow> {
  final int id;
  final String name;
  final DateTime createdAt;
  const CollectionRow({
    required this.id,
    required this.name,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CollectionsCompanion toCompanion(bool nullToAbsent) {
    return CollectionsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory CollectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectionRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CollectionRow copyWith({int? id, String? name, DateTime? createdAt}) =>
      CollectionRow(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );
  CollectionRow copyWithCompanion(CollectionsCompanion data) {
    return CollectionRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectionRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectionRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class CollectionsCompanion extends UpdateCompanion<CollectionRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  const CollectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CollectionsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime createdAt,
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<CollectionRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CollectionsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
  }) {
    return CollectionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $BookCollectionsTable extends BookCollections
    with TableInfo<$BookCollectionsTable, BookCollectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookCollectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _collectionIdMeta = const VerificationMeta(
    'collectionId',
  );
  @override
  late final GeneratedColumn<int> collectionId = GeneratedColumn<int>(
    'collection_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES collections (id) ON DELETE CASCADE',
    ),
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
  @override
  List<GeneratedColumn> get $columns => [bookId, collectionId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_collections';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookCollectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('collection_id')) {
      context.handle(
        _collectionIdMeta,
        collectionId.isAcceptableOrUnknown(
          data['collection_id']!,
          _collectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, collectionId};
  @override
  BookCollectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookCollectionRow(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}book_id'],
      )!,
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}collection_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $BookCollectionsTable createAlias(String alias) {
    return $BookCollectionsTable(attachedDatabase, alias);
  }
}

class BookCollectionRow extends DataClass
    implements Insertable<BookCollectionRow> {
  final int bookId;
  final int collectionId;
  final DateTime addedAt;
  const BookCollectionRow({
    required this.bookId,
    required this.collectionId,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<int>(bookId);
    map['collection_id'] = Variable<int>(collectionId);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  BookCollectionsCompanion toCompanion(bool nullToAbsent) {
    return BookCollectionsCompanion(
      bookId: Value(bookId),
      collectionId: Value(collectionId),
      addedAt: Value(addedAt),
    );
  }

  factory BookCollectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookCollectionRow(
      bookId: serializer.fromJson<int>(json['bookId']),
      collectionId: serializer.fromJson<int>(json['collectionId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<int>(bookId),
      'collectionId': serializer.toJson<int>(collectionId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  BookCollectionRow copyWith({
    int? bookId,
    int? collectionId,
    DateTime? addedAt,
  }) => BookCollectionRow(
    bookId: bookId ?? this.bookId,
    collectionId: collectionId ?? this.collectionId,
    addedAt: addedAt ?? this.addedAt,
  );
  BookCollectionRow copyWithCompanion(BookCollectionsCompanion data) {
    return BookCollectionRow(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookCollectionRow(')
          ..write('bookId: $bookId, ')
          ..write('collectionId: $collectionId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, collectionId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookCollectionRow &&
          other.bookId == this.bookId &&
          other.collectionId == this.collectionId &&
          other.addedAt == this.addedAt);
}

class BookCollectionsCompanion extends UpdateCompanion<BookCollectionRow> {
  final Value<int> bookId;
  final Value<int> collectionId;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const BookCollectionsCompanion({
    this.bookId = const Value.absent(),
    this.collectionId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookCollectionsCompanion.insert({
    required int bookId,
    required int collectionId,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       collectionId = Value(collectionId),
       addedAt = Value(addedAt);
  static Insertable<BookCollectionRow> custom({
    Expression<int>? bookId,
    Expression<int>? collectionId,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (collectionId != null) 'collection_id': collectionId,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookCollectionsCompanion copyWith({
    Value<int>? bookId,
    Value<int>? collectionId,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return BookCollectionsCompanion(
      bookId: bookId ?? this.bookId,
      collectionId: collectionId ?? this.collectionId,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (collectionId.present) {
      map['collection_id'] = Variable<int>(collectionId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookCollectionsCompanion(')
          ..write('bookId: $bookId, ')
          ..write('collectionId: $collectionId, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FoldersTable extends Folders with TableInfo<$FoldersTable, FolderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
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
  @override
  late final GeneratedColumnWithTypeConverter<FolderKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<FolderKind>($FoldersTable.$converterkind);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _refMeta = const VerificationMeta('ref');
  @override
  late final GeneratedColumn<String> ref = GeneratedColumn<String>(
    'ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _scannedAtMeta = const VerificationMeta(
    'scannedAt',
  );
  @override
  late final GeneratedColumn<DateTime> scannedAt = GeneratedColumn<DateTime>(
    'scanned_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lostMeta = const VerificationMeta('lost');
  @override
  late final GeneratedColumn<bool> lost = GeneratedColumn<bool>(
    'lost',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("lost" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _tooBigMeta = const VerificationMeta('tooBig');
  @override
  late final GeneratedColumn<bool> tooBig = GeneratedColumn<bool>(
    'too_big',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("too_big" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _collectionIdMeta = const VerificationMeta(
    'collectionId',
  );
  @override
  late final GeneratedColumn<int> collectionId = GeneratedColumn<int>(
    'collection_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES collections (id) ON DELETE SET NULL',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    name,
    ref,
    addedAt,
    scannedAt,
    lost,
    tooBig,
    collectionId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<FolderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('ref')) {
      context.handle(
        _refMeta,
        ref.isAcceptableOrUnknown(data['ref']!, _refMeta),
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
    if (data.containsKey('scanned_at')) {
      context.handle(
        _scannedAtMeta,
        scannedAt.isAcceptableOrUnknown(data['scanned_at']!, _scannedAtMeta),
      );
    }
    if (data.containsKey('lost')) {
      context.handle(
        _lostMeta,
        lost.isAcceptableOrUnknown(data['lost']!, _lostMeta),
      );
    }
    if (data.containsKey('too_big')) {
      context.handle(
        _tooBigMeta,
        tooBig.isAcceptableOrUnknown(data['too_big']!, _tooBigMeta),
      );
    }
    if (data.containsKey('collection_id')) {
      context.handle(
        _collectionIdMeta,
        collectionId.isAcceptableOrUnknown(
          data['collection_id']!,
          _collectionIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FolderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FolderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: $FoldersTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      ref: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      scannedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scanned_at'],
      ),
      lost: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}lost'],
      )!,
      tooBig: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}too_big'],
      )!,
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}collection_id'],
      ),
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<FolderKind, String, String> $converterkind =
      const EnumNameConverter<FolderKind>(FolderKind.values);
}

class FolderRow extends DataClass implements Insertable<FolderRow> {
  final int id;
  final FolderKind kind;
  final String name;

  /// Opaque handle from the platform (Android tree URI, iOS bookmark);
  /// null for the own folder.
  final String? ref;
  final DateTime addedAt;
  final DateTime? scannedAt;

  /// No access any more: books stay, the owner can pick the folder again.
  final bool lost;

  /// The last scan found more books than the limit and took only some.
  final bool tooBig;

  /// Books from the folder also go to this collection; null — nowhere.
  final int? collectionId;
  const FolderRow({
    required this.id,
    required this.kind,
    required this.name,
    this.ref,
    required this.addedAt,
    this.scannedAt,
    required this.lost,
    required this.tooBig,
    this.collectionId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['kind'] = Variable<String>($FoldersTable.$converterkind.toSql(kind));
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || ref != null) {
      map['ref'] = Variable<String>(ref);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || scannedAt != null) {
      map['scanned_at'] = Variable<DateTime>(scannedAt);
    }
    map['lost'] = Variable<bool>(lost);
    map['too_big'] = Variable<bool>(tooBig);
    if (!nullToAbsent || collectionId != null) {
      map['collection_id'] = Variable<int>(collectionId);
    }
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      id: Value(id),
      kind: Value(kind),
      name: Value(name),
      ref: ref == null && nullToAbsent ? const Value.absent() : Value(ref),
      addedAt: Value(addedAt),
      scannedAt: scannedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(scannedAt),
      lost: Value(lost),
      tooBig: Value(tooBig),
      collectionId: collectionId == null && nullToAbsent
          ? const Value.absent()
          : Value(collectionId),
    );
  }

  factory FolderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FolderRow(
      id: serializer.fromJson<int>(json['id']),
      kind: $FoldersTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      name: serializer.fromJson<String>(json['name']),
      ref: serializer.fromJson<String?>(json['ref']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      scannedAt: serializer.fromJson<DateTime?>(json['scannedAt']),
      lost: serializer.fromJson<bool>(json['lost']),
      tooBig: serializer.fromJson<bool>(json['tooBig']),
      collectionId: serializer.fromJson<int?>(json['collectionId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(
        $FoldersTable.$converterkind.toJson(kind),
      ),
      'name': serializer.toJson<String>(name),
      'ref': serializer.toJson<String?>(ref),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'scannedAt': serializer.toJson<DateTime?>(scannedAt),
      'lost': serializer.toJson<bool>(lost),
      'tooBig': serializer.toJson<bool>(tooBig),
      'collectionId': serializer.toJson<int?>(collectionId),
    };
  }

  FolderRow copyWith({
    int? id,
    FolderKind? kind,
    String? name,
    Value<String?> ref = const Value.absent(),
    DateTime? addedAt,
    Value<DateTime?> scannedAt = const Value.absent(),
    bool? lost,
    bool? tooBig,
    Value<int?> collectionId = const Value.absent(),
  }) => FolderRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    ref: ref.present ? ref.value : this.ref,
    addedAt: addedAt ?? this.addedAt,
    scannedAt: scannedAt.present ? scannedAt.value : this.scannedAt,
    lost: lost ?? this.lost,
    tooBig: tooBig ?? this.tooBig,
    collectionId: collectionId.present ? collectionId.value : this.collectionId,
  );
  FolderRow copyWithCompanion(FoldersCompanion data) {
    return FolderRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      ref: data.ref.present ? data.ref.value : this.ref,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      scannedAt: data.scannedAt.present ? data.scannedAt.value : this.scannedAt,
      lost: data.lost.present ? data.lost.value : this.lost,
      tooBig: data.tooBig.present ? data.tooBig.value : this.tooBig,
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FolderRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('ref: $ref, ')
          ..write('addedAt: $addedAt, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('lost: $lost, ')
          ..write('tooBig: $tooBig, ')
          ..write('collectionId: $collectionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    name,
    ref,
    addedAt,
    scannedAt,
    lost,
    tooBig,
    collectionId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FolderRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.ref == this.ref &&
          other.addedAt == this.addedAt &&
          other.scannedAt == this.scannedAt &&
          other.lost == this.lost &&
          other.tooBig == this.tooBig &&
          other.collectionId == this.collectionId);
}

class FoldersCompanion extends UpdateCompanion<FolderRow> {
  final Value<int> id;
  final Value<FolderKind> kind;
  final Value<String> name;
  final Value<String?> ref;
  final Value<DateTime> addedAt;
  final Value<DateTime?> scannedAt;
  final Value<bool> lost;
  final Value<bool> tooBig;
  final Value<int?> collectionId;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.ref = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.scannedAt = const Value.absent(),
    this.lost = const Value.absent(),
    this.tooBig = const Value.absent(),
    this.collectionId = const Value.absent(),
  });
  FoldersCompanion.insert({
    this.id = const Value.absent(),
    required FolderKind kind,
    required String name,
    this.ref = const Value.absent(),
    required DateTime addedAt,
    this.scannedAt = const Value.absent(),
    this.lost = const Value.absent(),
    this.tooBig = const Value.absent(),
    this.collectionId = const Value.absent(),
  }) : kind = Value(kind),
       name = Value(name),
       addedAt = Value(addedAt);
  static Insertable<FolderRow> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? ref,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? scannedAt,
    Expression<bool>? lost,
    Expression<bool>? tooBig,
    Expression<int>? collectionId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (ref != null) 'ref': ref,
      if (addedAt != null) 'added_at': addedAt,
      if (scannedAt != null) 'scanned_at': scannedAt,
      if (lost != null) 'lost': lost,
      if (tooBig != null) 'too_big': tooBig,
      if (collectionId != null) 'collection_id': collectionId,
    });
  }

  FoldersCompanion copyWith({
    Value<int>? id,
    Value<FolderKind>? kind,
    Value<String>? name,
    Value<String?>? ref,
    Value<DateTime>? addedAt,
    Value<DateTime?>? scannedAt,
    Value<bool>? lost,
    Value<bool>? tooBig,
    Value<int?>? collectionId,
  }) {
    return FoldersCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      ref: ref ?? this.ref,
      addedAt: addedAt ?? this.addedAt,
      scannedAt: scannedAt ?? this.scannedAt,
      lost: lost ?? this.lost,
      tooBig: tooBig ?? this.tooBig,
      collectionId: collectionId ?? this.collectionId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $FoldersTable.$converterkind.toSql(kind.value),
      );
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (ref.present) {
      map['ref'] = Variable<String>(ref.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (scannedAt.present) {
      map['scanned_at'] = Variable<DateTime>(scannedAt.value);
    }
    if (lost.present) {
      map['lost'] = Variable<bool>(lost.value);
    }
    if (tooBig.present) {
      map['too_big'] = Variable<bool>(tooBig.value);
    }
    if (collectionId.present) {
      map['collection_id'] = Variable<int>(collectionId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('ref: $ref, ')
          ..write('addedAt: $addedAt, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('lost: $lost, ')
          ..write('tooBig: $tooBig, ')
          ..write('collectionId: $collectionId')
          ..write(')'))
        .toString();
  }
}

class $FolderFilesTable extends FolderFiles
    with TableInfo<$FolderFilesTable, FolderFileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FolderFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<int> folderId = GeneratedColumn<int>(
    'folder_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES folders (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifiedMeta = const VerificationMeta(
    'modified',
  );
  @override
  late final GeneratedColumn<int> modified = GeneratedColumn<int>(
    'modified',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seenAtMeta = const VerificationMeta('seenAt');
  @override
  late final GeneratedColumn<DateTime> seenAt = GeneratedColumn<DateTime>(
    'seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [folderId, key, size, modified, seenAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folder_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<FolderFileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_folderIdMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('modified')) {
      context.handle(
        _modifiedMeta,
        modified.isAcceptableOrUnknown(data['modified']!, _modifiedMeta),
      );
    } else if (isInserting) {
      context.missing(_modifiedMeta);
    }
    if (data.containsKey('seen_at')) {
      context.handle(
        _seenAtMeta,
        seenAt.isAcceptableOrUnknown(data['seen_at']!, _seenAtMeta),
      );
    } else if (isInserting) {
      context.missing(_seenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {folderId, key};
  @override
  FolderFileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FolderFileRow(
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}folder_id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      modified: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modified'],
      )!,
      seenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}seen_at'],
      )!,
    );
  }

  @override
  $FolderFilesTable createAlias(String alias) {
    return $FolderFilesTable(attachedDatabase, alias);
  }
}

class FolderFileRow extends DataClass implements Insertable<FolderFileRow> {
  final int folderId;

  /// Path inside the folder (or Android document id).
  final String key;
  final int size;

  /// Change time in milliseconds; 0 — unknown, compare by size only.
  final int modified;
  final DateTime seenAt;
  const FolderFileRow({
    required this.folderId,
    required this.key,
    required this.size,
    required this.modified,
    required this.seenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['folder_id'] = Variable<int>(folderId);
    map['key'] = Variable<String>(key);
    map['size'] = Variable<int>(size);
    map['modified'] = Variable<int>(modified);
    map['seen_at'] = Variable<DateTime>(seenAt);
    return map;
  }

  FolderFilesCompanion toCompanion(bool nullToAbsent) {
    return FolderFilesCompanion(
      folderId: Value(folderId),
      key: Value(key),
      size: Value(size),
      modified: Value(modified),
      seenAt: Value(seenAt),
    );
  }

  factory FolderFileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FolderFileRow(
      folderId: serializer.fromJson<int>(json['folderId']),
      key: serializer.fromJson<String>(json['key']),
      size: serializer.fromJson<int>(json['size']),
      modified: serializer.fromJson<int>(json['modified']),
      seenAt: serializer.fromJson<DateTime>(json['seenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'folderId': serializer.toJson<int>(folderId),
      'key': serializer.toJson<String>(key),
      'size': serializer.toJson<int>(size),
      'modified': serializer.toJson<int>(modified),
      'seenAt': serializer.toJson<DateTime>(seenAt),
    };
  }

  FolderFileRow copyWith({
    int? folderId,
    String? key,
    int? size,
    int? modified,
    DateTime? seenAt,
  }) => FolderFileRow(
    folderId: folderId ?? this.folderId,
    key: key ?? this.key,
    size: size ?? this.size,
    modified: modified ?? this.modified,
    seenAt: seenAt ?? this.seenAt,
  );
  FolderFileRow copyWithCompanion(FolderFilesCompanion data) {
    return FolderFileRow(
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      key: data.key.present ? data.key.value : this.key,
      size: data.size.present ? data.size.value : this.size,
      modified: data.modified.present ? data.modified.value : this.modified,
      seenAt: data.seenAt.present ? data.seenAt.value : this.seenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FolderFileRow(')
          ..write('folderId: $folderId, ')
          ..write('key: $key, ')
          ..write('size: $size, ')
          ..write('modified: $modified, ')
          ..write('seenAt: $seenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(folderId, key, size, modified, seenAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FolderFileRow &&
          other.folderId == this.folderId &&
          other.key == this.key &&
          other.size == this.size &&
          other.modified == this.modified &&
          other.seenAt == this.seenAt);
}

class FolderFilesCompanion extends UpdateCompanion<FolderFileRow> {
  final Value<int> folderId;
  final Value<String> key;
  final Value<int> size;
  final Value<int> modified;
  final Value<DateTime> seenAt;
  final Value<int> rowid;
  const FolderFilesCompanion({
    this.folderId = const Value.absent(),
    this.key = const Value.absent(),
    this.size = const Value.absent(),
    this.modified = const Value.absent(),
    this.seenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FolderFilesCompanion.insert({
    required int folderId,
    required String key,
    required int size,
    required int modified,
    required DateTime seenAt,
    this.rowid = const Value.absent(),
  }) : folderId = Value(folderId),
       key = Value(key),
       size = Value(size),
       modified = Value(modified),
       seenAt = Value(seenAt);
  static Insertable<FolderFileRow> custom({
    Expression<int>? folderId,
    Expression<String>? key,
    Expression<int>? size,
    Expression<int>? modified,
    Expression<DateTime>? seenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (folderId != null) 'folder_id': folderId,
      if (key != null) 'key': key,
      if (size != null) 'size': size,
      if (modified != null) 'modified': modified,
      if (seenAt != null) 'seen_at': seenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FolderFilesCompanion copyWith({
    Value<int>? folderId,
    Value<String>? key,
    Value<int>? size,
    Value<int>? modified,
    Value<DateTime>? seenAt,
    Value<int>? rowid,
  }) {
    return FolderFilesCompanion(
      folderId: folderId ?? this.folderId,
      key: key ?? this.key,
      size: size ?? this.size,
      modified: modified ?? this.modified,
      seenAt: seenAt ?? this.seenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (folderId.present) {
      map['folder_id'] = Variable<int>(folderId.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (modified.present) {
      map['modified'] = Variable<int>(modified.value);
    }
    if (seenAt.present) {
      map['seen_at'] = Variable<DateTime>(seenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FolderFilesCompanion(')
          ..write('folderId: $folderId, ')
          ..write('key: $key, ')
          ..write('size: $size, ')
          ..write('modified: $modified, ')
          ..write('seenAt: $seenAt, ')
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
  late final $CollectionsTable collections = $CollectionsTable(this);
  late final $BookCollectionsTable bookCollections = $BookCollectionsTable(
    this,
  );
  late final $FoldersTable folders = $FoldersTable(this);
  late final $FolderFilesTable folderFiles = $FolderFilesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    books,
    appSettings,
    collections,
    bookCollections,
    folders,
    folderFiles,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'books',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('book_collections', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'collections',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('book_collections', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'collections',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('folders', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'folders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('folder_files', kind: UpdateKind.delete)],
    ),
  ]);
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
  Value<DateTime?> finishedAt,
  Value<StatusMark?> statusMark,
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
  Value<DateTime?> finishedAt,
  Value<StatusMark?> statusMark,
});

final class $$BooksTableReferences
    extends BaseReferences<_$AppDatabase, $BooksTable, BookRow> {
  $$BooksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BookCollectionsTable, List<BookCollectionRow>>
  _bookCollectionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bookCollections,
    aliasName: 'books__id__book_collections__book_id',
  );

  $$BookCollectionsTableProcessedTableManager get bookCollectionsRefs {
    final manager = $$BookCollectionsTableTableManager(
      $_db,
      $_db.bookCollections,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _bookCollectionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

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

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<StatusMark?, StatusMark, String>
  get statusMark => $composableBuilder(
    column: $table.statusMark,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  Expression<bool> bookCollectionsRefs(
    Expression<bool> Function($$BookCollectionsTableFilterComposer f) f,
  ) {
    final $$BookCollectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookCollections,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookCollectionsTableFilterComposer(
            $db: $db,
            $table: $db.bookCollections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
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

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statusMark => $composableBuilder(
    column: $table.statusMark,
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

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<StatusMark?, String> get statusMark =>
      $composableBuilder(
        column: $table.statusMark,
        builder: (column) => column,
      );

  Expression<T> bookCollectionsRefs<T extends Object>(
    Expression<T> Function($$BookCollectionsTableAnnotationComposer a) f,
  ) {
    final $$BookCollectionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookCollections,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookCollectionsTableAnnotationComposer(
            $db: $db,
            $table: $db.bookCollections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
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
          (BookRow, $$BooksTableReferences),
          BookRow,
          PrefetchHooks Function({bool bookCollectionsRefs})
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
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<StatusMark?> statusMark = const Value.absent(),
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
                finishedAt: finishedAt,
                statusMark: statusMark,
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
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<StatusMark?> statusMark = const Value.absent(),
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
                finishedAt: finishedAt,
                statusMark: statusMark,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BooksTable, BookRow>(table),
                  $$BooksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookCollectionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (bookCollectionsRefs) db.bookCollections,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (bookCollectionsRefs)
                    await $_getPrefetchedData<
                      BookRow,
                      $BooksTable,
                      BookCollectionRow
                    >(
                      currentTable: table,
                      referencedTable: $$BooksTableReferences
                          ._bookCollectionsRefsTable(db),
                      managerFromTypedResult: (p0) => $$BooksTableReferences(
                        db,
                        table,
                        p0,
                      ).bookCollectionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.bookId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
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
      (BookRow, $$BooksTableReferences),
      BookRow,
      PrefetchHooks Function({bool bookCollectionsRefs})
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
typedef $$CollectionsTableCreateCompanionBuilder =
    CollectionsCompanion Function({
      Value<int> id,
      required String name,
      required DateTime createdAt,
    });
typedef $$CollectionsTableUpdateCompanionBuilder =
    CollectionsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<DateTime> createdAt,
    });

final class $$CollectionsTableReferences
    extends BaseReferences<_$AppDatabase, $CollectionsTable, CollectionRow> {
  $$CollectionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BookCollectionsTable, List<BookCollectionRow>>
  _bookCollectionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bookCollections,
    aliasName: 'collections__id__book_collections__collection_id',
  );

  $$BookCollectionsTableProcessedTableManager get bookCollectionsRefs {
    final manager = $$BookCollectionsTableTableManager(
      $_db,
      $_db.bookCollections,
    ).filter((f) => f.collectionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _bookCollectionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FoldersTable, List<FolderRow>> _foldersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.folders,
    aliasName: 'collections__id__folders__collection_id',
  );

  $$FoldersTableProcessedTableManager get foldersRefs {
    final manager = $$FoldersTableTableManager(
      $_db,
      $_db.folders,
    ).filter((f) => f.collectionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_foldersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CollectionsTableFilterComposer
    extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> bookCollectionsRefs(
    Expression<bool> Function($$BookCollectionsTableFilterComposer f) f,
  ) {
    final $$BookCollectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookCollections,
      getReferencedColumn: (t) => t.collectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookCollectionsTableFilterComposer(
            $db: $db,
            $table: $db.bookCollections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> foldersRefs(
    Expression<bool> Function($$FoldersTableFilterComposer f) f,
  ) {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.collectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableFilterComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CollectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CollectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> bookCollectionsRefs<T extends Object>(
    Expression<T> Function($$BookCollectionsTableAnnotationComposer a) f,
  ) {
    final $$BookCollectionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookCollections,
      getReferencedColumn: (t) => t.collectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookCollectionsTableAnnotationComposer(
            $db: $db,
            $table: $db.bookCollections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> foldersRefs<T extends Object>(
    Expression<T> Function($$FoldersTableAnnotationComposer a) f,
  ) {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.collectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CollectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CollectionsTable,
          CollectionRow,
          $$CollectionsTableFilterComposer,
          $$CollectionsTableOrderingComposer,
          $$CollectionsTableAnnotationComposer,
          $$CollectionsTableCreateCompanionBuilder,
          $$CollectionsTableUpdateCompanionBuilder,
          (CollectionRow, $$CollectionsTableReferences),
          CollectionRow,
          PrefetchHooks Function({bool bookCollectionsRefs, bool foldersRefs})
        > {
  $$CollectionsTableTableManager(_$AppDatabase db, $CollectionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) => CollectionsCompanion(id: id, name: name, createdAt: createdAt),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required DateTime createdAt,
              }) => CollectionsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CollectionsTable, CollectionRow>(table),
                  $$CollectionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({bookCollectionsRefs = false, foldersRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (bookCollectionsRefs) db.bookCollections,
                    if (foldersRefs) db.folders,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (bookCollectionsRefs)
                        await $_getPrefetchedData<
                          CollectionRow,
                          $CollectionsTable,
                          BookCollectionRow
                        >(
                          currentTable: table,
                          referencedTable: $$CollectionsTableReferences
                              ._bookCollectionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CollectionsTableReferences(
                                db,
                                table,
                                p0,
                              ).bookCollectionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.collectionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (foldersRefs)
                        await $_getPrefetchedData<
                          CollectionRow,
                          $CollectionsTable,
                          FolderRow
                        >(
                          currentTable: table,
                          referencedTable: $$CollectionsTableReferences
                              ._foldersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CollectionsTableReferences(
                                db,
                                table,
                                p0,
                              ).foldersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.collectionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CollectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CollectionsTable,
      CollectionRow,
      $$CollectionsTableFilterComposer,
      $$CollectionsTableOrderingComposer,
      $$CollectionsTableAnnotationComposer,
      $$CollectionsTableCreateCompanionBuilder,
      $$CollectionsTableUpdateCompanionBuilder,
      (CollectionRow, $$CollectionsTableReferences),
      CollectionRow,
      PrefetchHooks Function({bool bookCollectionsRefs, bool foldersRefs})
    >;
typedef $$BookCollectionsTableCreateCompanionBuilder =
    BookCollectionsCompanion Function({
      required int bookId,
      required int collectionId,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$BookCollectionsTableUpdateCompanionBuilder =
    BookCollectionsCompanion Function({
      Value<int> bookId,
      Value<int> collectionId,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

final class $$BookCollectionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $BookCollectionsTable,
          BookCollectionRow
        > {
  $$BookCollectionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('book_collections__book_id__books__id');

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<int>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CollectionsTable _collectionIdTable(_$AppDatabase db) => db
      .collections
      .createAlias('book_collections__collection_id__collections__id');

  $$CollectionsTableProcessedTableManager get collectionId {
    final $_column = $_itemColumn<int>('collection_id')!;

    final manager = $$CollectionsTableTableManager(
      $_db,
      $_db.collections,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_collectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BookCollectionsTableFilterComposer
    extends Composer<_$AppDatabase, $BookCollectionsTable> {
  $$BookCollectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CollectionsTableFilterComposer get collectionId {
    final $$CollectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableFilterComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookCollectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $BookCollectionsTable> {
  $$BookCollectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CollectionsTableOrderingComposer get collectionId {
    final $$CollectionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableOrderingComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookCollectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookCollectionsTable> {
  $$BookCollectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CollectionsTableAnnotationComposer get collectionId {
    final $$CollectionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableAnnotationComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookCollectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookCollectionsTable,
          BookCollectionRow,
          $$BookCollectionsTableFilterComposer,
          $$BookCollectionsTableOrderingComposer,
          $$BookCollectionsTableAnnotationComposer,
          $$BookCollectionsTableCreateCompanionBuilder,
          $$BookCollectionsTableUpdateCompanionBuilder,
          (BookCollectionRow, $$BookCollectionsTableReferences),
          BookCollectionRow,
          PrefetchHooks Function({bool bookId, bool collectionId})
        > {
  $$BookCollectionsTableTableManager(
    _$AppDatabase db,
    $BookCollectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookCollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookCollectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookCollectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> bookId = const Value.absent(),
                Value<int> collectionId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookCollectionsCompanion(
                bookId: bookId,
                collectionId: collectionId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int bookId,
                required int collectionId,
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => BookCollectionsCompanion.insert(
                bookId: bookId,
                collectionId: collectionId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BookCollectionsTable, BookCollectionRow>(table),
                  $$BookCollectionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false, collectionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.bookId,
                        referencedTable: $$BookCollectionsTableReferences
                            ._bookIdTable(db),
                        referencedColumn: $$BookCollectionsTableReferences
                            ._bookIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (collectionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.collectionId,
                        referencedTable: $$BookCollectionsTableReferences
                            ._collectionIdTable(db),
                        referencedColumn: $$BookCollectionsTableReferences
                            ._collectionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BookCollectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookCollectionsTable,
      BookCollectionRow,
      $$BookCollectionsTableFilterComposer,
      $$BookCollectionsTableOrderingComposer,
      $$BookCollectionsTableAnnotationComposer,
      $$BookCollectionsTableCreateCompanionBuilder,
      $$BookCollectionsTableUpdateCompanionBuilder,
      (BookCollectionRow, $$BookCollectionsTableReferences),
      BookCollectionRow,
      PrefetchHooks Function({bool bookId, bool collectionId})
    >;
typedef $$FoldersTableCreateCompanionBuilder = FoldersCompanion Function({
  Value<int> id,
  required FolderKind kind,
  required String name,
  Value<String?> ref,
  required DateTime addedAt,
  Value<DateTime?> scannedAt,
  Value<bool> lost,
  Value<bool> tooBig,
  Value<int?> collectionId,
});
typedef $$FoldersTableUpdateCompanionBuilder = FoldersCompanion Function({
  Value<int> id,
  Value<FolderKind> kind,
  Value<String> name,
  Value<String?> ref,
  Value<DateTime> addedAt,
  Value<DateTime?> scannedAt,
  Value<bool> lost,
  Value<bool> tooBig,
  Value<int?> collectionId,
});

final class $$FoldersTableReferences
    extends BaseReferences<_$AppDatabase, $FoldersTable, FolderRow> {
  $$FoldersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CollectionsTable _collectionIdTable(_$AppDatabase db) =>
      db.collections.createAlias('folders__collection_id__collections__id');

  $$CollectionsTableProcessedTableManager? get collectionId {
    final $_column = $_itemColumn<int>('collection_id');
    if ($_column == null) return null;
    final manager = $$CollectionsTableTableManager(
      $_db,
      $_db.collections,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_collectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$FolderFilesTable, List<FolderFileRow>>
  _folderFilesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.folderFiles,
    aliasName: 'folders__id__folder_files__folder_id',
  );

  $$FolderFilesTableProcessedTableManager get folderFilesRefs {
    final manager = $$FolderFilesTableTableManager(
      $_db,
      $_db.folderFiles,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_folderFilesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FoldersTableFilterComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableFilterComposer({
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

  ColumnWithTypeConverterFilters<FolderKind, FolderKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ref => $composableBuilder(
    column: $table.ref,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scannedAt => $composableBuilder(
    column: $table.scannedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get lost => $composableBuilder(
    column: $table.lost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get tooBig => $composableBuilder(
    column: $table.tooBig,
    builder: (column) => ColumnFilters(column),
  );

  $$CollectionsTableFilterComposer get collectionId {
    final $$CollectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableFilterComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> folderFilesRefs(
    Expression<bool> Function($$FolderFilesTableFilterComposer f) f,
  ) {
    final $$FolderFilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.folderFiles,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FolderFilesTableFilterComposer(
            $db: $db,
            $table: $db.folderFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ref => $composableBuilder(
    column: $table.ref,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scannedAt => $composableBuilder(
    column: $table.scannedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get lost => $composableBuilder(
    column: $table.lost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get tooBig => $composableBuilder(
    column: $table.tooBig,
    builder: (column) => ColumnOrderings(column),
  );

  $$CollectionsTableOrderingComposer get collectionId {
    final $$CollectionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableOrderingComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<FolderKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get ref =>
      $composableBuilder(column: $table.ref, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get scannedAt =>
      $composableBuilder(column: $table.scannedAt, builder: (column) => column);

  GeneratedColumn<bool> get lost =>
      $composableBuilder(column: $table.lost, builder: (column) => column);

  GeneratedColumn<bool> get tooBig =>
      $composableBuilder(column: $table.tooBig, builder: (column) => column);

  $$CollectionsTableAnnotationComposer get collectionId {
    final $$CollectionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableAnnotationComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> folderFilesRefs<T extends Object>(
    Expression<T> Function($$FolderFilesTableAnnotationComposer a) f,
  ) {
    final $$FolderFilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.folderFiles,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FolderFilesTableAnnotationComposer(
            $db: $db,
            $table: $db.folderFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoldersTable,
          FolderRow,
          $$FoldersTableFilterComposer,
          $$FoldersTableOrderingComposer,
          $$FoldersTableAnnotationComposer,
          $$FoldersTableCreateCompanionBuilder,
          $$FoldersTableUpdateCompanionBuilder,
          (FolderRow, $$FoldersTableReferences),
          FolderRow,
          PrefetchHooks Function({bool collectionId, bool folderFilesRefs})
        > {
  $$FoldersTableTableManager(_$AppDatabase db, $FoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<FolderKind> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> ref = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> scannedAt = const Value.absent(),
                Value<bool> lost = const Value.absent(),
                Value<bool> tooBig = const Value.absent(),
                Value<int?> collectionId = const Value.absent(),
              }) => FoldersCompanion(
                id: id,
                kind: kind,
                name: name,
                ref: ref,
                addedAt: addedAt,
                scannedAt: scannedAt,
                lost: lost,
                tooBig: tooBig,
                collectionId: collectionId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required FolderKind kind,
                required String name,
                Value<String?> ref = const Value.absent(),
                required DateTime addedAt,
                Value<DateTime?> scannedAt = const Value.absent(),
                Value<bool> lost = const Value.absent(),
                Value<bool> tooBig = const Value.absent(),
                Value<int?> collectionId = const Value.absent(),
              }) => FoldersCompanion.insert(
                id: id,
                kind: kind,
                name: name,
                ref: ref,
                addedAt: addedAt,
                scannedAt: scannedAt,
                lost: lost,
                tooBig: tooBig,
                collectionId: collectionId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FoldersTable, FolderRow>(table),
                  $$FoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({collectionId = false, folderFilesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (folderFilesRefs) db.folderFiles,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (collectionId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.collectionId,
                            referencedTable: $$FoldersTableReferences
                                ._collectionIdTable(db),
                            referencedColumn: $$FoldersTableReferences
                                ._collectionIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (folderFilesRefs)
                        await $_getPrefetchedData<
                          FolderRow,
                          $FoldersTable,
                          FolderFileRow
                        >(
                          currentTable: table,
                          referencedTable: $$FoldersTableReferences
                              ._folderFilesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FoldersTableReferences(
                                db,
                                table,
                                p0,
                              ).folderFilesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.folderId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoldersTable,
      FolderRow,
      $$FoldersTableFilterComposer,
      $$FoldersTableOrderingComposer,
      $$FoldersTableAnnotationComposer,
      $$FoldersTableCreateCompanionBuilder,
      $$FoldersTableUpdateCompanionBuilder,
      (FolderRow, $$FoldersTableReferences),
      FolderRow,
      PrefetchHooks Function({bool collectionId, bool folderFilesRefs})
    >;
typedef $$FolderFilesTableCreateCompanionBuilder =
    FolderFilesCompanion Function({
      required int folderId,
      required String key,
      required int size,
      required int modified,
      required DateTime seenAt,
      Value<int> rowid,
    });
typedef $$FolderFilesTableUpdateCompanionBuilder =
    FolderFilesCompanion Function({
      Value<int> folderId,
      Value<String> key,
      Value<int> size,
      Value<int> modified,
      Value<DateTime> seenAt,
      Value<int> rowid,
    });

final class $$FolderFilesTableReferences
    extends BaseReferences<_$AppDatabase, $FolderFilesTable, FolderFileRow> {
  $$FolderFilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FoldersTable _folderIdTable(_$AppDatabase db) =>
      db.folders.createAlias('folder_files__folder_id__folders__id');

  $$FoldersTableProcessedTableManager get folderId {
    final $_column = $_itemColumn<int>('folder_id')!;

    final manager = $$FoldersTableTableManager(
      $_db,
      $_db.folders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FolderFilesTableFilterComposer
    extends Composer<_$AppDatabase, $FolderFilesTable> {
  $$FolderFilesTableFilterComposer({
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

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modified => $composableBuilder(
    column: $table.modified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get seenAt => $composableBuilder(
    column: $table.seenAt,
    builder: (column) => ColumnFilters(column),
  );

  $$FoldersTableFilterComposer get folderId {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableFilterComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FolderFilesTableOrderingComposer
    extends Composer<_$AppDatabase, $FolderFilesTable> {
  $$FolderFilesTableOrderingComposer({
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

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modified => $composableBuilder(
    column: $table.modified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get seenAt => $composableBuilder(
    column: $table.seenAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FoldersTableOrderingComposer get folderId {
    final $$FoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableOrderingComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FolderFilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FolderFilesTable> {
  $$FolderFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<int> get modified =>
      $composableBuilder(column: $table.modified, builder: (column) => column);

  GeneratedColumn<DateTime> get seenAt =>
      $composableBuilder(column: $table.seenAt, builder: (column) => column);

  $$FoldersTableAnnotationComposer get folderId {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FolderFilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FolderFilesTable,
          FolderFileRow,
          $$FolderFilesTableFilterComposer,
          $$FolderFilesTableOrderingComposer,
          $$FolderFilesTableAnnotationComposer,
          $$FolderFilesTableCreateCompanionBuilder,
          $$FolderFilesTableUpdateCompanionBuilder,
          (FolderFileRow, $$FolderFilesTableReferences),
          FolderFileRow,
          PrefetchHooks Function({bool folderId})
        > {
  $$FolderFilesTableTableManager(_$AppDatabase db, $FolderFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FolderFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FolderFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FolderFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> folderId = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int> modified = const Value.absent(),
                Value<DateTime> seenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FolderFilesCompanion(
                folderId: folderId,
                key: key,
                size: size,
                modified: modified,
                seenAt: seenAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int folderId,
                required String key,
                required int size,
                required int modified,
                required DateTime seenAt,
                Value<int> rowid = const Value.absent(),
              }) => FolderFilesCompanion.insert(
                folderId: folderId,
                key: key,
                size: size,
                modified: modified,
                seenAt: seenAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FolderFilesTable, FolderFileRow>(table),
                  $$FolderFilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({folderId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (folderId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.folderId,
                        referencedTable: $$FolderFilesTableReferences
                            ._folderIdTable(db),
                        referencedColumn: $$FolderFilesTableReferences
                            ._folderIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FolderFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FolderFilesTable,
      FolderFileRow,
      $$FolderFilesTableFilterComposer,
      $$FolderFilesTableOrderingComposer,
      $$FolderFilesTableAnnotationComposer,
      $$FolderFilesTableCreateCompanionBuilder,
      $$FolderFilesTableUpdateCompanionBuilder,
      (FolderFileRow, $$FolderFilesTableReferences),
      FolderFileRow,
      PrefetchHooks Function({bool folderId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$CollectionsTableTableManager get collections =>
      $$CollectionsTableTableManager(_db, _db.collections);
  $$BookCollectionsTableTableManager get bookCollections =>
      $$BookCollectionsTableTableManager(_db, _db.bookCollections);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$FolderFilesTableTableManager get folderFiles =>
      $$FolderFilesTableTableManager(_db, _db.folderFiles);
}

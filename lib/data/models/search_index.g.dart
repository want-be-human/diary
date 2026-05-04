// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_index.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSearchIndexCollection on Isar {
  IsarCollection<SearchIndex> get searchIndexs => this.collection();
}

const SearchIndexSchema = CollectionSchema(
  name: r'SearchIndex',
  id: 4768691469594422700,
  properties: {
    r'bodyTokens': PropertySchema(
      id: 0,
      name: r'bodyTokens',
      type: IsarType.string,
    ),
    r'category': PropertySchema(
      id: 1,
      name: r'category',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 2,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'entryId': PropertySchema(
      id: 3,
      name: r'entryId',
      type: IsarType.string,
    ),
    r'isPinned': PropertySchema(
      id: 4,
      name: r'isPinned',
      type: IsarType.bool,
    ),
    r'moodScore': PropertySchema(
      id: 5,
      name: r'moodScore',
      type: IsarType.long,
    ),
    r'projectName': PropertySchema(
      id: 6,
      name: r'projectName',
      type: IsarType.string,
    ),
    r'tags': PropertySchema(
      id: 7,
      name: r'tags',
      type: IsarType.string,
    ),
    r'titleTokens': PropertySchema(
      id: 8,
      name: r'titleTokens',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 9,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'wordCount': PropertySchema(
      id: 10,
      name: r'wordCount',
      type: IsarType.long,
    )
  },
  estimateSize: _searchIndexEstimateSize,
  serialize: _searchIndexSerialize,
  deserialize: _searchIndexDeserialize,
  deserializeProp: _searchIndexDeserializeProp,
  idName: r'isarId',
  indexes: {
    r'entryId': IndexSchema(
      id: 3733379884318738402,
      name: r'entryId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'entryId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'category': IndexSchema(
      id: -7560358558326323820,
      name: r'category',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'category',
          type: IndexType.value,
          caseSensitive: true,
        )
      ],
    ),
    r'titleTokens': IndexSchema(
      id: 2325608814300745520,
      name: r'titleTokens',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'titleTokens',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'bodyTokens': IndexSchema(
      id: 8922716944064119626,
      name: r'bodyTokens',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'bodyTokens',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'projectName': IndexSchema(
      id: 7457588439029069741,
      name: r'projectName',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'projectName',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'tags': IndexSchema(
      id: 4029205728550669204,
      name: r'tags',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'tags',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'createdAt': IndexSchema(
      id: -3433535483987302584,
      name: r'createdAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'createdAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'moodScore': IndexSchema(
      id: -55800858395767011,
      name: r'moodScore',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'moodScore',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'isPinned': IndexSchema(
      id: 7607338673446676027,
      name: r'isPinned',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isPinned',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'wordCount': IndexSchema(
      id: -6865332602315195179,
      name: r'wordCount',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'wordCount',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _searchIndexGetId,
  getLinks: _searchIndexGetLinks,
  attach: _searchIndexAttach,
  version: '3.1.0+1',
);

int _searchIndexEstimateSize(
  SearchIndex object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.bodyTokens.length * 3;
  bytesCount += 3 + object.category.length * 3;
  bytesCount += 3 + object.entryId.length * 3;
  {
    final value = object.projectName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.tags.length * 3;
  bytesCount += 3 + object.titleTokens.length * 3;
  return bytesCount;
}

void _searchIndexSerialize(
  SearchIndex object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.bodyTokens);
  writer.writeString(offsets[1], object.category);
  writer.writeDateTime(offsets[2], object.createdAt);
  writer.writeString(offsets[3], object.entryId);
  writer.writeBool(offsets[4], object.isPinned);
  writer.writeLong(offsets[5], object.moodScore);
  writer.writeString(offsets[6], object.projectName);
  writer.writeString(offsets[7], object.tags);
  writer.writeString(offsets[8], object.titleTokens);
  writer.writeDateTime(offsets[9], object.updatedAt);
  writer.writeLong(offsets[10], object.wordCount);
}

SearchIndex _searchIndexDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SearchIndex();
  object.bodyTokens = reader.readString(offsets[0]);
  object.category = reader.readString(offsets[1]);
  object.createdAt = reader.readDateTime(offsets[2]);
  object.entryId = reader.readString(offsets[3]);
  object.isPinned = reader.readBool(offsets[4]);
  object.isarId = id;
  object.moodScore = reader.readLongOrNull(offsets[5]);
  object.projectName = reader.readStringOrNull(offsets[6]);
  object.tags = reader.readString(offsets[7]);
  object.titleTokens = reader.readString(offsets[8]);
  object.updatedAt = reader.readDateTime(offsets[9]);
  object.wordCount = reader.readLong(offsets[10]);
  return object;
}

P _searchIndexDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readLongOrNull(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readDateTime(offset)) as P;
    case 10:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _searchIndexGetId(SearchIndex object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _searchIndexGetLinks(SearchIndex object) {
  return [];
}

void _searchIndexAttach(
    IsarCollection<dynamic> col, Id id, SearchIndex object) {
  object.isarId = id;
}

extension SearchIndexByIndex on IsarCollection<SearchIndex> {
  Future<SearchIndex?> getByEntryId(String entryId) {
    return getByIndex(r'entryId', [entryId]);
  }

  SearchIndex? getByEntryIdSync(String entryId) {
    return getByIndexSync(r'entryId', [entryId]);
  }

  Future<bool> deleteByEntryId(String entryId) {
    return deleteByIndex(r'entryId', [entryId]);
  }

  bool deleteByEntryIdSync(String entryId) {
    return deleteByIndexSync(r'entryId', [entryId]);
  }

  Future<List<SearchIndex?>> getAllByEntryId(List<String> entryIdValues) {
    final values = entryIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'entryId', values);
  }

  List<SearchIndex?> getAllByEntryIdSync(List<String> entryIdValues) {
    final values = entryIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'entryId', values);
  }

  Future<int> deleteAllByEntryId(List<String> entryIdValues) {
    final values = entryIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'entryId', values);
  }

  int deleteAllByEntryIdSync(List<String> entryIdValues) {
    final values = entryIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'entryId', values);
  }

  Future<Id> putByEntryId(SearchIndex object) {
    return putByIndex(r'entryId', object);
  }

  Id putByEntryIdSync(SearchIndex object, {bool saveLinks = true}) {
    return putByIndexSync(r'entryId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByEntryId(List<SearchIndex> objects) {
    return putAllByIndex(r'entryId', objects);
  }

  List<Id> putAllByEntryIdSync(List<SearchIndex> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'entryId', objects, saveLinks: saveLinks);
  }
}

extension SearchIndexQueryWhereSort
    on QueryBuilder<SearchIndex, SearchIndex, QWhere> {
  QueryBuilder<SearchIndex, SearchIndex, QAfterWhere> anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhere> anyCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'category'),
      );
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhere> anyTitleTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'titleTokens'),
      );
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhere> anyBodyTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'bodyTokens'),
      );
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhere> anyProjectName() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'projectName'),
      );
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhere> anyTags() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'tags'),
      );
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhere> anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhere> anyMoodScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'moodScore'),
      );
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhere> anyIsPinned() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isPinned'),
      );
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhere> anyWordCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'wordCount'),
      );
    });
  }
}

extension SearchIndexQueryWhere
    on QueryBuilder<SearchIndex, SearchIndex, QWhereClause> {
  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> isarIdEqualTo(
      Id isarId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: isarId,
        upper: isarId,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> isarIdNotEqualTo(
      Id isarId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> isarIdGreaterThan(
      Id isarId,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> isarIdLessThan(
      Id isarId,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> isarIdBetween(
    Id lowerIsarId,
    Id upperIsarId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerIsarId,
        includeLower: includeLower,
        upper: upperIsarId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> entryIdEqualTo(
      String entryId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'entryId',
        value: [entryId],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> entryIdNotEqualTo(
      String entryId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entryId',
              lower: [],
              upper: [entryId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entryId',
              lower: [entryId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entryId',
              lower: [entryId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entryId',
              lower: [],
              upper: [entryId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> categoryEqualTo(
      String category) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'category',
        value: [category],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> categoryNotEqualTo(
      String category) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'category',
              lower: [],
              upper: [category],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'category',
              lower: [category],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'category',
              lower: [category],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'category',
              lower: [],
              upper: [category],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> categoryGreaterThan(
    String category, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'category',
        lower: [category],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> categoryLessThan(
    String category, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'category',
        lower: [],
        upper: [category],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> categoryBetween(
    String lowerCategory,
    String upperCategory, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'category',
        lower: [lowerCategory],
        includeLower: includeLower,
        upper: [upperCategory],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> categoryStartsWith(
      String CategoryPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'category',
        lower: [CategoryPrefix],
        upper: ['$CategoryPrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> categoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'category',
        value: [''],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      categoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'category',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'category',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'category',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'category',
              upper: [''],
            ));
      }
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> titleTokensEqualTo(
      String titleTokens) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'titleTokens',
        value: [titleTokens],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      titleTokensNotEqualTo(String titleTokens) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'titleTokens',
              lower: [],
              upper: [titleTokens],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'titleTokens',
              lower: [titleTokens],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'titleTokens',
              lower: [titleTokens],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'titleTokens',
              lower: [],
              upper: [titleTokens],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      titleTokensGreaterThan(
    String titleTokens, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'titleTokens',
        lower: [titleTokens],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> titleTokensLessThan(
    String titleTokens, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'titleTokens',
        lower: [],
        upper: [titleTokens],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> titleTokensBetween(
    String lowerTitleTokens,
    String upperTitleTokens, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'titleTokens',
        lower: [lowerTitleTokens],
        includeLower: includeLower,
        upper: [upperTitleTokens],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      titleTokensStartsWith(String TitleTokensPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'titleTokens',
        lower: [TitleTokensPrefix],
        upper: ['$TitleTokensPrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      titleTokensIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'titleTokens',
        value: [''],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      titleTokensIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'titleTokens',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'titleTokens',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'titleTokens',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'titleTokens',
              upper: [''],
            ));
      }
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> bodyTokensEqualTo(
      String bodyTokens) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'bodyTokens',
        value: [bodyTokens],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      bodyTokensNotEqualTo(String bodyTokens) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'bodyTokens',
              lower: [],
              upper: [bodyTokens],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'bodyTokens',
              lower: [bodyTokens],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'bodyTokens',
              lower: [bodyTokens],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'bodyTokens',
              lower: [],
              upper: [bodyTokens],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      bodyTokensGreaterThan(
    String bodyTokens, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'bodyTokens',
        lower: [bodyTokens],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> bodyTokensLessThan(
    String bodyTokens, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'bodyTokens',
        lower: [],
        upper: [bodyTokens],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> bodyTokensBetween(
    String lowerBodyTokens,
    String upperBodyTokens, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'bodyTokens',
        lower: [lowerBodyTokens],
        includeLower: includeLower,
        upper: [upperBodyTokens],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      bodyTokensStartsWith(String BodyTokensPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'bodyTokens',
        lower: [BodyTokensPrefix],
        upper: ['$BodyTokensPrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      bodyTokensIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'bodyTokens',
        value: [''],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      bodyTokensIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'bodyTokens',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'bodyTokens',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'bodyTokens',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'bodyTokens',
              upper: [''],
            ));
      }
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      projectNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'projectName',
        value: [null],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      projectNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'projectName',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> projectNameEqualTo(
      String? projectName) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'projectName',
        value: [projectName],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      projectNameNotEqualTo(String? projectName) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'projectName',
              lower: [],
              upper: [projectName],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'projectName',
              lower: [projectName],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'projectName',
              lower: [projectName],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'projectName',
              lower: [],
              upper: [projectName],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      projectNameGreaterThan(
    String? projectName, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'projectName',
        lower: [projectName],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> projectNameLessThan(
    String? projectName, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'projectName',
        lower: [],
        upper: [projectName],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> projectNameBetween(
    String? lowerProjectName,
    String? upperProjectName, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'projectName',
        lower: [lowerProjectName],
        includeLower: includeLower,
        upper: [upperProjectName],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      projectNameStartsWith(String ProjectNamePrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'projectName',
        lower: [ProjectNamePrefix],
        upper: ['$ProjectNamePrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      projectNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'projectName',
        value: [''],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      projectNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'projectName',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'projectName',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'projectName',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'projectName',
              upper: [''],
            ));
      }
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> tagsEqualTo(
      String tags) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'tags',
        value: [tags],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> tagsNotEqualTo(
      String tags) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'tags',
              lower: [],
              upper: [tags],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'tags',
              lower: [tags],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'tags',
              lower: [tags],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'tags',
              lower: [],
              upper: [tags],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> tagsGreaterThan(
    String tags, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'tags',
        lower: [tags],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> tagsLessThan(
    String tags, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'tags',
        lower: [],
        upper: [tags],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> tagsBetween(
    String lowerTags,
    String upperTags, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'tags',
        lower: [lowerTags],
        includeLower: includeLower,
        upper: [upperTags],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> tagsStartsWith(
      String TagsPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'tags',
        lower: [TagsPrefix],
        upper: ['$TagsPrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> tagsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'tags',
        value: [''],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> tagsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'tags',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'tags',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'tags',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'tags',
              upper: [''],
            ));
      }
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> createdAtEqualTo(
      DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'createdAt',
        value: [createdAt],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> createdAtNotEqualTo(
      DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [],
              upper: [createdAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [createdAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [createdAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [],
              upper: [createdAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      createdAtGreaterThan(
    DateTime createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [createdAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> createdAtLessThan(
    DateTime createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [],
        upper: [createdAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> createdAtBetween(
    DateTime lowerCreatedAt,
    DateTime upperCreatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [lowerCreatedAt],
        includeLower: includeLower,
        upper: [upperCreatedAt],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> moodScoreIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'moodScore',
        value: [null],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      moodScoreIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'moodScore',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> moodScoreEqualTo(
      int? moodScore) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'moodScore',
        value: [moodScore],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> moodScoreNotEqualTo(
      int? moodScore) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'moodScore',
              lower: [],
              upper: [moodScore],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'moodScore',
              lower: [moodScore],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'moodScore',
              lower: [moodScore],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'moodScore',
              lower: [],
              upper: [moodScore],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      moodScoreGreaterThan(
    int? moodScore, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'moodScore',
        lower: [moodScore],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> moodScoreLessThan(
    int? moodScore, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'moodScore',
        lower: [],
        upper: [moodScore],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> moodScoreBetween(
    int? lowerMoodScore,
    int? upperMoodScore, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'moodScore',
        lower: [lowerMoodScore],
        includeLower: includeLower,
        upper: [upperMoodScore],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> isPinnedEqualTo(
      bool isPinned) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isPinned',
        value: [isPinned],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> isPinnedNotEqualTo(
      bool isPinned) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isPinned',
              lower: [],
              upper: [isPinned],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isPinned',
              lower: [isPinned],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isPinned',
              lower: [isPinned],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isPinned',
              lower: [],
              upper: [isPinned],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> wordCountEqualTo(
      int wordCount) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'wordCount',
        value: [wordCount],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> wordCountNotEqualTo(
      int wordCount) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'wordCount',
              lower: [],
              upper: [wordCount],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'wordCount',
              lower: [wordCount],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'wordCount',
              lower: [wordCount],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'wordCount',
              lower: [],
              upper: [wordCount],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause>
      wordCountGreaterThan(
    int wordCount, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'wordCount',
        lower: [wordCount],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> wordCountLessThan(
    int wordCount, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'wordCount',
        lower: [],
        upper: [wordCount],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> wordCountBetween(
    int lowerWordCount,
    int upperWordCount, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'wordCount',
        lower: [lowerWordCount],
        includeLower: includeLower,
        upper: [upperWordCount],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension SearchIndexQueryFilter
    on QueryBuilder<SearchIndex, SearchIndex, QFilterCondition> {
  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      bodyTokensEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'bodyTokens',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      bodyTokensGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'bodyTokens',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      bodyTokensLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'bodyTokens',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      bodyTokensBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'bodyTokens',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      bodyTokensStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'bodyTokens',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      bodyTokensEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'bodyTokens',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      bodyTokensContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'bodyTokens',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      bodyTokensMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'bodyTokens',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      bodyTokensIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'bodyTokens',
        value: '',
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      bodyTokensIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'bodyTokens',
        value: '',
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> categoryEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      categoryGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      categoryLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> categoryBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'category',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      categoryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      categoryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      categoryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> categoryMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'category',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      categoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'category',
        value: '',
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      categoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'category',
        value: '',
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> entryIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'entryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      entryIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'entryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> entryIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'entryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> entryIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'entryId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      entryIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'entryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> entryIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'entryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> entryIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'entryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> entryIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'entryId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      entryIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'entryId',
        value: '',
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      entryIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'entryId',
        value: '',
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> isPinnedEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isPinned',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> isarIdEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      isarIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> isarIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> isarIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'isarId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      moodScoreIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'moodScore',
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      moodScoreIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'moodScore',
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      moodScoreEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'moodScore',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      moodScoreGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'moodScore',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      moodScoreLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'moodScore',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      moodScoreBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'moodScore',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      projectNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'projectName',
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      projectNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'projectName',
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      projectNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'projectName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      projectNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'projectName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      projectNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'projectName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      projectNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'projectName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      projectNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'projectName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      projectNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'projectName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      projectNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'projectName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      projectNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'projectName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      projectNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'projectName',
        value: '',
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      projectNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'projectName',
        value: '',
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> tagsEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> tagsGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> tagsLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> tagsBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'tags',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> tagsStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> tagsEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> tagsContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> tagsMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'tags',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> tagsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tags',
        value: '',
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      tagsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'tags',
        value: '',
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      titleTokensEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'titleTokens',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      titleTokensGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'titleTokens',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      titleTokensLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'titleTokens',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      titleTokensBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'titleTokens',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      titleTokensStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'titleTokens',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      titleTokensEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'titleTokens',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      titleTokensContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'titleTokens',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      titleTokensMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'titleTokens',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      titleTokensIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'titleTokens',
        value: '',
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      titleTokensIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'titleTokens',
        value: '',
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      updatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      updatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      wordCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'wordCount',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      wordCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'wordCount',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      wordCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'wordCount',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      wordCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'wordCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension SearchIndexQueryObject
    on QueryBuilder<SearchIndex, SearchIndex, QFilterCondition> {}

extension SearchIndexQueryLinks
    on QueryBuilder<SearchIndex, SearchIndex, QFilterCondition> {}

extension SearchIndexQuerySortBy
    on QueryBuilder<SearchIndex, SearchIndex, QSortBy> {
  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByBodyTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bodyTokens', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByBodyTokensDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bodyTokens', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByEntryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByEntryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByIsPinned() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPinned', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByIsPinnedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPinned', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByMoodScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moodScore', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByMoodScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moodScore', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByProjectName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'projectName', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByProjectNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'projectName', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByTags() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tags', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByTagsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tags', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByTitleTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'titleTokens', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByTitleTokensDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'titleTokens', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByWordCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'wordCount', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByWordCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'wordCount', Sort.desc);
    });
  }
}

extension SearchIndexQuerySortThenBy
    on QueryBuilder<SearchIndex, SearchIndex, QSortThenBy> {
  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByBodyTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bodyTokens', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByBodyTokensDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bodyTokens', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByEntryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByEntryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByIsPinned() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPinned', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByIsPinnedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPinned', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByMoodScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moodScore', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByMoodScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moodScore', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByProjectName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'projectName', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByProjectNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'projectName', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByTags() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tags', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByTagsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tags', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByTitleTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'titleTokens', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByTitleTokensDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'titleTokens', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByWordCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'wordCount', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByWordCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'wordCount', Sort.desc);
    });
  }
}

extension SearchIndexQueryWhereDistinct
    on QueryBuilder<SearchIndex, SearchIndex, QDistinct> {
  QueryBuilder<SearchIndex, SearchIndex, QDistinct> distinctByBodyTokens(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bodyTokens', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QDistinct> distinctByCategory(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'category', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QDistinct> distinctByEntryId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'entryId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QDistinct> distinctByIsPinned() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isPinned');
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QDistinct> distinctByMoodScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'moodScore');
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QDistinct> distinctByProjectName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'projectName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QDistinct> distinctByTags(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tags', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QDistinct> distinctByTitleTokens(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'titleTokens', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QDistinct> distinctByWordCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'wordCount');
    });
  }
}

extension SearchIndexQueryProperty
    on QueryBuilder<SearchIndex, SearchIndex, QQueryProperty> {
  QueryBuilder<SearchIndex, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<SearchIndex, String, QQueryOperations> bodyTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bodyTokens');
    });
  }

  QueryBuilder<SearchIndex, String, QQueryOperations> categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'category');
    });
  }

  QueryBuilder<SearchIndex, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<SearchIndex, String, QQueryOperations> entryIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'entryId');
    });
  }

  QueryBuilder<SearchIndex, bool, QQueryOperations> isPinnedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isPinned');
    });
  }

  QueryBuilder<SearchIndex, int?, QQueryOperations> moodScoreProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'moodScore');
    });
  }

  QueryBuilder<SearchIndex, String?, QQueryOperations> projectNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'projectName');
    });
  }

  QueryBuilder<SearchIndex, String, QQueryOperations> tagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tags');
    });
  }

  QueryBuilder<SearchIndex, String, QQueryOperations> titleTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'titleTokens');
    });
  }

  QueryBuilder<SearchIndex, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<SearchIndex, int, QQueryOperations> wordCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'wordCount');
    });
  }
}

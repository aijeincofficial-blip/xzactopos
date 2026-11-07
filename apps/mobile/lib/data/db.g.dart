// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    parentId,
    name,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final String id;
  final String? parentId;
  final String name;
  final String? updatedAt;
  final String? deletedAt;
  const Category({
    required this.id,
    this.parentId,
    required this.name,
    this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      name: Value(name),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      name: serializer.fromJson<String>(json['name']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'parentId': serializer.toJson<String?>(parentId),
      'name': serializer.toJson<String>(name),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  Category copyWith({
    String? id,
    Value<String?> parentId = const Value.absent(),
    String? name,
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
  }) => Category(
    id: id ?? this.id,
    parentId: parentId.present ? parentId.value : this.parentId,
    name: name ?? this.name,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, parentId, name, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> id;
  final Value<String?> parentId;
  final Value<String> name;
  final Value<String?> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    this.parentId = const Value.absent(),
    required String name,
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<String>? parentId,
    Expression<String>? name,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String?>? parentId,
    Value<String>? name,
    Value<String?>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProductsTable extends Products with TableInfo<$ProductsTable, Product> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _searchNameMeta = const VerificationMeta(
    'searchName',
  );
  @override
  late final GeneratedColumn<String> searchName = GeneratedColumn<String>(
    'search_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pc'),
  );
  static const VerificationMeta _taxRateMeta = const VerificationMeta(
    'taxRate',
  );
  @override
  late final GeneratedColumn<double> taxRate = GeneratedColumn<double>(
    'tax_rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _trackStockMeta = const VerificationMeta(
    'trackStock',
  );
  @override
  late final GeneratedColumn<bool> trackStock = GeneratedColumn<bool>(
    'track_stock',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("track_stock" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    categoryId,
    name,
    searchName,
    unit,
    taxRate,
    trackStock,
    active,
    photoPath,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(
    Insertable<Product> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('search_name')) {
      context.handle(
        _searchNameMeta,
        searchName.isAcceptableOrUnknown(data['search_name']!, _searchNameMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('tax_rate')) {
      context.handle(
        _taxRateMeta,
        taxRate.isAcceptableOrUnknown(data['tax_rate']!, _taxRateMeta),
      );
    }
    if (data.containsKey('track_stock')) {
      context.handle(
        _trackStockMeta,
        trackStock.isAcceptableOrUnknown(data['track_stock']!, _trackStockMeta),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Product map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Product(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      searchName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_name'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      taxRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tax_rate'],
      )!,
      trackStock: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}track_stock'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ProductsTable createAlias(String alias) {
    return $ProductsTable(attachedDatabase, alias);
  }
}

class Product extends DataClass implements Insertable<Product> {
  final String id;
  final String? categoryId;
  final String name;

  /// searchKey(name): lower case, no accents. Written with every name change (schema v2).
  final String searchName;
  final String unit;
  final double taxRate;
  final bool trackStock;
  final bool active;
  final String? photoPath;
  final String? updatedAt;
  final String? deletedAt;
  const Product({
    required this.id,
    this.categoryId,
    required this.name,
    required this.searchName,
    required this.unit,
    required this.taxRate,
    required this.trackStock,
    required this.active,
    this.photoPath,
    this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['name'] = Variable<String>(name);
    map['search_name'] = Variable<String>(searchName);
    map['unit'] = Variable<String>(unit);
    map['tax_rate'] = Variable<double>(taxRate);
    map['track_stock'] = Variable<bool>(trackStock);
    map['active'] = Variable<bool>(active);
    if (!nullToAbsent || photoPath != null) {
      map['photo_path'] = Variable<String>(photoPath);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      id: Value(id),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      name: Value(name),
      searchName: Value(searchName),
      unit: Value(unit),
      taxRate: Value(taxRate),
      trackStock: Value(trackStock),
      active: Value(active),
      photoPath: photoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(photoPath),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Product.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Product(
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      name: serializer.fromJson<String>(json['name']),
      searchName: serializer.fromJson<String>(json['searchName']),
      unit: serializer.fromJson<String>(json['unit']),
      taxRate: serializer.fromJson<double>(json['taxRate']),
      trackStock: serializer.fromJson<bool>(json['trackStock']),
      active: serializer.fromJson<bool>(json['active']),
      photoPath: serializer.fromJson<String?>(json['photoPath']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'categoryId': serializer.toJson<String?>(categoryId),
      'name': serializer.toJson<String>(name),
      'searchName': serializer.toJson<String>(searchName),
      'unit': serializer.toJson<String>(unit),
      'taxRate': serializer.toJson<double>(taxRate),
      'trackStock': serializer.toJson<bool>(trackStock),
      'active': serializer.toJson<bool>(active),
      'photoPath': serializer.toJson<String?>(photoPath),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  Product copyWith({
    String? id,
    Value<String?> categoryId = const Value.absent(),
    String? name,
    String? searchName,
    String? unit,
    double? taxRate,
    bool? trackStock,
    bool? active,
    Value<String?> photoPath = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
  }) => Product(
    id: id ?? this.id,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    name: name ?? this.name,
    searchName: searchName ?? this.searchName,
    unit: unit ?? this.unit,
    taxRate: taxRate ?? this.taxRate,
    trackStock: trackStock ?? this.trackStock,
    active: active ?? this.active,
    photoPath: photoPath.present ? photoPath.value : this.photoPath,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Product copyWithCompanion(ProductsCompanion data) {
    return Product(
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      name: data.name.present ? data.name.value : this.name,
      searchName: data.searchName.present
          ? data.searchName.value
          : this.searchName,
      unit: data.unit.present ? data.unit.value : this.unit,
      taxRate: data.taxRate.present ? data.taxRate.value : this.taxRate,
      trackStock: data.trackStock.present
          ? data.trackStock.value
          : this.trackStock,
      active: data.active.present ? data.active.value : this.active,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Product(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('searchName: $searchName, ')
          ..write('unit: $unit, ')
          ..write('taxRate: $taxRate, ')
          ..write('trackStock: $trackStock, ')
          ..write('active: $active, ')
          ..write('photoPath: $photoPath, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    categoryId,
    name,
    searchName,
    unit,
    taxRate,
    trackStock,
    active,
    photoPath,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.name == this.name &&
          other.searchName == this.searchName &&
          other.unit == this.unit &&
          other.taxRate == this.taxRate &&
          other.trackStock == this.trackStock &&
          other.active == this.active &&
          other.photoPath == this.photoPath &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ProductsCompanion extends UpdateCompanion<Product> {
  final Value<String> id;
  final Value<String?> categoryId;
  final Value<String> name;
  final Value<String> searchName;
  final Value<String> unit;
  final Value<double> taxRate;
  final Value<bool> trackStock;
  final Value<bool> active;
  final Value<String?> photoPath;
  final Value<String?> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const ProductsCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.searchName = const Value.absent(),
    this.unit = const Value.absent(),
    this.taxRate = const Value.absent(),
    this.trackStock = const Value.absent(),
    this.active = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductsCompanion.insert({
    required String id,
    this.categoryId = const Value.absent(),
    required String name,
    this.searchName = const Value.absent(),
    this.unit = const Value.absent(),
    this.taxRate = const Value.absent(),
    this.trackStock = const Value.absent(),
    this.active = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Product> custom({
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<String>? name,
    Expression<String>? searchName,
    Expression<String>? unit,
    Expression<double>? taxRate,
    Expression<bool>? trackStock,
    Expression<bool>? active,
    Expression<String>? photoPath,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (name != null) 'name': name,
      if (searchName != null) 'search_name': searchName,
      if (unit != null) 'unit': unit,
      if (taxRate != null) 'tax_rate': taxRate,
      if (trackStock != null) 'track_stock': trackStock,
      if (active != null) 'active': active,
      if (photoPath != null) 'photo_path': photoPath,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductsCompanion copyWith({
    Value<String>? id,
    Value<String?>? categoryId,
    Value<String>? name,
    Value<String>? searchName,
    Value<String>? unit,
    Value<double>? taxRate,
    Value<bool>? trackStock,
    Value<bool>? active,
    Value<String?>? photoPath,
    Value<String?>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ProductsCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      searchName: searchName ?? this.searchName,
      unit: unit ?? this.unit,
      taxRate: taxRate ?? this.taxRate,
      trackStock: trackStock ?? this.trackStock,
      active: active ?? this.active,
      photoPath: photoPath ?? this.photoPath,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (searchName.present) {
      map['search_name'] = Variable<String>(searchName.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (taxRate.present) {
      map['tax_rate'] = Variable<double>(taxRate.value);
    }
    if (trackStock.present) {
      map['track_stock'] = Variable<bool>(trackStock.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('searchName: $searchName, ')
          ..write('unit: $unit, ')
          ..write('taxRate: $taxRate, ')
          ..write('trackStock: $trackStock, ')
          ..write('active: $active, ')
          ..write('photoPath: $photoPath, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VariantsTable extends Variants with TableInfo<$VariantsTable, Variant> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VariantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skuMeta = const VerificationMeta('sku');
  @override
  late final GeneratedColumn<String> sku = GeneratedColumn<String>(
    'sku',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _costMeta = const VerificationMeta('cost');
  @override
  late final GeneratedColumn<int> cost = GeneratedColumn<int>(
    'cost',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _reorderPointMeta = const VerificationMeta(
    'reorderPoint',
  );
  @override
  late final GeneratedColumn<double> reorderPoint = GeneratedColumn<double>(
    'reorder_point',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    productId,
    sku,
    barcode,
    isDefault,
    cost,
    reorderPoint,
    active,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'variants';
  @override
  VerificationContext validateIntegrity(
    Insertable<Variant> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('sku')) {
      context.handle(
        _skuMeta,
        sku.isAcceptableOrUnknown(data['sku']!, _skuMeta),
      );
    } else if (isInserting) {
      context.missing(_skuMeta);
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('cost')) {
      context.handle(
        _costMeta,
        cost.isAcceptableOrUnknown(data['cost']!, _costMeta),
      );
    }
    if (data.containsKey('reorder_point')) {
      context.handle(
        _reorderPointMeta,
        reorderPoint.isAcceptableOrUnknown(
          data['reorder_point']!,
          _reorderPointMeta,
        ),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Variant map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Variant(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      sku: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sku'],
      )!,
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      ),
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      cost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost'],
      )!,
      reorderPoint: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}reorder_point'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $VariantsTable createAlias(String alias) {
    return $VariantsTable(attachedDatabase, alias);
  }
}

class Variant extends DataClass implements Insertable<Variant> {
  final String id;
  final String productId;
  final String sku;
  final String? barcode;
  final bool isDefault;
  final int cost;
  final double reorderPoint;
  final bool active;
  final String? updatedAt;
  final String? deletedAt;
  const Variant({
    required this.id,
    required this.productId,
    required this.sku,
    this.barcode,
    required this.isDefault,
    required this.cost,
    required this.reorderPoint,
    required this.active,
    this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['product_id'] = Variable<String>(productId);
    map['sku'] = Variable<String>(sku);
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    map['is_default'] = Variable<bool>(isDefault);
    map['cost'] = Variable<int>(cost);
    map['reorder_point'] = Variable<double>(reorderPoint);
    map['active'] = Variable<bool>(active);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  VariantsCompanion toCompanion(bool nullToAbsent) {
    return VariantsCompanion(
      id: Value(id),
      productId: Value(productId),
      sku: Value(sku),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      isDefault: Value(isDefault),
      cost: Value(cost),
      reorderPoint: Value(reorderPoint),
      active: Value(active),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Variant.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Variant(
      id: serializer.fromJson<String>(json['id']),
      productId: serializer.fromJson<String>(json['productId']),
      sku: serializer.fromJson<String>(json['sku']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      cost: serializer.fromJson<int>(json['cost']),
      reorderPoint: serializer.fromJson<double>(json['reorderPoint']),
      active: serializer.fromJson<bool>(json['active']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'productId': serializer.toJson<String>(productId),
      'sku': serializer.toJson<String>(sku),
      'barcode': serializer.toJson<String?>(barcode),
      'isDefault': serializer.toJson<bool>(isDefault),
      'cost': serializer.toJson<int>(cost),
      'reorderPoint': serializer.toJson<double>(reorderPoint),
      'active': serializer.toJson<bool>(active),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  Variant copyWith({
    String? id,
    String? productId,
    String? sku,
    Value<String?> barcode = const Value.absent(),
    bool? isDefault,
    int? cost,
    double? reorderPoint,
    bool? active,
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
  }) => Variant(
    id: id ?? this.id,
    productId: productId ?? this.productId,
    sku: sku ?? this.sku,
    barcode: barcode.present ? barcode.value : this.barcode,
    isDefault: isDefault ?? this.isDefault,
    cost: cost ?? this.cost,
    reorderPoint: reorderPoint ?? this.reorderPoint,
    active: active ?? this.active,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Variant copyWithCompanion(VariantsCompanion data) {
    return Variant(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      sku: data.sku.present ? data.sku.value : this.sku,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      cost: data.cost.present ? data.cost.value : this.cost,
      reorderPoint: data.reorderPoint.present
          ? data.reorderPoint.value
          : this.reorderPoint,
      active: data.active.present ? data.active.value : this.active,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Variant(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('sku: $sku, ')
          ..write('barcode: $barcode, ')
          ..write('isDefault: $isDefault, ')
          ..write('cost: $cost, ')
          ..write('reorderPoint: $reorderPoint, ')
          ..write('active: $active, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    productId,
    sku,
    barcode,
    isDefault,
    cost,
    reorderPoint,
    active,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Variant &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.sku == this.sku &&
          other.barcode == this.barcode &&
          other.isDefault == this.isDefault &&
          other.cost == this.cost &&
          other.reorderPoint == this.reorderPoint &&
          other.active == this.active &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class VariantsCompanion extends UpdateCompanion<Variant> {
  final Value<String> id;
  final Value<String> productId;
  final Value<String> sku;
  final Value<String?> barcode;
  final Value<bool> isDefault;
  final Value<int> cost;
  final Value<double> reorderPoint;
  final Value<bool> active;
  final Value<String?> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const VariantsCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.sku = const Value.absent(),
    this.barcode = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.cost = const Value.absent(),
    this.reorderPoint = const Value.absent(),
    this.active = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VariantsCompanion.insert({
    required String id,
    required String productId,
    required String sku,
    this.barcode = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.cost = const Value.absent(),
    this.reorderPoint = const Value.absent(),
    this.active = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       productId = Value(productId),
       sku = Value(sku);
  static Insertable<Variant> custom({
    Expression<String>? id,
    Expression<String>? productId,
    Expression<String>? sku,
    Expression<String>? barcode,
    Expression<bool>? isDefault,
    Expression<int>? cost,
    Expression<double>? reorderPoint,
    Expression<bool>? active,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (sku != null) 'sku': sku,
      if (barcode != null) 'barcode': barcode,
      if (isDefault != null) 'is_default': isDefault,
      if (cost != null) 'cost': cost,
      if (reorderPoint != null) 'reorder_point': reorderPoint,
      if (active != null) 'active': active,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VariantsCompanion copyWith({
    Value<String>? id,
    Value<String>? productId,
    Value<String>? sku,
    Value<String?>? barcode,
    Value<bool>? isDefault,
    Value<int>? cost,
    Value<double>? reorderPoint,
    Value<bool>? active,
    Value<String?>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return VariantsCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      isDefault: isDefault ?? this.isDefault,
      cost: cost ?? this.cost,
      reorderPoint: reorderPoint ?? this.reorderPoint,
      active: active ?? this.active,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (sku.present) {
      map['sku'] = Variable<String>(sku.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (cost.present) {
      map['cost'] = Variable<int>(cost.value);
    }
    if (reorderPoint.present) {
      map['reorder_point'] = Variable<double>(reorderPoint.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VariantsCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('sku: $sku, ')
          ..write('barcode: $barcode, ')
          ..write('isDefault: $isDefault, ')
          ..write('cost: $cost, ')
          ..write('reorderPoint: $reorderPoint, ')
          ..write('active: $active, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PricesTable extends Prices with TableInfo<$PricesTable, Price> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PricesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _variantIdMeta = const VerificationMeta(
    'variantId',
  );
  @override
  late final GeneratedColumn<String> variantId = GeneratedColumn<String>(
    'variant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<int> price = GeneratedColumn<int>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    variantId,
    currency,
    price,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prices';
  @override
  VerificationContext validateIntegrity(
    Insertable<Price> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('variant_id')) {
      context.handle(
        _variantIdMeta,
        variantId.isAcceptableOrUnknown(data['variant_id']!, _variantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_variantIdMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {variantId, currency};
  @override
  Price map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Price(
      variantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variant_id'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PricesTable createAlias(String alias) {
    return $PricesTable(attachedDatabase, alias);
  }
}

class Price extends DataClass implements Insertable<Price> {
  final String variantId;
  final String currency;
  final int price;
  final String? updatedAt;
  final String? deletedAt;
  const Price({
    required this.variantId,
    required this.currency,
    required this.price,
    this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['variant_id'] = Variable<String>(variantId);
    map['currency'] = Variable<String>(currency);
    map['price'] = Variable<int>(price);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  PricesCompanion toCompanion(bool nullToAbsent) {
    return PricesCompanion(
      variantId: Value(variantId),
      currency: Value(currency),
      price: Value(price),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Price.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Price(
      variantId: serializer.fromJson<String>(json['variantId']),
      currency: serializer.fromJson<String>(json['currency']),
      price: serializer.fromJson<int>(json['price']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'variantId': serializer.toJson<String>(variantId),
      'currency': serializer.toJson<String>(currency),
      'price': serializer.toJson<int>(price),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  Price copyWith({
    String? variantId,
    String? currency,
    int? price,
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
  }) => Price(
    variantId: variantId ?? this.variantId,
    currency: currency ?? this.currency,
    price: price ?? this.price,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Price copyWithCompanion(PricesCompanion data) {
    return Price(
      variantId: data.variantId.present ? data.variantId.value : this.variantId,
      currency: data.currency.present ? data.currency.value : this.currency,
      price: data.price.present ? data.price.value : this.price,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Price(')
          ..write('variantId: $variantId, ')
          ..write('currency: $currency, ')
          ..write('price: $price, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(variantId, currency, price, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Price &&
          other.variantId == this.variantId &&
          other.currency == this.currency &&
          other.price == this.price &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class PricesCompanion extends UpdateCompanion<Price> {
  final Value<String> variantId;
  final Value<String> currency;
  final Value<int> price;
  final Value<String?> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const PricesCompanion({
    this.variantId = const Value.absent(),
    this.currency = const Value.absent(),
    this.price = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PricesCompanion.insert({
    required String variantId,
    required String currency,
    required int price,
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : variantId = Value(variantId),
       currency = Value(currency),
       price = Value(price);
  static Insertable<Price> custom({
    Expression<String>? variantId,
    Expression<String>? currency,
    Expression<int>? price,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (variantId != null) 'variant_id': variantId,
      if (currency != null) 'currency': currency,
      if (price != null) 'price': price,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PricesCompanion copyWith({
    Value<String>? variantId,
    Value<String>? currency,
    Value<int>? price,
    Value<String?>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return PricesCompanion(
      variantId: variantId ?? this.variantId,
      currency: currency ?? this.currency,
      price: price ?? this.price,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (variantId.present) {
      map['variant_id'] = Variable<String>(variantId.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (price.present) {
      map['price'] = Variable<int>(price.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PricesCompanion(')
          ..write('variantId: $variantId, ')
          ..write('currency: $currency, ')
          ..write('price: $price, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorsTable extends SyncCursors
    with TableInfo<$SyncCursorsTable, SyncCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tableKeyMeta = const VerificationMeta(
    'tableKey',
  );
  @override
  late final GeneratedColumn<String> tableKey = GeneratedColumn<String>(
    'table_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cursorJsonMeta = const VerificationMeta(
    'cursorJson',
  );
  @override
  late final GeneratedColumn<String> cursorJson = GeneratedColumn<String>(
    'cursor_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [tableKey, cursorJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('table_key')) {
      context.handle(
        _tableKeyMeta,
        tableKey.isAcceptableOrUnknown(data['table_key']!, _tableKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_tableKeyMeta);
    }
    if (data.containsKey('cursor_json')) {
      context.handle(
        _cursorJsonMeta,
        cursorJson.isAcceptableOrUnknown(data['cursor_json']!, _cursorJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_cursorJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tableKey};
  @override
  SyncCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursor(
      tableKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_key'],
      )!,
      cursorJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor_json'],
      )!,
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursor extends DataClass implements Insertable<SyncCursor> {
  final String tableKey;
  final String cursorJson;
  const SyncCursor({required this.tableKey, required this.cursorJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['table_key'] = Variable<String>(tableKey);
    map['cursor_json'] = Variable<String>(cursorJson);
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      tableKey: Value(tableKey),
      cursorJson: Value(cursorJson),
    );
  }

  factory SyncCursor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursor(
      tableKey: serializer.fromJson<String>(json['tableKey']),
      cursorJson: serializer.fromJson<String>(json['cursorJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tableKey': serializer.toJson<String>(tableKey),
      'cursorJson': serializer.toJson<String>(cursorJson),
    };
  }

  SyncCursor copyWith({String? tableKey, String? cursorJson}) => SyncCursor(
    tableKey: tableKey ?? this.tableKey,
    cursorJson: cursorJson ?? this.cursorJson,
  );
  SyncCursor copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursor(
      tableKey: data.tableKey.present ? data.tableKey.value : this.tableKey,
      cursorJson: data.cursorJson.present
          ? data.cursorJson.value
          : this.cursorJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursor(')
          ..write('tableKey: $tableKey, ')
          ..write('cursorJson: $cursorJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tableKey, cursorJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursor &&
          other.tableKey == this.tableKey &&
          other.cursorJson == this.cursorJson);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursor> {
  final Value<String> tableKey;
  final Value<String> cursorJson;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.tableKey = const Value.absent(),
    this.cursorJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String tableKey,
    required String cursorJson,
    this.rowid = const Value.absent(),
  }) : tableKey = Value(tableKey),
       cursorJson = Value(cursorJson);
  static Insertable<SyncCursor> custom({
    Expression<String>? tableKey,
    Expression<String>? cursorJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tableKey != null) 'table_key': tableKey,
      if (cursorJson != null) 'cursor_json': cursorJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({
    Value<String>? tableKey,
    Value<String>? cursorJson,
    Value<int>? rowid,
  }) {
    return SyncCursorsCompanion(
      tableKey: tableKey ?? this.tableKey,
      cursorJson: cursorJson ?? this.cursorJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tableKey.present) {
      map['table_key'] = Variable<String>(tableKey.value);
    }
    if (cursorJson.present) {
      map['cursor_json'] = Variable<String>(cursorJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('tableKey: $tableKey, ')
          ..write('cursorJson: $cursorJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _opIdMeta = const VerificationMeta('opId');
  @override
  late final GeneratedColumn<String> opId = GeneratedColumn<String>(
    'op_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  List<GeneratedColumn> get $columns => [
    opId,
    seq,
    kind,
    entityId,
    payload,
    status,
    attempts,
    lastError,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('op_id')) {
      context.handle(
        _opIdMeta,
        opId.isAcceptableOrUnknown(data['op_id']!, _opIdMeta),
      );
    } else if (isInserting) {
      context.missing(_opIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {opId},
  ];
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      opId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final String opId;
  final int seq;
  final String kind;
  final String entityId;
  final String payload;
  final String status;
  final int attempts;
  final String? lastError;
  final DateTime createdAt;
  const OutboxData({
    required this.opId,
    required this.seq,
    required this.kind,
    required this.entityId,
    required this.payload,
    required this.status,
    required this.attempts,
    this.lastError,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['op_id'] = Variable<String>(opId);
    map['seq'] = Variable<int>(seq);
    map['kind'] = Variable<String>(kind);
    map['entity_id'] = Variable<String>(entityId);
    map['payload'] = Variable<String>(payload);
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      opId: Value(opId),
      seq: Value(seq),
      kind: Value(kind),
      entityId: Value(entityId),
      payload: Value(payload),
      status: Value(status),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      opId: serializer.fromJson<String>(json['opId']),
      seq: serializer.fromJson<int>(json['seq']),
      kind: serializer.fromJson<String>(json['kind']),
      entityId: serializer.fromJson<String>(json['entityId']),
      payload: serializer.fromJson<String>(json['payload']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'opId': serializer.toJson<String>(opId),
      'seq': serializer.toJson<int>(seq),
      'kind': serializer.toJson<String>(kind),
      'entityId': serializer.toJson<String>(entityId),
      'payload': serializer.toJson<String>(payload),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxData copyWith({
    String? opId,
    int? seq,
    String? kind,
    String? entityId,
    String? payload,
    String? status,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
  }) => OutboxData(
    opId: opId ?? this.opId,
    seq: seq ?? this.seq,
    kind: kind ?? this.kind,
    entityId: entityId ?? this.entityId,
    payload: payload ?? this.payload,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
  );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      opId: data.opId.present ? data.opId.value : this.opId,
      seq: data.seq.present ? data.seq.value : this.seq,
      kind: data.kind.present ? data.kind.value : this.kind,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      payload: data.payload.present ? data.payload.value : this.payload,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('opId: $opId, ')
          ..write('seq: $seq, ')
          ..write('kind: $kind, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    opId,
    seq,
    kind,
    entityId,
    payload,
    status,
    attempts,
    lastError,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.opId == this.opId &&
          other.seq == this.seq &&
          other.kind == this.kind &&
          other.entityId == this.entityId &&
          other.payload == this.payload &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<String> opId;
  final Value<int> seq;
  final Value<String> kind;
  final Value<String> entityId;
  final Value<String> payload;
  final Value<String> status;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  const OutboxCompanion({
    this.opId = const Value.absent(),
    this.seq = const Value.absent(),
    this.kind = const Value.absent(),
    this.entityId = const Value.absent(),
    this.payload = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String opId,
    this.seq = const Value.absent(),
    required String kind,
    required String entityId,
    required String payload,
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
  }) : opId = Value(opId),
       kind = Value(kind),
       entityId = Value(entityId),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<OutboxData> custom({
    Expression<String>? opId,
    Expression<int>? seq,
    Expression<String>? kind,
    Expression<String>? entityId,
    Expression<String>? payload,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (opId != null) 'op_id': opId,
      if (seq != null) 'seq': seq,
      if (kind != null) 'kind': kind,
      if (entityId != null) 'entity_id': entityId,
      if (payload != null) 'payload': payload,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OutboxCompanion copyWith({
    Value<String>? opId,
    Value<int>? seq,
    Value<String>? kind,
    Value<String>? entityId,
    Value<String>? payload,
    Value<String>? status,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
  }) {
    return OutboxCompanion(
      opId: opId ?? this.opId,
      seq: seq ?? this.seq,
      kind: kind ?? this.kind,
      entityId: entityId ?? this.entityId,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (opId.present) {
      map['op_id'] = Variable<String>(opId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('opId: $opId, ')
          ..write('seq: $seq, ')
          ..write('kind: $kind, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $OpeningStockTable extends OpeningStock
    with TableInfo<$OpeningStockTable, OpeningStockData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OpeningStockTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _variantIdMeta = const VerificationMeta(
    'variantId',
  );
  @override
  late final GeneratedColumn<String> variantId = GeneratedColumn<String>(
    'variant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<double> qty = GeneratedColumn<double>(
    'qty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [variantId, qty];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'opening_stock';
  @override
  VerificationContext validateIntegrity(
    Insertable<OpeningStockData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('variant_id')) {
      context.handle(
        _variantIdMeta,
        variantId.isAcceptableOrUnknown(data['variant_id']!, _variantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_variantIdMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
        _qtyMeta,
        qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {variantId};
  @override
  OpeningStockData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OpeningStockData(
      variantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variant_id'],
      )!,
      qty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}qty'],
      )!,
    );
  }

  @override
  $OpeningStockTable createAlias(String alias) {
    return $OpeningStockTable(attachedDatabase, alias);
  }
}

class OpeningStockData extends DataClass
    implements Insertable<OpeningStockData> {
  final String variantId;
  final double qty;
  const OpeningStockData({required this.variantId, required this.qty});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['variant_id'] = Variable<String>(variantId);
    map['qty'] = Variable<double>(qty);
    return map;
  }

  OpeningStockCompanion toCompanion(bool nullToAbsent) {
    return OpeningStockCompanion(variantId: Value(variantId), qty: Value(qty));
  }

  factory OpeningStockData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OpeningStockData(
      variantId: serializer.fromJson<String>(json['variantId']),
      qty: serializer.fromJson<double>(json['qty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'variantId': serializer.toJson<String>(variantId),
      'qty': serializer.toJson<double>(qty),
    };
  }

  OpeningStockData copyWith({String? variantId, double? qty}) =>
      OpeningStockData(
        variantId: variantId ?? this.variantId,
        qty: qty ?? this.qty,
      );
  OpeningStockData copyWithCompanion(OpeningStockCompanion data) {
    return OpeningStockData(
      variantId: data.variantId.present ? data.variantId.value : this.variantId,
      qty: data.qty.present ? data.qty.value : this.qty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OpeningStockData(')
          ..write('variantId: $variantId, ')
          ..write('qty: $qty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(variantId, qty);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OpeningStockData &&
          other.variantId == this.variantId &&
          other.qty == this.qty);
}

class OpeningStockCompanion extends UpdateCompanion<OpeningStockData> {
  final Value<String> variantId;
  final Value<double> qty;
  final Value<int> rowid;
  const OpeningStockCompanion({
    this.variantId = const Value.absent(),
    this.qty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OpeningStockCompanion.insert({
    required String variantId,
    required double qty,
    this.rowid = const Value.absent(),
  }) : variantId = Value(variantId),
       qty = Value(qty);
  static Insertable<OpeningStockData> custom({
    Expression<String>? variantId,
    Expression<double>? qty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (variantId != null) 'variant_id': variantId,
      if (qty != null) 'qty': qty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OpeningStockCompanion copyWith({
    Value<String>? variantId,
    Value<double>? qty,
    Value<int>? rowid,
  }) {
    return OpeningStockCompanion(
      variantId: variantId ?? this.variantId,
      qty: qty ?? this.qty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (variantId.present) {
      map['variant_id'] = Variable<String>(variantId.value);
    }
    if (qty.present) {
      map['qty'] = Variable<double>(qty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OpeningStockCompanion(')
          ..write('variantId: $variantId, ')
          ..write('qty: $qty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MetaTable extends Meta with TableInfo<$MetaTable, MetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaData> instance, {
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
  MetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaData(
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
  $MetaTable createAlias(String alias) {
    return $MetaTable(attachedDatabase, alias);
  }
}

class MetaData extends DataClass implements Insertable<MetaData> {
  final String key;
  final String value;
  const MetaData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaCompanion toCompanion(bool nullToAbsent) {
    return MetaCompanion(key: Value(key), value: Value(value));
  }

  factory MetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaData(
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

  MetaData copyWith({String? key, String? value}) =>
      MetaData(key: key ?? this.key, value: value ?? this.value);
  MetaData copyWithCompanion(MetaCompanion data) {
    return MetaData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaData(')
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
      (other is MetaData && other.key == this.key && other.value == this.value);
}

class MetaCompanion extends UpdateCompanion<MetaData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaData> custom({
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

  MetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetaCompanion(
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
    return (StringBuffer('MetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhotoUploadsTable extends PhotoUploads
    with TableInfo<$PhotoUploadsTable, PhotoUpload> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotoUploadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _opIdMeta = const VerificationMeta('opId');
  @override
  late final GeneratedColumn<String> opId = GeneratedColumn<String>(
    'op_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [opId, productId, path, bytes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photo_uploads';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhotoUpload> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('op_id')) {
      context.handle(
        _opIdMeta,
        opId.isAcceptableOrUnknown(data['op_id']!, _opIdMeta),
      );
    } else if (isInserting) {
      context.missing(_opIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {opId};
  @override
  PhotoUpload map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhotoUpload(
      opId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}bytes'],
      )!,
    );
  }

  @override
  $PhotoUploadsTable createAlias(String alias) {
    return $PhotoUploadsTable(attachedDatabase, alias);
  }
}

class PhotoUpload extends DataClass implements Insertable<PhotoUpload> {
  final String opId;
  final String productId;
  final String path;
  final Uint8List bytes;
  const PhotoUpload({
    required this.opId,
    required this.productId,
    required this.path,
    required this.bytes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['op_id'] = Variable<String>(opId);
    map['product_id'] = Variable<String>(productId);
    map['path'] = Variable<String>(path);
    map['bytes'] = Variable<Uint8List>(bytes);
    return map;
  }

  PhotoUploadsCompanion toCompanion(bool nullToAbsent) {
    return PhotoUploadsCompanion(
      opId: Value(opId),
      productId: Value(productId),
      path: Value(path),
      bytes: Value(bytes),
    );
  }

  factory PhotoUpload.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhotoUpload(
      opId: serializer.fromJson<String>(json['opId']),
      productId: serializer.fromJson<String>(json['productId']),
      path: serializer.fromJson<String>(json['path']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'opId': serializer.toJson<String>(opId),
      'productId': serializer.toJson<String>(productId),
      'path': serializer.toJson<String>(path),
      'bytes': serializer.toJson<Uint8List>(bytes),
    };
  }

  PhotoUpload copyWith({
    String? opId,
    String? productId,
    String? path,
    Uint8List? bytes,
  }) => PhotoUpload(
    opId: opId ?? this.opId,
    productId: productId ?? this.productId,
    path: path ?? this.path,
    bytes: bytes ?? this.bytes,
  );
  PhotoUpload copyWithCompanion(PhotoUploadsCompanion data) {
    return PhotoUpload(
      opId: data.opId.present ? data.opId.value : this.opId,
      productId: data.productId.present ? data.productId.value : this.productId,
      path: data.path.present ? data.path.value : this.path,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhotoUpload(')
          ..write('opId: $opId, ')
          ..write('productId: $productId, ')
          ..write('path: $path, ')
          ..write('bytes: $bytes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(opId, productId, path, $driftBlobEquality.hash(bytes));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoUpload &&
          other.opId == this.opId &&
          other.productId == this.productId &&
          other.path == this.path &&
          $driftBlobEquality.equals(other.bytes, this.bytes));
}

class PhotoUploadsCompanion extends UpdateCompanion<PhotoUpload> {
  final Value<String> opId;
  final Value<String> productId;
  final Value<String> path;
  final Value<Uint8List> bytes;
  final Value<int> rowid;
  const PhotoUploadsCompanion({
    this.opId = const Value.absent(),
    this.productId = const Value.absent(),
    this.path = const Value.absent(),
    this.bytes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhotoUploadsCompanion.insert({
    required String opId,
    required String productId,
    required String path,
    required Uint8List bytes,
    this.rowid = const Value.absent(),
  }) : opId = Value(opId),
       productId = Value(productId),
       path = Value(path),
       bytes = Value(bytes);
  static Insertable<PhotoUpload> custom({
    Expression<String>? opId,
    Expression<String>? productId,
    Expression<String>? path,
    Expression<Uint8List>? bytes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (opId != null) 'op_id': opId,
      if (productId != null) 'product_id': productId,
      if (path != null) 'path': path,
      if (bytes != null) 'bytes': bytes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhotoUploadsCompanion copyWith({
    Value<String>? opId,
    Value<String>? productId,
    Value<String>? path,
    Value<Uint8List>? bytes,
    Value<int>? rowid,
  }) {
    return PhotoUploadsCompanion(
      opId: opId ?? this.opId,
      productId: productId ?? this.productId,
      path: path ?? this.path,
      bytes: bytes ?? this.bytes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (opId.present) {
      map['op_id'] = Variable<String>(opId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotoUploadsCompanion(')
          ..write('opId: $opId, ')
          ..write('productId: $productId, ')
          ..write('path: $path, ')
          ..write('bytes: $bytes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhotoCacheTable extends PhotoCache
    with TableInfo<$PhotoCacheTable, PhotoCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotoCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [productId, path, bytes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photo_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhotoCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {productId};
  @override
  PhotoCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhotoCacheData(
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}bytes'],
      )!,
    );
  }

  @override
  $PhotoCacheTable createAlias(String alias) {
    return $PhotoCacheTable(attachedDatabase, alias);
  }
}

class PhotoCacheData extends DataClass implements Insertable<PhotoCacheData> {
  final String productId;
  final String path;
  final Uint8List bytes;
  const PhotoCacheData({
    required this.productId,
    required this.path,
    required this.bytes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['product_id'] = Variable<String>(productId);
    map['path'] = Variable<String>(path);
    map['bytes'] = Variable<Uint8List>(bytes);
    return map;
  }

  PhotoCacheCompanion toCompanion(bool nullToAbsent) {
    return PhotoCacheCompanion(
      productId: Value(productId),
      path: Value(path),
      bytes: Value(bytes),
    );
  }

  factory PhotoCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhotoCacheData(
      productId: serializer.fromJson<String>(json['productId']),
      path: serializer.fromJson<String>(json['path']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'productId': serializer.toJson<String>(productId),
      'path': serializer.toJson<String>(path),
      'bytes': serializer.toJson<Uint8List>(bytes),
    };
  }

  PhotoCacheData copyWith({
    String? productId,
    String? path,
    Uint8List? bytes,
  }) => PhotoCacheData(
    productId: productId ?? this.productId,
    path: path ?? this.path,
    bytes: bytes ?? this.bytes,
  );
  PhotoCacheData copyWithCompanion(PhotoCacheCompanion data) {
    return PhotoCacheData(
      productId: data.productId.present ? data.productId.value : this.productId,
      path: data.path.present ? data.path.value : this.path,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhotoCacheData(')
          ..write('productId: $productId, ')
          ..write('path: $path, ')
          ..write('bytes: $bytes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(productId, path, $driftBlobEquality.hash(bytes));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoCacheData &&
          other.productId == this.productId &&
          other.path == this.path &&
          $driftBlobEquality.equals(other.bytes, this.bytes));
}

class PhotoCacheCompanion extends UpdateCompanion<PhotoCacheData> {
  final Value<String> productId;
  final Value<String> path;
  final Value<Uint8List> bytes;
  final Value<int> rowid;
  const PhotoCacheCompanion({
    this.productId = const Value.absent(),
    this.path = const Value.absent(),
    this.bytes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhotoCacheCompanion.insert({
    required String productId,
    required String path,
    required Uint8List bytes,
    this.rowid = const Value.absent(),
  }) : productId = Value(productId),
       path = Value(path),
       bytes = Value(bytes);
  static Insertable<PhotoCacheData> custom({
    Expression<String>? productId,
    Expression<String>? path,
    Expression<Uint8List>? bytes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (productId != null) 'product_id': productId,
      if (path != null) 'path': path,
      if (bytes != null) 'bytes': bytes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhotoCacheCompanion copyWith({
    Value<String>? productId,
    Value<String>? path,
    Value<Uint8List>? bytes,
    Value<int>? rowid,
  }) {
    return PhotoCacheCompanion(
      productId: productId ?? this.productId,
      path: path ?? this.path,
      bytes: bytes ?? this.bytes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotoCacheCompanion(')
          ..write('productId: $productId, ')
          ..write('path: $path, ')
          ..write('bytes: $bytes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CustomersTable extends Customers
    with TableInfo<$CustomersTable, Customer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, phone, updatedAt, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'customers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Customer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Customer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Customer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CustomersTable createAlias(String alias) {
    return $CustomersTable(attachedDatabase, alias);
  }
}

class Customer extends DataClass implements Insertable<Customer> {
  final String id;
  final String name;
  final String? phone;
  final String? updatedAt;
  final String? deletedAt;
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  CustomersCompanion toCompanion(bool nullToAbsent) {
    return CustomersCompanion(
      id: Value(id),
      name: Value(name),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Customer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Customer(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String?>(json['phone']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String?>(phone),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  Customer copyWith({
    String? id,
    String? name,
    Value<String?> phone = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
  }) => Customer(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone.present ? phone.value : this.phone,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Customer copyWithCompanion(CustomersCompanion data) {
    return Customer(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Customer(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, phone, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Customer &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class CustomersCompanion extends UpdateCompanion<Customer> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> phone;
  final Value<String?> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const CustomersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomersCompanion.insert({
    required String id,
    required String name,
    this.phone = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Customer> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? phone,
    Value<String?>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CustomersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ServerLedgerTable extends ServerLedger
    with TableInfo<$ServerLedgerTable, ServerLedgerData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServerLedgerTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _saleIdMeta = const VerificationMeta('saleId');
  @override
  late final GeneratedColumn<String> saleId = GeneratedColumn<String>(
    'sale_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<String> occurredAt = GeneratedColumn<String>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    customerId,
    kind,
    amount,
    saleId,
    note,
    occurredAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'server_ledger';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServerLedgerData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_customerIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('sale_id')) {
      context.handle(
        _saleIdMeta,
        saleId.isAcceptableOrUnknown(data['sale_id']!, _saleIdMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
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
  ServerLedgerData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServerLedgerData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      saleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sale_id'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurred_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ServerLedgerTable createAlias(String alias) {
    return $ServerLedgerTable(attachedDatabase, alias);
  }
}

class ServerLedgerData extends DataClass
    implements Insertable<ServerLedgerData> {
  final String id;
  final String customerId;
  final String kind;
  final int amount;
  final String? saleId;
  final String? note;
  final String occurredAt;
  final String createdAt;
  const ServerLedgerData({
    required this.id,
    required this.customerId,
    required this.kind,
    required this.amount,
    this.saleId,
    this.note,
    required this.occurredAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['customer_id'] = Variable<String>(customerId);
    map['kind'] = Variable<String>(kind);
    map['amount'] = Variable<int>(amount);
    if (!nullToAbsent || saleId != null) {
      map['sale_id'] = Variable<String>(saleId);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['occurred_at'] = Variable<String>(occurredAt);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  ServerLedgerCompanion toCompanion(bool nullToAbsent) {
    return ServerLedgerCompanion(
      id: Value(id),
      customerId: Value(customerId),
      kind: Value(kind),
      amount: Value(amount),
      saleId: saleId == null && nullToAbsent
          ? const Value.absent()
          : Value(saleId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      occurredAt: Value(occurredAt),
      createdAt: Value(createdAt),
    );
  }

  factory ServerLedgerData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServerLedgerData(
      id: serializer.fromJson<String>(json['id']),
      customerId: serializer.fromJson<String>(json['customerId']),
      kind: serializer.fromJson<String>(json['kind']),
      amount: serializer.fromJson<int>(json['amount']),
      saleId: serializer.fromJson<String?>(json['saleId']),
      note: serializer.fromJson<String?>(json['note']),
      occurredAt: serializer.fromJson<String>(json['occurredAt']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'customerId': serializer.toJson<String>(customerId),
      'kind': serializer.toJson<String>(kind),
      'amount': serializer.toJson<int>(amount),
      'saleId': serializer.toJson<String?>(saleId),
      'note': serializer.toJson<String?>(note),
      'occurredAt': serializer.toJson<String>(occurredAt),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  ServerLedgerData copyWith({
    String? id,
    String? customerId,
    String? kind,
    int? amount,
    Value<String?> saleId = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? occurredAt,
    String? createdAt,
  }) => ServerLedgerData(
    id: id ?? this.id,
    customerId: customerId ?? this.customerId,
    kind: kind ?? this.kind,
    amount: amount ?? this.amount,
    saleId: saleId.present ? saleId.value : this.saleId,
    note: note.present ? note.value : this.note,
    occurredAt: occurredAt ?? this.occurredAt,
    createdAt: createdAt ?? this.createdAt,
  );
  ServerLedgerData copyWithCompanion(ServerLedgerCompanion data) {
    return ServerLedgerData(
      id: data.id.present ? data.id.value : this.id,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      kind: data.kind.present ? data.kind.value : this.kind,
      amount: data.amount.present ? data.amount.value : this.amount,
      saleId: data.saleId.present ? data.saleId.value : this.saleId,
      note: data.note.present ? data.note.value : this.note,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServerLedgerData(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('kind: $kind, ')
          ..write('amount: $amount, ')
          ..write('saleId: $saleId, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    customerId,
    kind,
    amount,
    saleId,
    note,
    occurredAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerLedgerData &&
          other.id == this.id &&
          other.customerId == this.customerId &&
          other.kind == this.kind &&
          other.amount == this.amount &&
          other.saleId == this.saleId &&
          other.note == this.note &&
          other.occurredAt == this.occurredAt &&
          other.createdAt == this.createdAt);
}

class ServerLedgerCompanion extends UpdateCompanion<ServerLedgerData> {
  final Value<String> id;
  final Value<String> customerId;
  final Value<String> kind;
  final Value<int> amount;
  final Value<String?> saleId;
  final Value<String?> note;
  final Value<String> occurredAt;
  final Value<String> createdAt;
  final Value<int> rowid;
  const ServerLedgerCompanion({
    this.id = const Value.absent(),
    this.customerId = const Value.absent(),
    this.kind = const Value.absent(),
    this.amount = const Value.absent(),
    this.saleId = const Value.absent(),
    this.note = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServerLedgerCompanion.insert({
    required String id,
    required String customerId,
    required String kind,
    required int amount,
    this.saleId = const Value.absent(),
    this.note = const Value.absent(),
    required String occurredAt,
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       customerId = Value(customerId),
       kind = Value(kind),
       amount = Value(amount),
       occurredAt = Value(occurredAt),
       createdAt = Value(createdAt);
  static Insertable<ServerLedgerData> custom({
    Expression<String>? id,
    Expression<String>? customerId,
    Expression<String>? kind,
    Expression<int>? amount,
    Expression<String>? saleId,
    Expression<String>? note,
    Expression<String>? occurredAt,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (customerId != null) 'customer_id': customerId,
      if (kind != null) 'kind': kind,
      if (amount != null) 'amount': amount,
      if (saleId != null) 'sale_id': saleId,
      if (note != null) 'note': note,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServerLedgerCompanion copyWith({
    Value<String>? id,
    Value<String>? customerId,
    Value<String>? kind,
    Value<int>? amount,
    Value<String?>? saleId,
    Value<String?>? note,
    Value<String>? occurredAt,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return ServerLedgerCompanion(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      kind: kind ?? this.kind,
      amount: amount ?? this.amount,
      saleId: saleId ?? this.saleId,
      note: note ?? this.note,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (saleId.present) {
      map['sale_id'] = Variable<String>(saleId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<String>(occurredAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServerLedgerCompanion(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('kind: $kind, ')
          ..write('amount: $amount, ')
          ..write('saleId: $saleId, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalLedgerTable extends LocalLedger
    with TableInfo<$LocalLedgerTable, LocalLedgerData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalLedgerTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _opIdMeta = const VerificationMeta('opId');
  @override
  late final GeneratedColumn<String> opId = GeneratedColumn<String>(
    'op_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _saleIdMeta = const VerificationMeta('saleId');
  @override
  late final GeneratedColumn<String> saleId = GeneratedColumn<String>(
    'sale_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<String> occurredAt = GeneratedColumn<String>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confirmedAfterMeta = const VerificationMeta(
    'confirmedAfter',
  );
  @override
  late final GeneratedColumn<String> confirmedAfter = GeneratedColumn<String>(
    'confirmed_after',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    opId,
    customerId,
    kind,
    amount,
    saleId,
    note,
    occurredAt,
    confirmedAfter,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_ledger';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalLedgerData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('op_id')) {
      context.handle(
        _opIdMeta,
        opId.isAcceptableOrUnknown(data['op_id']!, _opIdMeta),
      );
    } else if (isInserting) {
      context.missing(_opIdMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_customerIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('sale_id')) {
      context.handle(
        _saleIdMeta,
        saleId.isAcceptableOrUnknown(data['sale_id']!, _saleIdMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('confirmed_after')) {
      context.handle(
        _confirmedAfterMeta,
        confirmedAfter.isAcceptableOrUnknown(
          data['confirmed_after']!,
          _confirmedAfterMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalLedgerData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalLedgerData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      opId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op_id'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      saleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sale_id'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurred_at'],
      )!,
      confirmedAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confirmed_after'],
      ),
    );
  }

  @override
  $LocalLedgerTable createAlias(String alias) {
    return $LocalLedgerTable(attachedDatabase, alias);
  }
}

class LocalLedgerData extends DataClass implements Insertable<LocalLedgerData> {
  final int id;
  final String opId;
  final String customerId;
  final String kind;
  final int amount;
  final String? saleId;
  final String? note;
  final String occurredAt;
  final String? confirmedAfter;
  const LocalLedgerData({
    required this.id,
    required this.opId,
    required this.customerId,
    required this.kind,
    required this.amount,
    this.saleId,
    this.note,
    required this.occurredAt,
    this.confirmedAfter,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['op_id'] = Variable<String>(opId);
    map['customer_id'] = Variable<String>(customerId);
    map['kind'] = Variable<String>(kind);
    map['amount'] = Variable<int>(amount);
    if (!nullToAbsent || saleId != null) {
      map['sale_id'] = Variable<String>(saleId);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['occurred_at'] = Variable<String>(occurredAt);
    if (!nullToAbsent || confirmedAfter != null) {
      map['confirmed_after'] = Variable<String>(confirmedAfter);
    }
    return map;
  }

  LocalLedgerCompanion toCompanion(bool nullToAbsent) {
    return LocalLedgerCompanion(
      id: Value(id),
      opId: Value(opId),
      customerId: Value(customerId),
      kind: Value(kind),
      amount: Value(amount),
      saleId: saleId == null && nullToAbsent
          ? const Value.absent()
          : Value(saleId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      occurredAt: Value(occurredAt),
      confirmedAfter: confirmedAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(confirmedAfter),
    );
  }

  factory LocalLedgerData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalLedgerData(
      id: serializer.fromJson<int>(json['id']),
      opId: serializer.fromJson<String>(json['opId']),
      customerId: serializer.fromJson<String>(json['customerId']),
      kind: serializer.fromJson<String>(json['kind']),
      amount: serializer.fromJson<int>(json['amount']),
      saleId: serializer.fromJson<String?>(json['saleId']),
      note: serializer.fromJson<String?>(json['note']),
      occurredAt: serializer.fromJson<String>(json['occurredAt']),
      confirmedAfter: serializer.fromJson<String?>(json['confirmedAfter']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'opId': serializer.toJson<String>(opId),
      'customerId': serializer.toJson<String>(customerId),
      'kind': serializer.toJson<String>(kind),
      'amount': serializer.toJson<int>(amount),
      'saleId': serializer.toJson<String?>(saleId),
      'note': serializer.toJson<String?>(note),
      'occurredAt': serializer.toJson<String>(occurredAt),
      'confirmedAfter': serializer.toJson<String?>(confirmedAfter),
    };
  }

  LocalLedgerData copyWith({
    int? id,
    String? opId,
    String? customerId,
    String? kind,
    int? amount,
    Value<String?> saleId = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? occurredAt,
    Value<String?> confirmedAfter = const Value.absent(),
  }) => LocalLedgerData(
    id: id ?? this.id,
    opId: opId ?? this.opId,
    customerId: customerId ?? this.customerId,
    kind: kind ?? this.kind,
    amount: amount ?? this.amount,
    saleId: saleId.present ? saleId.value : this.saleId,
    note: note.present ? note.value : this.note,
    occurredAt: occurredAt ?? this.occurredAt,
    confirmedAfter: confirmedAfter.present
        ? confirmedAfter.value
        : this.confirmedAfter,
  );
  LocalLedgerData copyWithCompanion(LocalLedgerCompanion data) {
    return LocalLedgerData(
      id: data.id.present ? data.id.value : this.id,
      opId: data.opId.present ? data.opId.value : this.opId,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      kind: data.kind.present ? data.kind.value : this.kind,
      amount: data.amount.present ? data.amount.value : this.amount,
      saleId: data.saleId.present ? data.saleId.value : this.saleId,
      note: data.note.present ? data.note.value : this.note,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      confirmedAfter: data.confirmedAfter.present
          ? data.confirmedAfter.value
          : this.confirmedAfter,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalLedgerData(')
          ..write('id: $id, ')
          ..write('opId: $opId, ')
          ..write('customerId: $customerId, ')
          ..write('kind: $kind, ')
          ..write('amount: $amount, ')
          ..write('saleId: $saleId, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('confirmedAfter: $confirmedAfter')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    opId,
    customerId,
    kind,
    amount,
    saleId,
    note,
    occurredAt,
    confirmedAfter,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalLedgerData &&
          other.id == this.id &&
          other.opId == this.opId &&
          other.customerId == this.customerId &&
          other.kind == this.kind &&
          other.amount == this.amount &&
          other.saleId == this.saleId &&
          other.note == this.note &&
          other.occurredAt == this.occurredAt &&
          other.confirmedAfter == this.confirmedAfter);
}

class LocalLedgerCompanion extends UpdateCompanion<LocalLedgerData> {
  final Value<int> id;
  final Value<String> opId;
  final Value<String> customerId;
  final Value<String> kind;
  final Value<int> amount;
  final Value<String?> saleId;
  final Value<String?> note;
  final Value<String> occurredAt;
  final Value<String?> confirmedAfter;
  const LocalLedgerCompanion({
    this.id = const Value.absent(),
    this.opId = const Value.absent(),
    this.customerId = const Value.absent(),
    this.kind = const Value.absent(),
    this.amount = const Value.absent(),
    this.saleId = const Value.absent(),
    this.note = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.confirmedAfter = const Value.absent(),
  });
  LocalLedgerCompanion.insert({
    this.id = const Value.absent(),
    required String opId,
    required String customerId,
    required String kind,
    required int amount,
    this.saleId = const Value.absent(),
    this.note = const Value.absent(),
    required String occurredAt,
    this.confirmedAfter = const Value.absent(),
  }) : opId = Value(opId),
       customerId = Value(customerId),
       kind = Value(kind),
       amount = Value(amount),
       occurredAt = Value(occurredAt);
  static Insertable<LocalLedgerData> custom({
    Expression<int>? id,
    Expression<String>? opId,
    Expression<String>? customerId,
    Expression<String>? kind,
    Expression<int>? amount,
    Expression<String>? saleId,
    Expression<String>? note,
    Expression<String>? occurredAt,
    Expression<String>? confirmedAfter,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (opId != null) 'op_id': opId,
      if (customerId != null) 'customer_id': customerId,
      if (kind != null) 'kind': kind,
      if (amount != null) 'amount': amount,
      if (saleId != null) 'sale_id': saleId,
      if (note != null) 'note': note,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (confirmedAfter != null) 'confirmed_after': confirmedAfter,
    });
  }

  LocalLedgerCompanion copyWith({
    Value<int>? id,
    Value<String>? opId,
    Value<String>? customerId,
    Value<String>? kind,
    Value<int>? amount,
    Value<String?>? saleId,
    Value<String?>? note,
    Value<String>? occurredAt,
    Value<String?>? confirmedAfter,
  }) {
    return LocalLedgerCompanion(
      id: id ?? this.id,
      opId: opId ?? this.opId,
      customerId: customerId ?? this.customerId,
      kind: kind ?? this.kind,
      amount: amount ?? this.amount,
      saleId: saleId ?? this.saleId,
      note: note ?? this.note,
      occurredAt: occurredAt ?? this.occurredAt,
      confirmedAfter: confirmedAfter ?? this.confirmedAfter,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (opId.present) {
      map['op_id'] = Variable<String>(opId.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (saleId.present) {
      map['sale_id'] = Variable<String>(saleId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<String>(occurredAt.value);
    }
    if (confirmedAfter.present) {
      map['confirmed_after'] = Variable<String>(confirmedAfter.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalLedgerCompanion(')
          ..write('id: $id, ')
          ..write('opId: $opId, ')
          ..write('customerId: $customerId, ')
          ..write('kind: $kind, ')
          ..write('amount: $amount, ')
          ..write('saleId: $saleId, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('confirmedAfter: $confirmedAfter')
          ..write(')'))
        .toString();
  }
}

class $StockLevelsTable extends StockLevels
    with TableInfo<$StockLevelsTable, StockLevel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockLevelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _locationIdMeta = const VerificationMeta(
    'locationId',
  );
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
    'location_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _variantIdMeta = const VerificationMeta(
    'variantId',
  );
  @override
  late final GeneratedColumn<String> variantId = GeneratedColumn<String>(
    'variant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<double> qty = GeneratedColumn<double>(
    'qty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [locationId, variantId, qty, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_levels';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockLevel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('location_id')) {
      context.handle(
        _locationIdMeta,
        locationId.isAcceptableOrUnknown(data['location_id']!, _locationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_locationIdMeta);
    }
    if (data.containsKey('variant_id')) {
      context.handle(
        _variantIdMeta,
        variantId.isAcceptableOrUnknown(data['variant_id']!, _variantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_variantIdMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
        _qtyMeta,
        qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {locationId, variantId};
  @override
  StockLevel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockLevel(
      locationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_id'],
      )!,
      variantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variant_id'],
      )!,
      qty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}qty'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StockLevelsTable createAlias(String alias) {
    return $StockLevelsTable(attachedDatabase, alias);
  }
}

class StockLevel extends DataClass implements Insertable<StockLevel> {
  final String locationId;
  final String variantId;
  final double qty;
  final String updatedAt;
  const StockLevel({
    required this.locationId,
    required this.variantId,
    required this.qty,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['location_id'] = Variable<String>(locationId);
    map['variant_id'] = Variable<String>(variantId);
    map['qty'] = Variable<double>(qty);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  StockLevelsCompanion toCompanion(bool nullToAbsent) {
    return StockLevelsCompanion(
      locationId: Value(locationId),
      variantId: Value(variantId),
      qty: Value(qty),
      updatedAt: Value(updatedAt),
    );
  }

  factory StockLevel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockLevel(
      locationId: serializer.fromJson<String>(json['locationId']),
      variantId: serializer.fromJson<String>(json['variantId']),
      qty: serializer.fromJson<double>(json['qty']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'locationId': serializer.toJson<String>(locationId),
      'variantId': serializer.toJson<String>(variantId),
      'qty': serializer.toJson<double>(qty),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  StockLevel copyWith({
    String? locationId,
    String? variantId,
    double? qty,
    String? updatedAt,
  }) => StockLevel(
    locationId: locationId ?? this.locationId,
    variantId: variantId ?? this.variantId,
    qty: qty ?? this.qty,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StockLevel copyWithCompanion(StockLevelsCompanion data) {
    return StockLevel(
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
      variantId: data.variantId.present ? data.variantId.value : this.variantId,
      qty: data.qty.present ? data.qty.value : this.qty,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockLevel(')
          ..write('locationId: $locationId, ')
          ..write('variantId: $variantId, ')
          ..write('qty: $qty, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(locationId, variantId, qty, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockLevel &&
          other.locationId == this.locationId &&
          other.variantId == this.variantId &&
          other.qty == this.qty &&
          other.updatedAt == this.updatedAt);
}

class StockLevelsCompanion extends UpdateCompanion<StockLevel> {
  final Value<String> locationId;
  final Value<String> variantId;
  final Value<double> qty;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const StockLevelsCompanion({
    this.locationId = const Value.absent(),
    this.variantId = const Value.absent(),
    this.qty = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StockLevelsCompanion.insert({
    required String locationId,
    required String variantId,
    required double qty,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : locationId = Value(locationId),
       variantId = Value(variantId),
       qty = Value(qty),
       updatedAt = Value(updatedAt);
  static Insertable<StockLevel> custom({
    Expression<String>? locationId,
    Expression<String>? variantId,
    Expression<double>? qty,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (locationId != null) 'location_id': locationId,
      if (variantId != null) 'variant_id': variantId,
      if (qty != null) 'qty': qty,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StockLevelsCompanion copyWith({
    Value<String>? locationId,
    Value<String>? variantId,
    Value<double>? qty,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return StockLevelsCompanion(
      locationId: locationId ?? this.locationId,
      variantId: variantId ?? this.variantId,
      qty: qty ?? this.qty,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (variantId.present) {
      map['variant_id'] = Variable<String>(variantId.value);
    }
    if (qty.present) {
      map['qty'] = Variable<double>(qty.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockLevelsCompanion(')
          ..write('locationId: $locationId, ')
          ..write('variantId: $variantId, ')
          ..write('qty: $qty, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalMovementsTable extends LocalMovements
    with TableInfo<$LocalMovementsTable, LocalMovement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMovementsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _opIdMeta = const VerificationMeta('opId');
  @override
  late final GeneratedColumn<String> opId = GeneratedColumn<String>(
    'op_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _variantIdMeta = const VerificationMeta(
    'variantId',
  );
  @override
  late final GeneratedColumn<String> variantId = GeneratedColumn<String>(
    'variant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<double> qty = GeneratedColumn<double>(
    'qty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confirmedAfterMeta = const VerificationMeta(
    'confirmedAfter',
  );
  @override
  late final GeneratedColumn<String> confirmedAfter = GeneratedColumn<String>(
    'confirmed_after',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    opId,
    variantId,
    qty,
    confirmedAfter,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_movements';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMovement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('op_id')) {
      context.handle(
        _opIdMeta,
        opId.isAcceptableOrUnknown(data['op_id']!, _opIdMeta),
      );
    } else if (isInserting) {
      context.missing(_opIdMeta);
    }
    if (data.containsKey('variant_id')) {
      context.handle(
        _variantIdMeta,
        variantId.isAcceptableOrUnknown(data['variant_id']!, _variantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_variantIdMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
        _qtyMeta,
        qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    if (data.containsKey('confirmed_after')) {
      context.handle(
        _confirmedAfterMeta,
        confirmedAfter.isAcceptableOrUnknown(
          data['confirmed_after']!,
          _confirmedAfterMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalMovement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMovement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      opId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op_id'],
      )!,
      variantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variant_id'],
      )!,
      qty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}qty'],
      )!,
      confirmedAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confirmed_after'],
      ),
    );
  }

  @override
  $LocalMovementsTable createAlias(String alias) {
    return $LocalMovementsTable(attachedDatabase, alias);
  }
}

class LocalMovement extends DataClass implements Insertable<LocalMovement> {
  final int id;
  final String opId;
  final String variantId;
  final double qty;
  final String? confirmedAfter;
  const LocalMovement({
    required this.id,
    required this.opId,
    required this.variantId,
    required this.qty,
    this.confirmedAfter,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['op_id'] = Variable<String>(opId);
    map['variant_id'] = Variable<String>(variantId);
    map['qty'] = Variable<double>(qty);
    if (!nullToAbsent || confirmedAfter != null) {
      map['confirmed_after'] = Variable<String>(confirmedAfter);
    }
    return map;
  }

  LocalMovementsCompanion toCompanion(bool nullToAbsent) {
    return LocalMovementsCompanion(
      id: Value(id),
      opId: Value(opId),
      variantId: Value(variantId),
      qty: Value(qty),
      confirmedAfter: confirmedAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(confirmedAfter),
    );
  }

  factory LocalMovement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMovement(
      id: serializer.fromJson<int>(json['id']),
      opId: serializer.fromJson<String>(json['opId']),
      variantId: serializer.fromJson<String>(json['variantId']),
      qty: serializer.fromJson<double>(json['qty']),
      confirmedAfter: serializer.fromJson<String?>(json['confirmedAfter']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'opId': serializer.toJson<String>(opId),
      'variantId': serializer.toJson<String>(variantId),
      'qty': serializer.toJson<double>(qty),
      'confirmedAfter': serializer.toJson<String?>(confirmedAfter),
    };
  }

  LocalMovement copyWith({
    int? id,
    String? opId,
    String? variantId,
    double? qty,
    Value<String?> confirmedAfter = const Value.absent(),
  }) => LocalMovement(
    id: id ?? this.id,
    opId: opId ?? this.opId,
    variantId: variantId ?? this.variantId,
    qty: qty ?? this.qty,
    confirmedAfter: confirmedAfter.present
        ? confirmedAfter.value
        : this.confirmedAfter,
  );
  LocalMovement copyWithCompanion(LocalMovementsCompanion data) {
    return LocalMovement(
      id: data.id.present ? data.id.value : this.id,
      opId: data.opId.present ? data.opId.value : this.opId,
      variantId: data.variantId.present ? data.variantId.value : this.variantId,
      qty: data.qty.present ? data.qty.value : this.qty,
      confirmedAfter: data.confirmedAfter.present
          ? data.confirmedAfter.value
          : this.confirmedAfter,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMovement(')
          ..write('id: $id, ')
          ..write('opId: $opId, ')
          ..write('variantId: $variantId, ')
          ..write('qty: $qty, ')
          ..write('confirmedAfter: $confirmedAfter')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, opId, variantId, qty, confirmedAfter);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMovement &&
          other.id == this.id &&
          other.opId == this.opId &&
          other.variantId == this.variantId &&
          other.qty == this.qty &&
          other.confirmedAfter == this.confirmedAfter);
}

class LocalMovementsCompanion extends UpdateCompanion<LocalMovement> {
  final Value<int> id;
  final Value<String> opId;
  final Value<String> variantId;
  final Value<double> qty;
  final Value<String?> confirmedAfter;
  const LocalMovementsCompanion({
    this.id = const Value.absent(),
    this.opId = const Value.absent(),
    this.variantId = const Value.absent(),
    this.qty = const Value.absent(),
    this.confirmedAfter = const Value.absent(),
  });
  LocalMovementsCompanion.insert({
    this.id = const Value.absent(),
    required String opId,
    required String variantId,
    required double qty,
    this.confirmedAfter = const Value.absent(),
  }) : opId = Value(opId),
       variantId = Value(variantId),
       qty = Value(qty);
  static Insertable<LocalMovement> custom({
    Expression<int>? id,
    Expression<String>? opId,
    Expression<String>? variantId,
    Expression<double>? qty,
    Expression<String>? confirmedAfter,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (opId != null) 'op_id': opId,
      if (variantId != null) 'variant_id': variantId,
      if (qty != null) 'qty': qty,
      if (confirmedAfter != null) 'confirmed_after': confirmedAfter,
    });
  }

  LocalMovementsCompanion copyWith({
    Value<int>? id,
    Value<String>? opId,
    Value<String>? variantId,
    Value<double>? qty,
    Value<String?>? confirmedAfter,
  }) {
    return LocalMovementsCompanion(
      id: id ?? this.id,
      opId: opId ?? this.opId,
      variantId: variantId ?? this.variantId,
      qty: qty ?? this.qty,
      confirmedAfter: confirmedAfter ?? this.confirmedAfter,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (opId.present) {
      map['op_id'] = Variable<String>(opId.value);
    }
    if (variantId.present) {
      map['variant_id'] = Variable<String>(variantId.value);
    }
    if (qty.present) {
      map['qty'] = Variable<double>(qty.value);
    }
    if (confirmedAfter.present) {
      map['confirmed_after'] = Variable<String>(confirmedAfter.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMovementsCompanion(')
          ..write('id: $id, ')
          ..write('opId: $opId, ')
          ..write('variantId: $variantId, ')
          ..write('qty: $qty, ')
          ..write('confirmedAfter: $confirmedAfter')
          ..write(')'))
        .toString();
  }
}

class $SalesTable extends Sales with TableInfo<$SalesTable, Sale> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SalesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localNoMeta = const VerificationMeta(
    'localNo',
  );
  @override
  late final GeneratedColumn<String> localNo = GeneratedColumn<String>(
    'local_no',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('completed'),
  );
  static const VerificationMeta _subtotalMeta = const VerificationMeta(
    'subtotal',
  );
  @override
  late final GeneratedColumn<int> subtotal = GeneratedColumn<int>(
    'subtotal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _discountMeta = const VerificationMeta(
    'discount',
  );
  @override
  late final GeneratedColumn<int> discount = GeneratedColumn<int>(
    'discount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _taxMeta = const VerificationMeta('tax');
  @override
  late final GeneratedColumn<int> tax = GeneratedColumn<int>(
    'tax',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _soldAtMeta = const VerificationMeta('soldAt');
  @override
  late final GeneratedColumn<String> soldAt = GeneratedColumn<String>(
    'sold_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voidedAtMeta = const VerificationMeta(
    'voidedAt',
  );
  @override
  late final GeneratedColumn<String> voidedAt = GeneratedColumn<String>(
    'voided_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voidReasonMeta = const VerificationMeta(
    'voidReason',
  );
  @override
  late final GeneratedColumn<String> voidReason = GeneratedColumn<String>(
    'void_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    localNo,
    status,
    subtotal,
    discount,
    tax,
    total,
    customerId,
    soldAt,
    voidedAt,
    voidReason,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sales';
  @override
  VerificationContext validateIntegrity(
    Insertable<Sale> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('local_no')) {
      context.handle(
        _localNoMeta,
        localNo.isAcceptableOrUnknown(data['local_no']!, _localNoMeta),
      );
    } else if (isInserting) {
      context.missing(_localNoMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('subtotal')) {
      context.handle(
        _subtotalMeta,
        subtotal.isAcceptableOrUnknown(data['subtotal']!, _subtotalMeta),
      );
    } else if (isInserting) {
      context.missing(_subtotalMeta);
    }
    if (data.containsKey('discount')) {
      context.handle(
        _discountMeta,
        discount.isAcceptableOrUnknown(data['discount']!, _discountMeta),
      );
    }
    if (data.containsKey('tax')) {
      context.handle(
        _taxMeta,
        tax.isAcceptableOrUnknown(data['tax']!, _taxMeta),
      );
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    }
    if (data.containsKey('sold_at')) {
      context.handle(
        _soldAtMeta,
        soldAt.isAcceptableOrUnknown(data['sold_at']!, _soldAtMeta),
      );
    } else if (isInserting) {
      context.missing(_soldAtMeta);
    }
    if (data.containsKey('voided_at')) {
      context.handle(
        _voidedAtMeta,
        voidedAt.isAcceptableOrUnknown(data['voided_at']!, _voidedAtMeta),
      );
    }
    if (data.containsKey('void_reason')) {
      context.handle(
        _voidReasonMeta,
        voidReason.isAcceptableOrUnknown(data['void_reason']!, _voidReasonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Sale map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Sale(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      localNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_no'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      subtotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subtotal'],
      )!,
      discount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discount'],
      )!,
      tax: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tax'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      ),
      soldAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sold_at'],
      )!,
      voidedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voided_at'],
      ),
      voidReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}void_reason'],
      ),
    );
  }

  @override
  $SalesTable createAlias(String alias) {
    return $SalesTable(attachedDatabase, alias);
  }
}

class Sale extends DataClass implements Insertable<Sale> {
  final String id;
  final String localNo;
  final String status;
  final int subtotal;
  final int discount;
  final int tax;
  final int total;
  final String? customerId;
  final String soldAt;
  final String? voidedAt;
  final String? voidReason;
  const Sale({
    required this.id,
    required this.localNo,
    required this.status,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    this.customerId,
    required this.soldAt,
    this.voidedAt,
    this.voidReason,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['local_no'] = Variable<String>(localNo);
    map['status'] = Variable<String>(status);
    map['subtotal'] = Variable<int>(subtotal);
    map['discount'] = Variable<int>(discount);
    map['tax'] = Variable<int>(tax);
    map['total'] = Variable<int>(total);
    if (!nullToAbsent || customerId != null) {
      map['customer_id'] = Variable<String>(customerId);
    }
    map['sold_at'] = Variable<String>(soldAt);
    if (!nullToAbsent || voidedAt != null) {
      map['voided_at'] = Variable<String>(voidedAt);
    }
    if (!nullToAbsent || voidReason != null) {
      map['void_reason'] = Variable<String>(voidReason);
    }
    return map;
  }

  SalesCompanion toCompanion(bool nullToAbsent) {
    return SalesCompanion(
      id: Value(id),
      localNo: Value(localNo),
      status: Value(status),
      subtotal: Value(subtotal),
      discount: Value(discount),
      tax: Value(tax),
      total: Value(total),
      customerId: customerId == null && nullToAbsent
          ? const Value.absent()
          : Value(customerId),
      soldAt: Value(soldAt),
      voidedAt: voidedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(voidedAt),
      voidReason: voidReason == null && nullToAbsent
          ? const Value.absent()
          : Value(voidReason),
    );
  }

  factory Sale.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Sale(
      id: serializer.fromJson<String>(json['id']),
      localNo: serializer.fromJson<String>(json['localNo']),
      status: serializer.fromJson<String>(json['status']),
      subtotal: serializer.fromJson<int>(json['subtotal']),
      discount: serializer.fromJson<int>(json['discount']),
      tax: serializer.fromJson<int>(json['tax']),
      total: serializer.fromJson<int>(json['total']),
      customerId: serializer.fromJson<String?>(json['customerId']),
      soldAt: serializer.fromJson<String>(json['soldAt']),
      voidedAt: serializer.fromJson<String?>(json['voidedAt']),
      voidReason: serializer.fromJson<String?>(json['voidReason']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'localNo': serializer.toJson<String>(localNo),
      'status': serializer.toJson<String>(status),
      'subtotal': serializer.toJson<int>(subtotal),
      'discount': serializer.toJson<int>(discount),
      'tax': serializer.toJson<int>(tax),
      'total': serializer.toJson<int>(total),
      'customerId': serializer.toJson<String?>(customerId),
      'soldAt': serializer.toJson<String>(soldAt),
      'voidedAt': serializer.toJson<String?>(voidedAt),
      'voidReason': serializer.toJson<String?>(voidReason),
    };
  }

  Sale copyWith({
    String? id,
    String? localNo,
    String? status,
    int? subtotal,
    int? discount,
    int? tax,
    int? total,
    Value<String?> customerId = const Value.absent(),
    String? soldAt,
    Value<String?> voidedAt = const Value.absent(),
    Value<String?> voidReason = const Value.absent(),
  }) => Sale(
    id: id ?? this.id,
    localNo: localNo ?? this.localNo,
    status: status ?? this.status,
    subtotal: subtotal ?? this.subtotal,
    discount: discount ?? this.discount,
    tax: tax ?? this.tax,
    total: total ?? this.total,
    customerId: customerId.present ? customerId.value : this.customerId,
    soldAt: soldAt ?? this.soldAt,
    voidedAt: voidedAt.present ? voidedAt.value : this.voidedAt,
    voidReason: voidReason.present ? voidReason.value : this.voidReason,
  );
  Sale copyWithCompanion(SalesCompanion data) {
    return Sale(
      id: data.id.present ? data.id.value : this.id,
      localNo: data.localNo.present ? data.localNo.value : this.localNo,
      status: data.status.present ? data.status.value : this.status,
      subtotal: data.subtotal.present ? data.subtotal.value : this.subtotal,
      discount: data.discount.present ? data.discount.value : this.discount,
      tax: data.tax.present ? data.tax.value : this.tax,
      total: data.total.present ? data.total.value : this.total,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      soldAt: data.soldAt.present ? data.soldAt.value : this.soldAt,
      voidedAt: data.voidedAt.present ? data.voidedAt.value : this.voidedAt,
      voidReason: data.voidReason.present
          ? data.voidReason.value
          : this.voidReason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Sale(')
          ..write('id: $id, ')
          ..write('localNo: $localNo, ')
          ..write('status: $status, ')
          ..write('subtotal: $subtotal, ')
          ..write('discount: $discount, ')
          ..write('tax: $tax, ')
          ..write('total: $total, ')
          ..write('customerId: $customerId, ')
          ..write('soldAt: $soldAt, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('voidReason: $voidReason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    localNo,
    status,
    subtotal,
    discount,
    tax,
    total,
    customerId,
    soldAt,
    voidedAt,
    voidReason,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sale &&
          other.id == this.id &&
          other.localNo == this.localNo &&
          other.status == this.status &&
          other.subtotal == this.subtotal &&
          other.discount == this.discount &&
          other.tax == this.tax &&
          other.total == this.total &&
          other.customerId == this.customerId &&
          other.soldAt == this.soldAt &&
          other.voidedAt == this.voidedAt &&
          other.voidReason == this.voidReason);
}

class SalesCompanion extends UpdateCompanion<Sale> {
  final Value<String> id;
  final Value<String> localNo;
  final Value<String> status;
  final Value<int> subtotal;
  final Value<int> discount;
  final Value<int> tax;
  final Value<int> total;
  final Value<String?> customerId;
  final Value<String> soldAt;
  final Value<String?> voidedAt;
  final Value<String?> voidReason;
  final Value<int> rowid;
  const SalesCompanion({
    this.id = const Value.absent(),
    this.localNo = const Value.absent(),
    this.status = const Value.absent(),
    this.subtotal = const Value.absent(),
    this.discount = const Value.absent(),
    this.tax = const Value.absent(),
    this.total = const Value.absent(),
    this.customerId = const Value.absent(),
    this.soldAt = const Value.absent(),
    this.voidedAt = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SalesCompanion.insert({
    required String id,
    required String localNo,
    this.status = const Value.absent(),
    required int subtotal,
    this.discount = const Value.absent(),
    this.tax = const Value.absent(),
    required int total,
    this.customerId = const Value.absent(),
    required String soldAt,
    this.voidedAt = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       localNo = Value(localNo),
       subtotal = Value(subtotal),
       total = Value(total),
       soldAt = Value(soldAt);
  static Insertable<Sale> custom({
    Expression<String>? id,
    Expression<String>? localNo,
    Expression<String>? status,
    Expression<int>? subtotal,
    Expression<int>? discount,
    Expression<int>? tax,
    Expression<int>? total,
    Expression<String>? customerId,
    Expression<String>? soldAt,
    Expression<String>? voidedAt,
    Expression<String>? voidReason,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (localNo != null) 'local_no': localNo,
      if (status != null) 'status': status,
      if (subtotal != null) 'subtotal': subtotal,
      if (discount != null) 'discount': discount,
      if (tax != null) 'tax': tax,
      if (total != null) 'total': total,
      if (customerId != null) 'customer_id': customerId,
      if (soldAt != null) 'sold_at': soldAt,
      if (voidedAt != null) 'voided_at': voidedAt,
      if (voidReason != null) 'void_reason': voidReason,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SalesCompanion copyWith({
    Value<String>? id,
    Value<String>? localNo,
    Value<String>? status,
    Value<int>? subtotal,
    Value<int>? discount,
    Value<int>? tax,
    Value<int>? total,
    Value<String?>? customerId,
    Value<String>? soldAt,
    Value<String?>? voidedAt,
    Value<String?>? voidReason,
    Value<int>? rowid,
  }) {
    return SalesCompanion(
      id: id ?? this.id,
      localNo: localNo ?? this.localNo,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      customerId: customerId ?? this.customerId,
      soldAt: soldAt ?? this.soldAt,
      voidedAt: voidedAt ?? this.voidedAt,
      voidReason: voidReason ?? this.voidReason,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (localNo.present) {
      map['local_no'] = Variable<String>(localNo.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (subtotal.present) {
      map['subtotal'] = Variable<int>(subtotal.value);
    }
    if (discount.present) {
      map['discount'] = Variable<int>(discount.value);
    }
    if (tax.present) {
      map['tax'] = Variable<int>(tax.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (soldAt.present) {
      map['sold_at'] = Variable<String>(soldAt.value);
    }
    if (voidedAt.present) {
      map['voided_at'] = Variable<String>(voidedAt.value);
    }
    if (voidReason.present) {
      map['void_reason'] = Variable<String>(voidReason.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SalesCompanion(')
          ..write('id: $id, ')
          ..write('localNo: $localNo, ')
          ..write('status: $status, ')
          ..write('subtotal: $subtotal, ')
          ..write('discount: $discount, ')
          ..write('tax: $tax, ')
          ..write('total: $total, ')
          ..write('customerId: $customerId, ')
          ..write('soldAt: $soldAt, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('voidReason: $voidReason, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SaleItemsTable extends SaleItems
    with TableInfo<$SaleItemsTable, SaleItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SaleItemsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _saleIdMeta = const VerificationMeta('saleId');
  @override
  late final GeneratedColumn<String> saleId = GeneratedColumn<String>(
    'sale_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _variantIdMeta = const VerificationMeta(
    'variantId',
  );
  @override
  late final GeneratedColumn<String> variantId = GeneratedColumn<String>(
    'variant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<double> qty = GeneratedColumn<double>(
    'qty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitPriceMeta = const VerificationMeta(
    'unitPrice',
  );
  @override
  late final GeneratedColumn<int> unitPrice = GeneratedColumn<int>(
    'unit_price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitCostMeta = const VerificationMeta(
    'unitCost',
  );
  @override
  late final GeneratedColumn<int> unitCost = GeneratedColumn<int>(
    'unit_cost',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _discountMeta = const VerificationMeta(
    'discount',
  );
  @override
  late final GeneratedColumn<int> discount = GeneratedColumn<int>(
    'discount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _taxMeta = const VerificationMeta('tax');
  @override
  late final GeneratedColumn<int> tax = GeneratedColumn<int>(
    'tax',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lineTotalMeta = const VerificationMeta(
    'lineTotal',
  );
  @override
  late final GeneratedColumn<int> lineTotal = GeneratedColumn<int>(
    'line_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackedMeta = const VerificationMeta(
    'tracked',
  );
  @override
  late final GeneratedColumn<bool> tracked = GeneratedColumn<bool>(
    'tracked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tracked" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    saleId,
    variantId,
    name,
    qty,
    unitPrice,
    unitCost,
    discount,
    tax,
    lineTotal,
    tracked,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sale_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<SaleItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sale_id')) {
      context.handle(
        _saleIdMeta,
        saleId.isAcceptableOrUnknown(data['sale_id']!, _saleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_saleIdMeta);
    }
    if (data.containsKey('variant_id')) {
      context.handle(
        _variantIdMeta,
        variantId.isAcceptableOrUnknown(data['variant_id']!, _variantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_variantIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
        _qtyMeta,
        qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    if (data.containsKey('unit_price')) {
      context.handle(
        _unitPriceMeta,
        unitPrice.isAcceptableOrUnknown(data['unit_price']!, _unitPriceMeta),
      );
    } else if (isInserting) {
      context.missing(_unitPriceMeta);
    }
    if (data.containsKey('unit_cost')) {
      context.handle(
        _unitCostMeta,
        unitCost.isAcceptableOrUnknown(data['unit_cost']!, _unitCostMeta),
      );
    }
    if (data.containsKey('discount')) {
      context.handle(
        _discountMeta,
        discount.isAcceptableOrUnknown(data['discount']!, _discountMeta),
      );
    }
    if (data.containsKey('tax')) {
      context.handle(
        _taxMeta,
        tax.isAcceptableOrUnknown(data['tax']!, _taxMeta),
      );
    }
    if (data.containsKey('line_total')) {
      context.handle(
        _lineTotalMeta,
        lineTotal.isAcceptableOrUnknown(data['line_total']!, _lineTotalMeta),
      );
    } else if (isInserting) {
      context.missing(_lineTotalMeta);
    }
    if (data.containsKey('tracked')) {
      context.handle(
        _trackedMeta,
        tracked.isAcceptableOrUnknown(data['tracked']!, _trackedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SaleItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SaleItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      saleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sale_id'],
      )!,
      variantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variant_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      qty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}qty'],
      )!,
      unitPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_price'],
      )!,
      unitCost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_cost'],
      )!,
      discount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discount'],
      )!,
      tax: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tax'],
      )!,
      lineTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_total'],
      )!,
      tracked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tracked'],
      )!,
    );
  }

  @override
  $SaleItemsTable createAlias(String alias) {
    return $SaleItemsTable(attachedDatabase, alias);
  }
}

class SaleItem extends DataClass implements Insertable<SaleItem> {
  final int id;
  final String saleId;
  final String variantId;
  final String name;
  final double qty;
  final int unitPrice;
  final int unitCost;
  final int discount;
  final int tax;
  final int lineTotal;
  final bool tracked;
  const SaleItem({
    required this.id,
    required this.saleId,
    required this.variantId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.unitCost,
    required this.discount,
    required this.tax,
    required this.lineTotal,
    required this.tracked,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sale_id'] = Variable<String>(saleId);
    map['variant_id'] = Variable<String>(variantId);
    map['name'] = Variable<String>(name);
    map['qty'] = Variable<double>(qty);
    map['unit_price'] = Variable<int>(unitPrice);
    map['unit_cost'] = Variable<int>(unitCost);
    map['discount'] = Variable<int>(discount);
    map['tax'] = Variable<int>(tax);
    map['line_total'] = Variable<int>(lineTotal);
    map['tracked'] = Variable<bool>(tracked);
    return map;
  }

  SaleItemsCompanion toCompanion(bool nullToAbsent) {
    return SaleItemsCompanion(
      id: Value(id),
      saleId: Value(saleId),
      variantId: Value(variantId),
      name: Value(name),
      qty: Value(qty),
      unitPrice: Value(unitPrice),
      unitCost: Value(unitCost),
      discount: Value(discount),
      tax: Value(tax),
      lineTotal: Value(lineTotal),
      tracked: Value(tracked),
    );
  }

  factory SaleItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SaleItem(
      id: serializer.fromJson<int>(json['id']),
      saleId: serializer.fromJson<String>(json['saleId']),
      variantId: serializer.fromJson<String>(json['variantId']),
      name: serializer.fromJson<String>(json['name']),
      qty: serializer.fromJson<double>(json['qty']),
      unitPrice: serializer.fromJson<int>(json['unitPrice']),
      unitCost: serializer.fromJson<int>(json['unitCost']),
      discount: serializer.fromJson<int>(json['discount']),
      tax: serializer.fromJson<int>(json['tax']),
      lineTotal: serializer.fromJson<int>(json['lineTotal']),
      tracked: serializer.fromJson<bool>(json['tracked']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'saleId': serializer.toJson<String>(saleId),
      'variantId': serializer.toJson<String>(variantId),
      'name': serializer.toJson<String>(name),
      'qty': serializer.toJson<double>(qty),
      'unitPrice': serializer.toJson<int>(unitPrice),
      'unitCost': serializer.toJson<int>(unitCost),
      'discount': serializer.toJson<int>(discount),
      'tax': serializer.toJson<int>(tax),
      'lineTotal': serializer.toJson<int>(lineTotal),
      'tracked': serializer.toJson<bool>(tracked),
    };
  }

  SaleItem copyWith({
    int? id,
    String? saleId,
    String? variantId,
    String? name,
    double? qty,
    int? unitPrice,
    int? unitCost,
    int? discount,
    int? tax,
    int? lineTotal,
    bool? tracked,
  }) => SaleItem(
    id: id ?? this.id,
    saleId: saleId ?? this.saleId,
    variantId: variantId ?? this.variantId,
    name: name ?? this.name,
    qty: qty ?? this.qty,
    unitPrice: unitPrice ?? this.unitPrice,
    unitCost: unitCost ?? this.unitCost,
    discount: discount ?? this.discount,
    tax: tax ?? this.tax,
    lineTotal: lineTotal ?? this.lineTotal,
    tracked: tracked ?? this.tracked,
  );
  SaleItem copyWithCompanion(SaleItemsCompanion data) {
    return SaleItem(
      id: data.id.present ? data.id.value : this.id,
      saleId: data.saleId.present ? data.saleId.value : this.saleId,
      variantId: data.variantId.present ? data.variantId.value : this.variantId,
      name: data.name.present ? data.name.value : this.name,
      qty: data.qty.present ? data.qty.value : this.qty,
      unitPrice: data.unitPrice.present ? data.unitPrice.value : this.unitPrice,
      unitCost: data.unitCost.present ? data.unitCost.value : this.unitCost,
      discount: data.discount.present ? data.discount.value : this.discount,
      tax: data.tax.present ? data.tax.value : this.tax,
      lineTotal: data.lineTotal.present ? data.lineTotal.value : this.lineTotal,
      tracked: data.tracked.present ? data.tracked.value : this.tracked,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SaleItem(')
          ..write('id: $id, ')
          ..write('saleId: $saleId, ')
          ..write('variantId: $variantId, ')
          ..write('name: $name, ')
          ..write('qty: $qty, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('unitCost: $unitCost, ')
          ..write('discount: $discount, ')
          ..write('tax: $tax, ')
          ..write('lineTotal: $lineTotal, ')
          ..write('tracked: $tracked')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    saleId,
    variantId,
    name,
    qty,
    unitPrice,
    unitCost,
    discount,
    tax,
    lineTotal,
    tracked,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SaleItem &&
          other.id == this.id &&
          other.saleId == this.saleId &&
          other.variantId == this.variantId &&
          other.name == this.name &&
          other.qty == this.qty &&
          other.unitPrice == this.unitPrice &&
          other.unitCost == this.unitCost &&
          other.discount == this.discount &&
          other.tax == this.tax &&
          other.lineTotal == this.lineTotal &&
          other.tracked == this.tracked);
}

class SaleItemsCompanion extends UpdateCompanion<SaleItem> {
  final Value<int> id;
  final Value<String> saleId;
  final Value<String> variantId;
  final Value<String> name;
  final Value<double> qty;
  final Value<int> unitPrice;
  final Value<int> unitCost;
  final Value<int> discount;
  final Value<int> tax;
  final Value<int> lineTotal;
  final Value<bool> tracked;
  const SaleItemsCompanion({
    this.id = const Value.absent(),
    this.saleId = const Value.absent(),
    this.variantId = const Value.absent(),
    this.name = const Value.absent(),
    this.qty = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.unitCost = const Value.absent(),
    this.discount = const Value.absent(),
    this.tax = const Value.absent(),
    this.lineTotal = const Value.absent(),
    this.tracked = const Value.absent(),
  });
  SaleItemsCompanion.insert({
    this.id = const Value.absent(),
    required String saleId,
    required String variantId,
    required String name,
    required double qty,
    required int unitPrice,
    this.unitCost = const Value.absent(),
    this.discount = const Value.absent(),
    this.tax = const Value.absent(),
    required int lineTotal,
    this.tracked = const Value.absent(),
  }) : saleId = Value(saleId),
       variantId = Value(variantId),
       name = Value(name),
       qty = Value(qty),
       unitPrice = Value(unitPrice),
       lineTotal = Value(lineTotal);
  static Insertable<SaleItem> custom({
    Expression<int>? id,
    Expression<String>? saleId,
    Expression<String>? variantId,
    Expression<String>? name,
    Expression<double>? qty,
    Expression<int>? unitPrice,
    Expression<int>? unitCost,
    Expression<int>? discount,
    Expression<int>? tax,
    Expression<int>? lineTotal,
    Expression<bool>? tracked,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (saleId != null) 'sale_id': saleId,
      if (variantId != null) 'variant_id': variantId,
      if (name != null) 'name': name,
      if (qty != null) 'qty': qty,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (unitCost != null) 'unit_cost': unitCost,
      if (discount != null) 'discount': discount,
      if (tax != null) 'tax': tax,
      if (lineTotal != null) 'line_total': lineTotal,
      if (tracked != null) 'tracked': tracked,
    });
  }

  SaleItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? saleId,
    Value<String>? variantId,
    Value<String>? name,
    Value<double>? qty,
    Value<int>? unitPrice,
    Value<int>? unitCost,
    Value<int>? discount,
    Value<int>? tax,
    Value<int>? lineTotal,
    Value<bool>? tracked,
  }) {
    return SaleItemsCompanion(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      variantId: variantId ?? this.variantId,
      name: name ?? this.name,
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice,
      unitCost: unitCost ?? this.unitCost,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      lineTotal: lineTotal ?? this.lineTotal,
      tracked: tracked ?? this.tracked,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (saleId.present) {
      map['sale_id'] = Variable<String>(saleId.value);
    }
    if (variantId.present) {
      map['variant_id'] = Variable<String>(variantId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (qty.present) {
      map['qty'] = Variable<double>(qty.value);
    }
    if (unitPrice.present) {
      map['unit_price'] = Variable<int>(unitPrice.value);
    }
    if (unitCost.present) {
      map['unit_cost'] = Variable<int>(unitCost.value);
    }
    if (discount.present) {
      map['discount'] = Variable<int>(discount.value);
    }
    if (tax.present) {
      map['tax'] = Variable<int>(tax.value);
    }
    if (lineTotal.present) {
      map['line_total'] = Variable<int>(lineTotal.value);
    }
    if (tracked.present) {
      map['tracked'] = Variable<bool>(tracked.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SaleItemsCompanion(')
          ..write('id: $id, ')
          ..write('saleId: $saleId, ')
          ..write('variantId: $variantId, ')
          ..write('name: $name, ')
          ..write('qty: $qty, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('unitCost: $unitCost, ')
          ..write('discount: $discount, ')
          ..write('tax: $tax, ')
          ..write('lineTotal: $lineTotal, ')
          ..write('tracked: $tracked')
          ..write(')'))
        .toString();
  }
}

class $SalePaymentsTable extends SalePayments
    with TableInfo<$SalePaymentsTable, SalePayment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SalePaymentsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _saleIdMeta = const VerificationMeta('saleId');
  @override
  late final GeneratedColumn<String> saleId = GeneratedColumn<String>(
    'sale_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenderedMeta = const VerificationMeta(
    'tendered',
  );
  @override
  late final GeneratedColumn<int> tendered = GeneratedColumn<int>(
    'tendered',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceMeta = const VerificationMeta(
    'reference',
  );
  @override
  late final GeneratedColumn<String> reference = GeneratedColumn<String>(
    'reference',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    saleId,
    method,
    amount,
    tendered,
    reference,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sale_payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<SalePayment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sale_id')) {
      context.handle(
        _saleIdMeta,
        saleId.isAcceptableOrUnknown(data['sale_id']!, _saleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_saleIdMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('tendered')) {
      context.handle(
        _tenderedMeta,
        tendered.isAcceptableOrUnknown(data['tendered']!, _tenderedMeta),
      );
    }
    if (data.containsKey('reference')) {
      context.handle(
        _referenceMeta,
        reference.isAcceptableOrUnknown(data['reference']!, _referenceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SalePayment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SalePayment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      saleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sale_id'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      tendered: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tendered'],
      ),
      reference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference'],
      ),
    );
  }

  @override
  $SalePaymentsTable createAlias(String alias) {
    return $SalePaymentsTable(attachedDatabase, alias);
  }
}

class SalePayment extends DataClass implements Insertable<SalePayment> {
  final int id;
  final String saleId;
  final String method;
  final int amount;
  final int? tendered;
  final String? reference;
  const SalePayment({
    required this.id,
    required this.saleId,
    required this.method,
    required this.amount,
    this.tendered,
    this.reference,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sale_id'] = Variable<String>(saleId);
    map['method'] = Variable<String>(method);
    map['amount'] = Variable<int>(amount);
    if (!nullToAbsent || tendered != null) {
      map['tendered'] = Variable<int>(tendered);
    }
    if (!nullToAbsent || reference != null) {
      map['reference'] = Variable<String>(reference);
    }
    return map;
  }

  SalePaymentsCompanion toCompanion(bool nullToAbsent) {
    return SalePaymentsCompanion(
      id: Value(id),
      saleId: Value(saleId),
      method: Value(method),
      amount: Value(amount),
      tendered: tendered == null && nullToAbsent
          ? const Value.absent()
          : Value(tendered),
      reference: reference == null && nullToAbsent
          ? const Value.absent()
          : Value(reference),
    );
  }

  factory SalePayment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SalePayment(
      id: serializer.fromJson<int>(json['id']),
      saleId: serializer.fromJson<String>(json['saleId']),
      method: serializer.fromJson<String>(json['method']),
      amount: serializer.fromJson<int>(json['amount']),
      tendered: serializer.fromJson<int?>(json['tendered']),
      reference: serializer.fromJson<String?>(json['reference']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'saleId': serializer.toJson<String>(saleId),
      'method': serializer.toJson<String>(method),
      'amount': serializer.toJson<int>(amount),
      'tendered': serializer.toJson<int?>(tendered),
      'reference': serializer.toJson<String?>(reference),
    };
  }

  SalePayment copyWith({
    int? id,
    String? saleId,
    String? method,
    int? amount,
    Value<int?> tendered = const Value.absent(),
    Value<String?> reference = const Value.absent(),
  }) => SalePayment(
    id: id ?? this.id,
    saleId: saleId ?? this.saleId,
    method: method ?? this.method,
    amount: amount ?? this.amount,
    tendered: tendered.present ? tendered.value : this.tendered,
    reference: reference.present ? reference.value : this.reference,
  );
  SalePayment copyWithCompanion(SalePaymentsCompanion data) {
    return SalePayment(
      id: data.id.present ? data.id.value : this.id,
      saleId: data.saleId.present ? data.saleId.value : this.saleId,
      method: data.method.present ? data.method.value : this.method,
      amount: data.amount.present ? data.amount.value : this.amount,
      tendered: data.tendered.present ? data.tendered.value : this.tendered,
      reference: data.reference.present ? data.reference.value : this.reference,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SalePayment(')
          ..write('id: $id, ')
          ..write('saleId: $saleId, ')
          ..write('method: $method, ')
          ..write('amount: $amount, ')
          ..write('tendered: $tendered, ')
          ..write('reference: $reference')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, saleId, method, amount, tendered, reference);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SalePayment &&
          other.id == this.id &&
          other.saleId == this.saleId &&
          other.method == this.method &&
          other.amount == this.amount &&
          other.tendered == this.tendered &&
          other.reference == this.reference);
}

class SalePaymentsCompanion extends UpdateCompanion<SalePayment> {
  final Value<int> id;
  final Value<String> saleId;
  final Value<String> method;
  final Value<int> amount;
  final Value<int?> tendered;
  final Value<String?> reference;
  const SalePaymentsCompanion({
    this.id = const Value.absent(),
    this.saleId = const Value.absent(),
    this.method = const Value.absent(),
    this.amount = const Value.absent(),
    this.tendered = const Value.absent(),
    this.reference = const Value.absent(),
  });
  SalePaymentsCompanion.insert({
    this.id = const Value.absent(),
    required String saleId,
    required String method,
    required int amount,
    this.tendered = const Value.absent(),
    this.reference = const Value.absent(),
  }) : saleId = Value(saleId),
       method = Value(method),
       amount = Value(amount);
  static Insertable<SalePayment> custom({
    Expression<int>? id,
    Expression<String>? saleId,
    Expression<String>? method,
    Expression<int>? amount,
    Expression<int>? tendered,
    Expression<String>? reference,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (saleId != null) 'sale_id': saleId,
      if (method != null) 'method': method,
      if (amount != null) 'amount': amount,
      if (tendered != null) 'tendered': tendered,
      if (reference != null) 'reference': reference,
    });
  }

  SalePaymentsCompanion copyWith({
    Value<int>? id,
    Value<String>? saleId,
    Value<String>? method,
    Value<int>? amount,
    Value<int?>? tendered,
    Value<String?>? reference,
  }) {
    return SalePaymentsCompanion(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      method: method ?? this.method,
      amount: amount ?? this.amount,
      tendered: tendered ?? this.tendered,
      reference: reference ?? this.reference,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (saleId.present) {
      map['sale_id'] = Variable<String>(saleId.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (tendered.present) {
      map['tendered'] = Variable<int>(tendered.value);
    }
    if (reference.present) {
      map['reference'] = Variable<String>(reference.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SalePaymentsCompanion(')
          ..write('id: $id, ')
          ..write('saleId: $saleId, ')
          ..write('method: $method, ')
          ..write('amount: $amount, ')
          ..write('tendered: $tendered, ')
          ..write('reference: $reference')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $ProductsTable products = $ProductsTable(this);
  late final $VariantsTable variants = $VariantsTable(this);
  late final $PricesTable prices = $PricesTable(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $OpeningStockTable openingStock = $OpeningStockTable(this);
  late final $MetaTable meta = $MetaTable(this);
  late final $PhotoUploadsTable photoUploads = $PhotoUploadsTable(this);
  late final $PhotoCacheTable photoCache = $PhotoCacheTable(this);
  late final $CustomersTable customers = $CustomersTable(this);
  late final $ServerLedgerTable serverLedger = $ServerLedgerTable(this);
  late final $LocalLedgerTable localLedger = $LocalLedgerTable(this);
  late final $StockLevelsTable stockLevels = $StockLevelsTable(this);
  late final $LocalMovementsTable localMovements = $LocalMovementsTable(this);
  late final $SalesTable sales = $SalesTable(this);
  late final $SaleItemsTable saleItems = $SaleItemsTable(this);
  late final $SalePaymentsTable salePayments = $SalePaymentsTable(this);
  late final Index variantsBarcode = Index(
    'variants_barcode',
    'CREATE INDEX variants_barcode ON variants (barcode)',
  );
  late final Index variantsProduct = Index(
    'variants_product',
    'CREATE INDEX variants_product ON variants (product_id)',
  );
  late final Index salesSoldAt = Index(
    'sales_sold_at',
    'CREATE INDEX sales_sold_at ON sales (sold_at)',
  );
  late final Index saleItemsSale = Index(
    'sale_items_sale',
    'CREATE INDEX sale_items_sale ON sale_items (sale_id)',
  );
  late final Index salePaymentsSale = Index(
    'sale_payments_sale',
    'CREATE INDEX sale_payments_sale ON sale_payments (sale_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    categories,
    products,
    variants,
    prices,
    syncCursors,
    outbox,
    openingStock,
    meta,
    photoUploads,
    photoCache,
    customers,
    serverLedger,
    localLedger,
    stockLevels,
    localMovements,
    sales,
    saleItems,
    salePayments,
    variantsBarcode,
    variantsProduct,
    salesSoldAt,
    saleItemsSale,
    salePaymentsSale,
  ];
}

typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      required String id,
      Value<String?> parentId,
      required String name,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<String> id,
      Value<String?> parentId,
      Value<String> name,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
          Category,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                parentId: parentId,
                name: name,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> parentId = const Value.absent(),
                required String name,
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                parentId: parentId,
                name: name,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
      Category,
      PrefetchHooks Function()
    >;
typedef $$ProductsTableCreateCompanionBuilder =
    ProductsCompanion Function({
      required String id,
      Value<String?> categoryId,
      required String name,
      Value<String> searchName,
      Value<String> unit,
      Value<double> taxRate,
      Value<bool> trackStock,
      Value<bool> active,
      Value<String?> photoPath,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$ProductsTableUpdateCompanionBuilder =
    ProductsCompanion Function({
      Value<String> id,
      Value<String?> categoryId,
      Value<String> name,
      Value<String> searchName,
      Value<String> unit,
      Value<double> taxRate,
      Value<bool> trackStock,
      Value<bool> active,
      Value<String?> photoPath,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$ProductsTableFilterComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchName => $composableBuilder(
    column: $table.searchName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get taxRate => $composableBuilder(
    column: $table.taxRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get trackStock => $composableBuilder(
    column: $table.trackStock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchName => $composableBuilder(
    column: $table.searchName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get taxRate => $composableBuilder(
    column: $table.taxRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get trackStock => $composableBuilder(
    column: $table.trackStock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get searchName => $composableBuilder(
    column: $table.searchName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<double> get taxRate =>
      $composableBuilder(column: $table.taxRate, builder: (column) => column);

  GeneratedColumn<bool> get trackStock => $composableBuilder(
    column: $table.trackStock,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ProductsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductsTable,
          Product,
          $$ProductsTableFilterComposer,
          $$ProductsTableOrderingComposer,
          $$ProductsTableAnnotationComposer,
          $$ProductsTableCreateCompanionBuilder,
          $$ProductsTableUpdateCompanionBuilder,
          (Product, BaseReferences<_$AppDatabase, $ProductsTable, Product>),
          Product,
          PrefetchHooks Function()
        > {
  $$ProductsTableTableManager(_$AppDatabase db, $ProductsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> searchName = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<double> taxRate = const Value.absent(),
                Value<bool> trackStock = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductsCompanion(
                id: id,
                categoryId: categoryId,
                name: name,
                searchName: searchName,
                unit: unit,
                taxRate: taxRate,
                trackStock: trackStock,
                active: active,
                photoPath: photoPath,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> categoryId = const Value.absent(),
                required String name,
                Value<String> searchName = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<double> taxRate = const Value.absent(),
                Value<bool> trackStock = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductsCompanion.insert(
                id: id,
                categoryId: categoryId,
                name: name,
                searchName: searchName,
                unit: unit,
                taxRate: taxRate,
                trackStock: trackStock,
                active: active,
                photoPath: photoPath,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductsTable,
      Product,
      $$ProductsTableFilterComposer,
      $$ProductsTableOrderingComposer,
      $$ProductsTableAnnotationComposer,
      $$ProductsTableCreateCompanionBuilder,
      $$ProductsTableUpdateCompanionBuilder,
      (Product, BaseReferences<_$AppDatabase, $ProductsTable, Product>),
      Product,
      PrefetchHooks Function()
    >;
typedef $$VariantsTableCreateCompanionBuilder =
    VariantsCompanion Function({
      required String id,
      required String productId,
      required String sku,
      Value<String?> barcode,
      Value<bool> isDefault,
      Value<int> cost,
      Value<double> reorderPoint,
      Value<bool> active,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$VariantsTableUpdateCompanionBuilder =
    VariantsCompanion Function({
      Value<String> id,
      Value<String> productId,
      Value<String> sku,
      Value<String?> barcode,
      Value<bool> isDefault,
      Value<int> cost,
      Value<double> reorderPoint,
      Value<bool> active,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$VariantsTableFilterComposer
    extends Composer<_$AppDatabase, $VariantsTable> {
  $$VariantsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sku => $composableBuilder(
    column: $table.sku,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cost => $composableBuilder(
    column: $table.cost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get reorderPoint => $composableBuilder(
    column: $table.reorderPoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VariantsTableOrderingComposer
    extends Composer<_$AppDatabase, $VariantsTable> {
  $$VariantsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sku => $composableBuilder(
    column: $table.sku,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cost => $composableBuilder(
    column: $table.cost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get reorderPoint => $composableBuilder(
    column: $table.reorderPoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VariantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VariantsTable> {
  $$VariantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get sku =>
      $composableBuilder(column: $table.sku, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<int> get cost =>
      $composableBuilder(column: $table.cost, builder: (column) => column);

  GeneratedColumn<double> get reorderPoint => $composableBuilder(
    column: $table.reorderPoint,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$VariantsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VariantsTable,
          Variant,
          $$VariantsTableFilterComposer,
          $$VariantsTableOrderingComposer,
          $$VariantsTableAnnotationComposer,
          $$VariantsTableCreateCompanionBuilder,
          $$VariantsTableUpdateCompanionBuilder,
          (Variant, BaseReferences<_$AppDatabase, $VariantsTable, Variant>),
          Variant,
          PrefetchHooks Function()
        > {
  $$VariantsTableTableManager(_$AppDatabase db, $VariantsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VariantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VariantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VariantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<String> sku = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> cost = const Value.absent(),
                Value<double> reorderPoint = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VariantsCompanion(
                id: id,
                productId: productId,
                sku: sku,
                barcode: barcode,
                isDefault: isDefault,
                cost: cost,
                reorderPoint: reorderPoint,
                active: active,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String productId,
                required String sku,
                Value<String?> barcode = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> cost = const Value.absent(),
                Value<double> reorderPoint = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VariantsCompanion.insert(
                id: id,
                productId: productId,
                sku: sku,
                barcode: barcode,
                isDefault: isDefault,
                cost: cost,
                reorderPoint: reorderPoint,
                active: active,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VariantsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VariantsTable,
      Variant,
      $$VariantsTableFilterComposer,
      $$VariantsTableOrderingComposer,
      $$VariantsTableAnnotationComposer,
      $$VariantsTableCreateCompanionBuilder,
      $$VariantsTableUpdateCompanionBuilder,
      (Variant, BaseReferences<_$AppDatabase, $VariantsTable, Variant>),
      Variant,
      PrefetchHooks Function()
    >;
typedef $$PricesTableCreateCompanionBuilder =
    PricesCompanion Function({
      required String variantId,
      required String currency,
      required int price,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$PricesTableUpdateCompanionBuilder =
    PricesCompanion Function({
      Value<String> variantId,
      Value<String> currency,
      Value<int> price,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$PricesTableFilterComposer
    extends Composer<_$AppDatabase, $PricesTable> {
  $$PricesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get variantId => $composableBuilder(
    column: $table.variantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PricesTableOrderingComposer
    extends Composer<_$AppDatabase, $PricesTable> {
  $$PricesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get variantId => $composableBuilder(
    column: $table.variantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PricesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PricesTable> {
  $$PricesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get variantId =>
      $composableBuilder(column: $table.variantId, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$PricesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PricesTable,
          Price,
          $$PricesTableFilterComposer,
          $$PricesTableOrderingComposer,
          $$PricesTableAnnotationComposer,
          $$PricesTableCreateCompanionBuilder,
          $$PricesTableUpdateCompanionBuilder,
          (Price, BaseReferences<_$AppDatabase, $PricesTable, Price>),
          Price,
          PrefetchHooks Function()
        > {
  $$PricesTableTableManager(_$AppDatabase db, $PricesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PricesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PricesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PricesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> variantId = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int> price = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PricesCompanion(
                variantId: variantId,
                currency: currency,
                price: price,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String variantId,
                required String currency,
                required int price,
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PricesCompanion.insert(
                variantId: variantId,
                currency: currency,
                price: price,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PricesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PricesTable,
      Price,
      $$PricesTableFilterComposer,
      $$PricesTableOrderingComposer,
      $$PricesTableAnnotationComposer,
      $$PricesTableCreateCompanionBuilder,
      $$PricesTableUpdateCompanionBuilder,
      (Price, BaseReferences<_$AppDatabase, $PricesTable, Price>),
      Price,
      PrefetchHooks Function()
    >;
typedef $$SyncCursorsTableCreateCompanionBuilder =
    SyncCursorsCompanion Function({
      required String tableKey,
      required String cursorJson,
      Value<int> rowid,
    });
typedef $$SyncCursorsTableUpdateCompanionBuilder =
    SyncCursorsCompanion Function({
      Value<String> tableKey,
      Value<String> cursorJson,
      Value<int> rowid,
    });

class $$SyncCursorsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tableKey => $composableBuilder(
    column: $table.tableKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursorJson => $composableBuilder(
    column: $table.cursorJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncCursorsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tableKey => $composableBuilder(
    column: $table.tableKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursorJson => $composableBuilder(
    column: $table.cursorJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncCursorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tableKey =>
      $composableBuilder(column: $table.tableKey, builder: (column) => column);

  GeneratedColumn<String> get cursorJson => $composableBuilder(
    column: $table.cursorJson,
    builder: (column) => column,
  );
}

class $$SyncCursorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncCursorsTable,
          SyncCursor,
          $$SyncCursorsTableFilterComposer,
          $$SyncCursorsTableOrderingComposer,
          $$SyncCursorsTableAnnotationComposer,
          $$SyncCursorsTableCreateCompanionBuilder,
          $$SyncCursorsTableUpdateCompanionBuilder,
          (
            SyncCursor,
            BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>,
          ),
          SyncCursor,
          PrefetchHooks Function()
        > {
  $$SyncCursorsTableTableManager(_$AppDatabase db, $SyncCursorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tableKey = const Value.absent(),
                Value<String> cursorJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion(
                tableKey: tableKey,
                cursorJson: cursorJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tableKey,
                required String cursorJson,
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion.insert(
                tableKey: tableKey,
                cursorJson: cursorJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncCursorsTable,
      SyncCursor,
      $$SyncCursorsTableFilterComposer,
      $$SyncCursorsTableOrderingComposer,
      $$SyncCursorsTableAnnotationComposer,
      $$SyncCursorsTableCreateCompanionBuilder,
      $$SyncCursorsTableUpdateCompanionBuilder,
      (
        SyncCursor,
        BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>,
      ),
      SyncCursor,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder =
    OutboxCompanion Function({
      required String opId,
      Value<int> seq,
      required String kind,
      required String entityId,
      required String payload,
      Value<String> status,
      Value<int> attempts,
      Value<String?> lastError,
      required DateTime createdAt,
    });
typedef $$OutboxTableUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<String> opId,
      Value<int> seq,
      Value<String> kind,
      Value<String> entityId,
      Value<String> payload,
      Value<String> status,
      Value<int> attempts,
      Value<String?> lastError,
      Value<DateTime> createdAt,
    });

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get opId =>
      $composableBuilder(column: $table.opId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxData,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
          OutboxData,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> opId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => OutboxCompanion(
                opId: opId,
                seq: seq,
                kind: kind,
                entityId: entityId,
                payload: payload,
                status: status,
                attempts: attempts,
                lastError: lastError,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                required String opId,
                Value<int> seq = const Value.absent(),
                required String kind,
                required String entityId,
                required String payload,
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
              }) => OutboxCompanion.insert(
                opId: opId,
                seq: seq,
                kind: kind,
                entityId: entityId,
                payload: payload,
                status: status,
                attempts: attempts,
                lastError: lastError,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxData,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
      OutboxData,
      PrefetchHooks Function()
    >;
typedef $$OpeningStockTableCreateCompanionBuilder =
    OpeningStockCompanion Function({
      required String variantId,
      required double qty,
      Value<int> rowid,
    });
typedef $$OpeningStockTableUpdateCompanionBuilder =
    OpeningStockCompanion Function({
      Value<String> variantId,
      Value<double> qty,
      Value<int> rowid,
    });

class $$OpeningStockTableFilterComposer
    extends Composer<_$AppDatabase, $OpeningStockTable> {
  $$OpeningStockTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get variantId => $composableBuilder(
    column: $table.variantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OpeningStockTableOrderingComposer
    extends Composer<_$AppDatabase, $OpeningStockTable> {
  $$OpeningStockTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get variantId => $composableBuilder(
    column: $table.variantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OpeningStockTableAnnotationComposer
    extends Composer<_$AppDatabase, $OpeningStockTable> {
  $$OpeningStockTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get variantId =>
      $composableBuilder(column: $table.variantId, builder: (column) => column);

  GeneratedColumn<double> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);
}

class $$OpeningStockTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OpeningStockTable,
          OpeningStockData,
          $$OpeningStockTableFilterComposer,
          $$OpeningStockTableOrderingComposer,
          $$OpeningStockTableAnnotationComposer,
          $$OpeningStockTableCreateCompanionBuilder,
          $$OpeningStockTableUpdateCompanionBuilder,
          (
            OpeningStockData,
            BaseReferences<_$AppDatabase, $OpeningStockTable, OpeningStockData>,
          ),
          OpeningStockData,
          PrefetchHooks Function()
        > {
  $$OpeningStockTableTableManager(_$AppDatabase db, $OpeningStockTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OpeningStockTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OpeningStockTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OpeningStockTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> variantId = const Value.absent(),
                Value<double> qty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OpeningStockCompanion(
                variantId: variantId,
                qty: qty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String variantId,
                required double qty,
                Value<int> rowid = const Value.absent(),
              }) => OpeningStockCompanion.insert(
                variantId: variantId,
                qty: qty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OpeningStockTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OpeningStockTable,
      OpeningStockData,
      $$OpeningStockTableFilterComposer,
      $$OpeningStockTableOrderingComposer,
      $$OpeningStockTableAnnotationComposer,
      $$OpeningStockTableCreateCompanionBuilder,
      $$OpeningStockTableUpdateCompanionBuilder,
      (
        OpeningStockData,
        BaseReferences<_$AppDatabase, $OpeningStockTable, OpeningStockData>,
      ),
      OpeningStockData,
      PrefetchHooks Function()
    >;
typedef $$MetaTableCreateCompanionBuilder =
    MetaCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$MetaTableUpdateCompanionBuilder =
    MetaCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$MetaTableFilterComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableFilterComposer({
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

class $$MetaTableOrderingComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableOrderingComposer({
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

class $$MetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableAnnotationComposer({
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

class $$MetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetaTable,
          MetaData,
          $$MetaTableFilterComposer,
          $$MetaTableOrderingComposer,
          $$MetaTableAnnotationComposer,
          $$MetaTableCreateCompanionBuilder,
          $$MetaTableUpdateCompanionBuilder,
          (MetaData, BaseReferences<_$AppDatabase, $MetaTable, MetaData>),
          MetaData,
          PrefetchHooks Function()
        > {
  $$MetaTableTableManager(_$AppDatabase db, $MetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => MetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetaTable,
      MetaData,
      $$MetaTableFilterComposer,
      $$MetaTableOrderingComposer,
      $$MetaTableAnnotationComposer,
      $$MetaTableCreateCompanionBuilder,
      $$MetaTableUpdateCompanionBuilder,
      (MetaData, BaseReferences<_$AppDatabase, $MetaTable, MetaData>),
      MetaData,
      PrefetchHooks Function()
    >;
typedef $$PhotoUploadsTableCreateCompanionBuilder =
    PhotoUploadsCompanion Function({
      required String opId,
      required String productId,
      required String path,
      required Uint8List bytes,
      Value<int> rowid,
    });
typedef $$PhotoUploadsTableUpdateCompanionBuilder =
    PhotoUploadsCompanion Function({
      Value<String> opId,
      Value<String> productId,
      Value<String> path,
      Value<Uint8List> bytes,
      Value<int> rowid,
    });

class $$PhotoUploadsTableFilterComposer
    extends Composer<_$AppDatabase, $PhotoUploadsTable> {
  $$PhotoUploadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PhotoUploadsTableOrderingComposer
    extends Composer<_$AppDatabase, $PhotoUploadsTable> {
  $$PhotoUploadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhotoUploadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhotoUploadsTable> {
  $$PhotoUploadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get opId =>
      $composableBuilder(column: $table.opId, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);
}

class $$PhotoUploadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhotoUploadsTable,
          PhotoUpload,
          $$PhotoUploadsTableFilterComposer,
          $$PhotoUploadsTableOrderingComposer,
          $$PhotoUploadsTableAnnotationComposer,
          $$PhotoUploadsTableCreateCompanionBuilder,
          $$PhotoUploadsTableUpdateCompanionBuilder,
          (
            PhotoUpload,
            BaseReferences<_$AppDatabase, $PhotoUploadsTable, PhotoUpload>,
          ),
          PhotoUpload,
          PrefetchHooks Function()
        > {
  $$PhotoUploadsTableTableManager(_$AppDatabase db, $PhotoUploadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotoUploadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotoUploadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotoUploadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> opId = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<Uint8List> bytes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotoUploadsCompanion(
                opId: opId,
                productId: productId,
                path: path,
                bytes: bytes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String opId,
                required String productId,
                required String path,
                required Uint8List bytes,
                Value<int> rowid = const Value.absent(),
              }) => PhotoUploadsCompanion.insert(
                opId: opId,
                productId: productId,
                path: path,
                bytes: bytes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PhotoUploadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhotoUploadsTable,
      PhotoUpload,
      $$PhotoUploadsTableFilterComposer,
      $$PhotoUploadsTableOrderingComposer,
      $$PhotoUploadsTableAnnotationComposer,
      $$PhotoUploadsTableCreateCompanionBuilder,
      $$PhotoUploadsTableUpdateCompanionBuilder,
      (
        PhotoUpload,
        BaseReferences<_$AppDatabase, $PhotoUploadsTable, PhotoUpload>,
      ),
      PhotoUpload,
      PrefetchHooks Function()
    >;
typedef $$PhotoCacheTableCreateCompanionBuilder =
    PhotoCacheCompanion Function({
      required String productId,
      required String path,
      required Uint8List bytes,
      Value<int> rowid,
    });
typedef $$PhotoCacheTableUpdateCompanionBuilder =
    PhotoCacheCompanion Function({
      Value<String> productId,
      Value<String> path,
      Value<Uint8List> bytes,
      Value<int> rowid,
    });

class $$PhotoCacheTableFilterComposer
    extends Composer<_$AppDatabase, $PhotoCacheTable> {
  $$PhotoCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PhotoCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $PhotoCacheTable> {
  $$PhotoCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhotoCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhotoCacheTable> {
  $$PhotoCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);
}

class $$PhotoCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhotoCacheTable,
          PhotoCacheData,
          $$PhotoCacheTableFilterComposer,
          $$PhotoCacheTableOrderingComposer,
          $$PhotoCacheTableAnnotationComposer,
          $$PhotoCacheTableCreateCompanionBuilder,
          $$PhotoCacheTableUpdateCompanionBuilder,
          (
            PhotoCacheData,
            BaseReferences<_$AppDatabase, $PhotoCacheTable, PhotoCacheData>,
          ),
          PhotoCacheData,
          PrefetchHooks Function()
        > {
  $$PhotoCacheTableTableManager(_$AppDatabase db, $PhotoCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotoCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotoCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotoCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> productId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<Uint8List> bytes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotoCacheCompanion(
                productId: productId,
                path: path,
                bytes: bytes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String productId,
                required String path,
                required Uint8List bytes,
                Value<int> rowid = const Value.absent(),
              }) => PhotoCacheCompanion.insert(
                productId: productId,
                path: path,
                bytes: bytes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PhotoCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhotoCacheTable,
      PhotoCacheData,
      $$PhotoCacheTableFilterComposer,
      $$PhotoCacheTableOrderingComposer,
      $$PhotoCacheTableAnnotationComposer,
      $$PhotoCacheTableCreateCompanionBuilder,
      $$PhotoCacheTableUpdateCompanionBuilder,
      (
        PhotoCacheData,
        BaseReferences<_$AppDatabase, $PhotoCacheTable, PhotoCacheData>,
      ),
      PhotoCacheData,
      PrefetchHooks Function()
    >;
typedef $$CustomersTableCreateCompanionBuilder =
    CustomersCompanion Function({
      required String id,
      required String name,
      Value<String?> phone,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$CustomersTableUpdateCompanionBuilder =
    CustomersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> phone,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$CustomersTableFilterComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomersTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$CustomersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomersTable,
          Customer,
          $$CustomersTableFilterComposer,
          $$CustomersTableOrderingComposer,
          $$CustomersTableAnnotationComposer,
          $$CustomersTableCreateCompanionBuilder,
          $$CustomersTableUpdateCompanionBuilder,
          (Customer, BaseReferences<_$AppDatabase, $CustomersTable, Customer>),
          Customer,
          PrefetchHooks Function()
        > {
  $$CustomersTableTableManager(_$AppDatabase db, $CustomersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomersCompanion(
                id: id,
                name: name,
                phone: phone,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> phone = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomersCompanion.insert(
                id: id,
                name: name,
                phone: phone,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomersTable,
      Customer,
      $$CustomersTableFilterComposer,
      $$CustomersTableOrderingComposer,
      $$CustomersTableAnnotationComposer,
      $$CustomersTableCreateCompanionBuilder,
      $$CustomersTableUpdateCompanionBuilder,
      (Customer, BaseReferences<_$AppDatabase, $CustomersTable, Customer>),
      Customer,
      PrefetchHooks Function()
    >;
typedef $$ServerLedgerTableCreateCompanionBuilder =
    ServerLedgerCompanion Function({
      required String id,
      required String customerId,
      required String kind,
      required int amount,
      Value<String?> saleId,
      Value<String?> note,
      required String occurredAt,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$ServerLedgerTableUpdateCompanionBuilder =
    ServerLedgerCompanion Function({
      Value<String> id,
      Value<String> customerId,
      Value<String> kind,
      Value<int> amount,
      Value<String?> saleId,
      Value<String?> note,
      Value<String> occurredAt,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$ServerLedgerTableFilterComposer
    extends Composer<_$AppDatabase, $ServerLedgerTable> {
  $$ServerLedgerTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get saleId => $composableBuilder(
    column: $table.saleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ServerLedgerTableOrderingComposer
    extends Composer<_$AppDatabase, $ServerLedgerTable> {
  $$ServerLedgerTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get saleId => $composableBuilder(
    column: $table.saleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ServerLedgerTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServerLedgerTable> {
  $$ServerLedgerTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get saleId =>
      $composableBuilder(column: $table.saleId, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ServerLedgerTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ServerLedgerTable,
          ServerLedgerData,
          $$ServerLedgerTableFilterComposer,
          $$ServerLedgerTableOrderingComposer,
          $$ServerLedgerTableAnnotationComposer,
          $$ServerLedgerTableCreateCompanionBuilder,
          $$ServerLedgerTableUpdateCompanionBuilder,
          (
            ServerLedgerData,
            BaseReferences<_$AppDatabase, $ServerLedgerTable, ServerLedgerData>,
          ),
          ServerLedgerData,
          PrefetchHooks Function()
        > {
  $$ServerLedgerTableTableManager(_$AppDatabase db, $ServerLedgerTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServerLedgerTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServerLedgerTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServerLedgerTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> customerId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String?> saleId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> occurredAt = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServerLedgerCompanion(
                id: id,
                customerId: customerId,
                kind: kind,
                amount: amount,
                saleId: saleId,
                note: note,
                occurredAt: occurredAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String customerId,
                required String kind,
                required int amount,
                Value<String?> saleId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required String occurredAt,
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ServerLedgerCompanion.insert(
                id: id,
                customerId: customerId,
                kind: kind,
                amount: amount,
                saleId: saleId,
                note: note,
                occurredAt: occurredAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ServerLedgerTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ServerLedgerTable,
      ServerLedgerData,
      $$ServerLedgerTableFilterComposer,
      $$ServerLedgerTableOrderingComposer,
      $$ServerLedgerTableAnnotationComposer,
      $$ServerLedgerTableCreateCompanionBuilder,
      $$ServerLedgerTableUpdateCompanionBuilder,
      (
        ServerLedgerData,
        BaseReferences<_$AppDatabase, $ServerLedgerTable, ServerLedgerData>,
      ),
      ServerLedgerData,
      PrefetchHooks Function()
    >;
typedef $$LocalLedgerTableCreateCompanionBuilder =
    LocalLedgerCompanion Function({
      Value<int> id,
      required String opId,
      required String customerId,
      required String kind,
      required int amount,
      Value<String?> saleId,
      Value<String?> note,
      required String occurredAt,
      Value<String?> confirmedAfter,
    });
typedef $$LocalLedgerTableUpdateCompanionBuilder =
    LocalLedgerCompanion Function({
      Value<int> id,
      Value<String> opId,
      Value<String> customerId,
      Value<String> kind,
      Value<int> amount,
      Value<String?> saleId,
      Value<String?> note,
      Value<String> occurredAt,
      Value<String?> confirmedAfter,
    });

class $$LocalLedgerTableFilterComposer
    extends Composer<_$AppDatabase, $LocalLedgerTable> {
  $$LocalLedgerTableFilterComposer({
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

  ColumnFilters<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get saleId => $composableBuilder(
    column: $table.saleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confirmedAfter => $composableBuilder(
    column: $table.confirmedAfter,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalLedgerTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalLedgerTable> {
  $$LocalLedgerTableOrderingComposer({
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

  ColumnOrderings<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get saleId => $composableBuilder(
    column: $table.saleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confirmedAfter => $composableBuilder(
    column: $table.confirmedAfter,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalLedgerTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalLedgerTable> {
  $$LocalLedgerTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get opId =>
      $composableBuilder(column: $table.opId, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get saleId =>
      $composableBuilder(column: $table.saleId, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get confirmedAfter => $composableBuilder(
    column: $table.confirmedAfter,
    builder: (column) => column,
  );
}

class $$LocalLedgerTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalLedgerTable,
          LocalLedgerData,
          $$LocalLedgerTableFilterComposer,
          $$LocalLedgerTableOrderingComposer,
          $$LocalLedgerTableAnnotationComposer,
          $$LocalLedgerTableCreateCompanionBuilder,
          $$LocalLedgerTableUpdateCompanionBuilder,
          (
            LocalLedgerData,
            BaseReferences<_$AppDatabase, $LocalLedgerTable, LocalLedgerData>,
          ),
          LocalLedgerData,
          PrefetchHooks Function()
        > {
  $$LocalLedgerTableTableManager(_$AppDatabase db, $LocalLedgerTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalLedgerTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalLedgerTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalLedgerTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> opId = const Value.absent(),
                Value<String> customerId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String?> saleId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> occurredAt = const Value.absent(),
                Value<String?> confirmedAfter = const Value.absent(),
              }) => LocalLedgerCompanion(
                id: id,
                opId: opId,
                customerId: customerId,
                kind: kind,
                amount: amount,
                saleId: saleId,
                note: note,
                occurredAt: occurredAt,
                confirmedAfter: confirmedAfter,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String opId,
                required String customerId,
                required String kind,
                required int amount,
                Value<String?> saleId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required String occurredAt,
                Value<String?> confirmedAfter = const Value.absent(),
              }) => LocalLedgerCompanion.insert(
                id: id,
                opId: opId,
                customerId: customerId,
                kind: kind,
                amount: amount,
                saleId: saleId,
                note: note,
                occurredAt: occurredAt,
                confirmedAfter: confirmedAfter,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalLedgerTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalLedgerTable,
      LocalLedgerData,
      $$LocalLedgerTableFilterComposer,
      $$LocalLedgerTableOrderingComposer,
      $$LocalLedgerTableAnnotationComposer,
      $$LocalLedgerTableCreateCompanionBuilder,
      $$LocalLedgerTableUpdateCompanionBuilder,
      (
        LocalLedgerData,
        BaseReferences<_$AppDatabase, $LocalLedgerTable, LocalLedgerData>,
      ),
      LocalLedgerData,
      PrefetchHooks Function()
    >;
typedef $$StockLevelsTableCreateCompanionBuilder =
    StockLevelsCompanion Function({
      required String locationId,
      required String variantId,
      required double qty,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$StockLevelsTableUpdateCompanionBuilder =
    StockLevelsCompanion Function({
      Value<String> locationId,
      Value<String> variantId,
      Value<double> qty,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$StockLevelsTableFilterComposer
    extends Composer<_$AppDatabase, $StockLevelsTable> {
  $$StockLevelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variantId => $composableBuilder(
    column: $table.variantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StockLevelsTableOrderingComposer
    extends Composer<_$AppDatabase, $StockLevelsTable> {
  $$StockLevelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variantId => $composableBuilder(
    column: $table.variantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StockLevelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockLevelsTable> {
  $$StockLevelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get variantId =>
      $composableBuilder(column: $table.variantId, builder: (column) => column);

  GeneratedColumn<double> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StockLevelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StockLevelsTable,
          StockLevel,
          $$StockLevelsTableFilterComposer,
          $$StockLevelsTableOrderingComposer,
          $$StockLevelsTableAnnotationComposer,
          $$StockLevelsTableCreateCompanionBuilder,
          $$StockLevelsTableUpdateCompanionBuilder,
          (
            StockLevel,
            BaseReferences<_$AppDatabase, $StockLevelsTable, StockLevel>,
          ),
          StockLevel,
          PrefetchHooks Function()
        > {
  $$StockLevelsTableTableManager(_$AppDatabase db, $StockLevelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockLevelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockLevelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockLevelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> locationId = const Value.absent(),
                Value<String> variantId = const Value.absent(),
                Value<double> qty = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StockLevelsCompanion(
                locationId: locationId,
                variantId: variantId,
                qty: qty,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String locationId,
                required String variantId,
                required double qty,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => StockLevelsCompanion.insert(
                locationId: locationId,
                variantId: variantId,
                qty: qty,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StockLevelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StockLevelsTable,
      StockLevel,
      $$StockLevelsTableFilterComposer,
      $$StockLevelsTableOrderingComposer,
      $$StockLevelsTableAnnotationComposer,
      $$StockLevelsTableCreateCompanionBuilder,
      $$StockLevelsTableUpdateCompanionBuilder,
      (
        StockLevel,
        BaseReferences<_$AppDatabase, $StockLevelsTable, StockLevel>,
      ),
      StockLevel,
      PrefetchHooks Function()
    >;
typedef $$LocalMovementsTableCreateCompanionBuilder =
    LocalMovementsCompanion Function({
      Value<int> id,
      required String opId,
      required String variantId,
      required double qty,
      Value<String?> confirmedAfter,
    });
typedef $$LocalMovementsTableUpdateCompanionBuilder =
    LocalMovementsCompanion Function({
      Value<int> id,
      Value<String> opId,
      Value<String> variantId,
      Value<double> qty,
      Value<String?> confirmedAfter,
    });

class $$LocalMovementsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalMovementsTable> {
  $$LocalMovementsTableFilterComposer({
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

  ColumnFilters<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variantId => $composableBuilder(
    column: $table.variantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confirmedAfter => $composableBuilder(
    column: $table.confirmedAfter,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalMovementsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalMovementsTable> {
  $$LocalMovementsTableOrderingComposer({
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

  ColumnOrderings<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variantId => $composableBuilder(
    column: $table.variantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confirmedAfter => $composableBuilder(
    column: $table.confirmedAfter,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalMovementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalMovementsTable> {
  $$LocalMovementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get opId =>
      $composableBuilder(column: $table.opId, builder: (column) => column);

  GeneratedColumn<String> get variantId =>
      $composableBuilder(column: $table.variantId, builder: (column) => column);

  GeneratedColumn<double> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<String> get confirmedAfter => $composableBuilder(
    column: $table.confirmedAfter,
    builder: (column) => column,
  );
}

class $$LocalMovementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalMovementsTable,
          LocalMovement,
          $$LocalMovementsTableFilterComposer,
          $$LocalMovementsTableOrderingComposer,
          $$LocalMovementsTableAnnotationComposer,
          $$LocalMovementsTableCreateCompanionBuilder,
          $$LocalMovementsTableUpdateCompanionBuilder,
          (
            LocalMovement,
            BaseReferences<_$AppDatabase, $LocalMovementsTable, LocalMovement>,
          ),
          LocalMovement,
          PrefetchHooks Function()
        > {
  $$LocalMovementsTableTableManager(
    _$AppDatabase db,
    $LocalMovementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMovementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalMovementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalMovementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> opId = const Value.absent(),
                Value<String> variantId = const Value.absent(),
                Value<double> qty = const Value.absent(),
                Value<String?> confirmedAfter = const Value.absent(),
              }) => LocalMovementsCompanion(
                id: id,
                opId: opId,
                variantId: variantId,
                qty: qty,
                confirmedAfter: confirmedAfter,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String opId,
                required String variantId,
                required double qty,
                Value<String?> confirmedAfter = const Value.absent(),
              }) => LocalMovementsCompanion.insert(
                id: id,
                opId: opId,
                variantId: variantId,
                qty: qty,
                confirmedAfter: confirmedAfter,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalMovementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalMovementsTable,
      LocalMovement,
      $$LocalMovementsTableFilterComposer,
      $$LocalMovementsTableOrderingComposer,
      $$LocalMovementsTableAnnotationComposer,
      $$LocalMovementsTableCreateCompanionBuilder,
      $$LocalMovementsTableUpdateCompanionBuilder,
      (
        LocalMovement,
        BaseReferences<_$AppDatabase, $LocalMovementsTable, LocalMovement>,
      ),
      LocalMovement,
      PrefetchHooks Function()
    >;
typedef $$SalesTableCreateCompanionBuilder =
    SalesCompanion Function({
      required String id,
      required String localNo,
      Value<String> status,
      required int subtotal,
      Value<int> discount,
      Value<int> tax,
      required int total,
      Value<String?> customerId,
      required String soldAt,
      Value<String?> voidedAt,
      Value<String?> voidReason,
      Value<int> rowid,
    });
typedef $$SalesTableUpdateCompanionBuilder =
    SalesCompanion Function({
      Value<String> id,
      Value<String> localNo,
      Value<String> status,
      Value<int> subtotal,
      Value<int> discount,
      Value<int> tax,
      Value<int> total,
      Value<String?> customerId,
      Value<String> soldAt,
      Value<String?> voidedAt,
      Value<String?> voidReason,
      Value<int> rowid,
    });

class $$SalesTableFilterComposer extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localNo => $composableBuilder(
    column: $table.localNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discount => $composableBuilder(
    column: $table.discount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get soldAt => $composableBuilder(
    column: $table.soldAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voidedAt => $composableBuilder(
    column: $table.voidedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SalesTableOrderingComposer
    extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localNo => $composableBuilder(
    column: $table.localNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discount => $composableBuilder(
    column: $table.discount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get soldAt => $composableBuilder(
    column: $table.soldAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voidedAt => $composableBuilder(
    column: $table.voidedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SalesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get localNo =>
      $composableBuilder(column: $table.localNo, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get subtotal =>
      $composableBuilder(column: $table.subtotal, builder: (column) => column);

  GeneratedColumn<int> get discount =>
      $composableBuilder(column: $table.discount, builder: (column) => column);

  GeneratedColumn<int> get tax =>
      $composableBuilder(column: $table.tax, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get soldAt =>
      $composableBuilder(column: $table.soldAt, builder: (column) => column);

  GeneratedColumn<String> get voidedAt =>
      $composableBuilder(column: $table.voidedAt, builder: (column) => column);

  GeneratedColumn<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => column,
  );
}

class $$SalesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SalesTable,
          Sale,
          $$SalesTableFilterComposer,
          $$SalesTableOrderingComposer,
          $$SalesTableAnnotationComposer,
          $$SalesTableCreateCompanionBuilder,
          $$SalesTableUpdateCompanionBuilder,
          (Sale, BaseReferences<_$AppDatabase, $SalesTable, Sale>),
          Sale,
          PrefetchHooks Function()
        > {
  $$SalesTableTableManager(_$AppDatabase db, $SalesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SalesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SalesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SalesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> localNo = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> subtotal = const Value.absent(),
                Value<int> discount = const Value.absent(),
                Value<int> tax = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                Value<String> soldAt = const Value.absent(),
                Value<String?> voidedAt = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SalesCompanion(
                id: id,
                localNo: localNo,
                status: status,
                subtotal: subtotal,
                discount: discount,
                tax: tax,
                total: total,
                customerId: customerId,
                soldAt: soldAt,
                voidedAt: voidedAt,
                voidReason: voidReason,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String localNo,
                Value<String> status = const Value.absent(),
                required int subtotal,
                Value<int> discount = const Value.absent(),
                Value<int> tax = const Value.absent(),
                required int total,
                Value<String?> customerId = const Value.absent(),
                required String soldAt,
                Value<String?> voidedAt = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SalesCompanion.insert(
                id: id,
                localNo: localNo,
                status: status,
                subtotal: subtotal,
                discount: discount,
                tax: tax,
                total: total,
                customerId: customerId,
                soldAt: soldAt,
                voidedAt: voidedAt,
                voidReason: voidReason,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SalesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SalesTable,
      Sale,
      $$SalesTableFilterComposer,
      $$SalesTableOrderingComposer,
      $$SalesTableAnnotationComposer,
      $$SalesTableCreateCompanionBuilder,
      $$SalesTableUpdateCompanionBuilder,
      (Sale, BaseReferences<_$AppDatabase, $SalesTable, Sale>),
      Sale,
      PrefetchHooks Function()
    >;
typedef $$SaleItemsTableCreateCompanionBuilder =
    SaleItemsCompanion Function({
      Value<int> id,
      required String saleId,
      required String variantId,
      required String name,
      required double qty,
      required int unitPrice,
      Value<int> unitCost,
      Value<int> discount,
      Value<int> tax,
      required int lineTotal,
      Value<bool> tracked,
    });
typedef $$SaleItemsTableUpdateCompanionBuilder =
    SaleItemsCompanion Function({
      Value<int> id,
      Value<String> saleId,
      Value<String> variantId,
      Value<String> name,
      Value<double> qty,
      Value<int> unitPrice,
      Value<int> unitCost,
      Value<int> discount,
      Value<int> tax,
      Value<int> lineTotal,
      Value<bool> tracked,
    });

class $$SaleItemsTableFilterComposer
    extends Composer<_$AppDatabase, $SaleItemsTable> {
  $$SaleItemsTableFilterComposer({
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

  ColumnFilters<String> get saleId => $composableBuilder(
    column: $table.saleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variantId => $composableBuilder(
    column: $table.variantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitCost => $composableBuilder(
    column: $table.unitCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discount => $composableBuilder(
    column: $table.discount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineTotal => $composableBuilder(
    column: $table.lineTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get tracked => $composableBuilder(
    column: $table.tracked,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SaleItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $SaleItemsTable> {
  $$SaleItemsTableOrderingComposer({
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

  ColumnOrderings<String> get saleId => $composableBuilder(
    column: $table.saleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variantId => $composableBuilder(
    column: $table.variantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitCost => $composableBuilder(
    column: $table.unitCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discount => $composableBuilder(
    column: $table.discount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineTotal => $composableBuilder(
    column: $table.lineTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get tracked => $composableBuilder(
    column: $table.tracked,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SaleItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SaleItemsTable> {
  $$SaleItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get saleId =>
      $composableBuilder(column: $table.saleId, builder: (column) => column);

  GeneratedColumn<String> get variantId =>
      $composableBuilder(column: $table.variantId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<int> get unitPrice =>
      $composableBuilder(column: $table.unitPrice, builder: (column) => column);

  GeneratedColumn<int> get unitCost =>
      $composableBuilder(column: $table.unitCost, builder: (column) => column);

  GeneratedColumn<int> get discount =>
      $composableBuilder(column: $table.discount, builder: (column) => column);

  GeneratedColumn<int> get tax =>
      $composableBuilder(column: $table.tax, builder: (column) => column);

  GeneratedColumn<int> get lineTotal =>
      $composableBuilder(column: $table.lineTotal, builder: (column) => column);

  GeneratedColumn<bool> get tracked =>
      $composableBuilder(column: $table.tracked, builder: (column) => column);
}

class $$SaleItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SaleItemsTable,
          SaleItem,
          $$SaleItemsTableFilterComposer,
          $$SaleItemsTableOrderingComposer,
          $$SaleItemsTableAnnotationComposer,
          $$SaleItemsTableCreateCompanionBuilder,
          $$SaleItemsTableUpdateCompanionBuilder,
          (SaleItem, BaseReferences<_$AppDatabase, $SaleItemsTable, SaleItem>),
          SaleItem,
          PrefetchHooks Function()
        > {
  $$SaleItemsTableTableManager(_$AppDatabase db, $SaleItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SaleItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SaleItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SaleItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> saleId = const Value.absent(),
                Value<String> variantId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> qty = const Value.absent(),
                Value<int> unitPrice = const Value.absent(),
                Value<int> unitCost = const Value.absent(),
                Value<int> discount = const Value.absent(),
                Value<int> tax = const Value.absent(),
                Value<int> lineTotal = const Value.absent(),
                Value<bool> tracked = const Value.absent(),
              }) => SaleItemsCompanion(
                id: id,
                saleId: saleId,
                variantId: variantId,
                name: name,
                qty: qty,
                unitPrice: unitPrice,
                unitCost: unitCost,
                discount: discount,
                tax: tax,
                lineTotal: lineTotal,
                tracked: tracked,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String saleId,
                required String variantId,
                required String name,
                required double qty,
                required int unitPrice,
                Value<int> unitCost = const Value.absent(),
                Value<int> discount = const Value.absent(),
                Value<int> tax = const Value.absent(),
                required int lineTotal,
                Value<bool> tracked = const Value.absent(),
              }) => SaleItemsCompanion.insert(
                id: id,
                saleId: saleId,
                variantId: variantId,
                name: name,
                qty: qty,
                unitPrice: unitPrice,
                unitCost: unitCost,
                discount: discount,
                tax: tax,
                lineTotal: lineTotal,
                tracked: tracked,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SaleItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SaleItemsTable,
      SaleItem,
      $$SaleItemsTableFilterComposer,
      $$SaleItemsTableOrderingComposer,
      $$SaleItemsTableAnnotationComposer,
      $$SaleItemsTableCreateCompanionBuilder,
      $$SaleItemsTableUpdateCompanionBuilder,
      (SaleItem, BaseReferences<_$AppDatabase, $SaleItemsTable, SaleItem>),
      SaleItem,
      PrefetchHooks Function()
    >;
typedef $$SalePaymentsTableCreateCompanionBuilder =
    SalePaymentsCompanion Function({
      Value<int> id,
      required String saleId,
      required String method,
      required int amount,
      Value<int?> tendered,
      Value<String?> reference,
    });
typedef $$SalePaymentsTableUpdateCompanionBuilder =
    SalePaymentsCompanion Function({
      Value<int> id,
      Value<String> saleId,
      Value<String> method,
      Value<int> amount,
      Value<int?> tendered,
      Value<String?> reference,
    });

class $$SalePaymentsTableFilterComposer
    extends Composer<_$AppDatabase, $SalePaymentsTable> {
  $$SalePaymentsTableFilterComposer({
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

  ColumnFilters<String> get saleId => $composableBuilder(
    column: $table.saleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tendered => $composableBuilder(
    column: $table.tendered,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SalePaymentsTableOrderingComposer
    extends Composer<_$AppDatabase, $SalePaymentsTable> {
  $$SalePaymentsTableOrderingComposer({
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

  ColumnOrderings<String> get saleId => $composableBuilder(
    column: $table.saleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tendered => $composableBuilder(
    column: $table.tendered,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SalePaymentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SalePaymentsTable> {
  $$SalePaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get saleId =>
      $composableBuilder(column: $table.saleId, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<int> get tendered =>
      $composableBuilder(column: $table.tendered, builder: (column) => column);

  GeneratedColumn<String> get reference =>
      $composableBuilder(column: $table.reference, builder: (column) => column);
}

class $$SalePaymentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SalePaymentsTable,
          SalePayment,
          $$SalePaymentsTableFilterComposer,
          $$SalePaymentsTableOrderingComposer,
          $$SalePaymentsTableAnnotationComposer,
          $$SalePaymentsTableCreateCompanionBuilder,
          $$SalePaymentsTableUpdateCompanionBuilder,
          (
            SalePayment,
            BaseReferences<_$AppDatabase, $SalePaymentsTable, SalePayment>,
          ),
          SalePayment,
          PrefetchHooks Function()
        > {
  $$SalePaymentsTableTableManager(_$AppDatabase db, $SalePaymentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SalePaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SalePaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SalePaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> saleId = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<int?> tendered = const Value.absent(),
                Value<String?> reference = const Value.absent(),
              }) => SalePaymentsCompanion(
                id: id,
                saleId: saleId,
                method: method,
                amount: amount,
                tendered: tendered,
                reference: reference,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String saleId,
                required String method,
                required int amount,
                Value<int?> tendered = const Value.absent(),
                Value<String?> reference = const Value.absent(),
              }) => SalePaymentsCompanion.insert(
                id: id,
                saleId: saleId,
                method: method,
                amount: amount,
                tendered: tendered,
                reference: reference,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SalePaymentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SalePaymentsTable,
      SalePayment,
      $$SalePaymentsTableFilterComposer,
      $$SalePaymentsTableOrderingComposer,
      $$SalePaymentsTableAnnotationComposer,
      $$SalePaymentsTableCreateCompanionBuilder,
      $$SalePaymentsTableUpdateCompanionBuilder,
      (
        SalePayment,
        BaseReferences<_$AppDatabase, $SalePaymentsTable, SalePayment>,
      ),
      SalePayment,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db, _db.products);
  $$VariantsTableTableManager get variants =>
      $$VariantsTableTableManager(_db, _db.variants);
  $$PricesTableTableManager get prices =>
      $$PricesTableTableManager(_db, _db.prices);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$OpeningStockTableTableManager get openingStock =>
      $$OpeningStockTableTableManager(_db, _db.openingStock);
  $$MetaTableTableManager get meta => $$MetaTableTableManager(_db, _db.meta);
  $$PhotoUploadsTableTableManager get photoUploads =>
      $$PhotoUploadsTableTableManager(_db, _db.photoUploads);
  $$PhotoCacheTableTableManager get photoCache =>
      $$PhotoCacheTableTableManager(_db, _db.photoCache);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db, _db.customers);
  $$ServerLedgerTableTableManager get serverLedger =>
      $$ServerLedgerTableTableManager(_db, _db.serverLedger);
  $$LocalLedgerTableTableManager get localLedger =>
      $$LocalLedgerTableTableManager(_db, _db.localLedger);
  $$StockLevelsTableTableManager get stockLevels =>
      $$StockLevelsTableTableManager(_db, _db.stockLevels);
  $$LocalMovementsTableTableManager get localMovements =>
      $$LocalMovementsTableTableManager(_db, _db.localMovements);
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db, _db.sales);
  $$SaleItemsTableTableManager get saleItems =>
      $$SaleItemsTableTableManager(_db, _db.saleItems);
  $$SalePaymentsTableTableManager get salePayments =>
      $$SalePaymentsTableTableManager(_db, _db.salePayments);
}

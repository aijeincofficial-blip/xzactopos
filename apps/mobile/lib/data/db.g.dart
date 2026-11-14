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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Default'),
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
  static const VerificationMeta _breaksIntoVariantIdMeta =
      const VerificationMeta('breaksIntoVariantId');
  @override
  late final GeneratedColumn<String> breaksIntoVariantId =
      GeneratedColumn<String>(
        'breaks_into_variant_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _breaksIntoQtyMeta = const VerificationMeta(
    'breaksIntoQty',
  );
  @override
  late final GeneratedColumn<int> breaksIntoQty = GeneratedColumn<int>(
    'breaks_into_qty',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    productId,
    name,
    sku,
    barcode,
    isDefault,
    cost,
    reorderPoint,
    active,
    updatedAt,
    deletedAt,
    breaksIntoVariantId,
    breaksIntoQty,
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
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
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
    if (data.containsKey('breaks_into_variant_id')) {
      context.handle(
        _breaksIntoVariantIdMeta,
        breaksIntoVariantId.isAcceptableOrUnknown(
          data['breaks_into_variant_id']!,
          _breaksIntoVariantIdMeta,
        ),
      );
    }
    if (data.containsKey('breaks_into_qty')) {
      context.handle(
        _breaksIntoQtyMeta,
        breaksIntoQty.isAcceptableOrUnknown(
          data['breaks_into_qty']!,
          _breaksIntoQtyMeta,
        ),
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
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
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
      breaksIntoVariantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}breaks_into_variant_id'],
      ),
      breaksIntoQty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}breaks_into_qty'],
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
  final String name;
  final String sku;
  final String? barcode;
  final bool isDefault;
  final int cost;
  final double reorderPoint;
  final bool active;
  final String? updatedAt;
  final String? deletedAt;

  /// Tingi (schema v8): one of this pack variant breaks into [breaksIntoQty] of that piece variant. Both or neither.
  final String? breaksIntoVariantId;
  final int? breaksIntoQty;
  const Variant({
    required this.id,
    required this.productId,
    required this.name,
    required this.sku,
    this.barcode,
    required this.isDefault,
    required this.cost,
    required this.reorderPoint,
    required this.active,
    this.updatedAt,
    this.deletedAt,
    this.breaksIntoVariantId,
    this.breaksIntoQty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['product_id'] = Variable<String>(productId);
    map['name'] = Variable<String>(name);
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
    if (!nullToAbsent || breaksIntoVariantId != null) {
      map['breaks_into_variant_id'] = Variable<String>(breaksIntoVariantId);
    }
    if (!nullToAbsent || breaksIntoQty != null) {
      map['breaks_into_qty'] = Variable<int>(breaksIntoQty);
    }
    return map;
  }

  VariantsCompanion toCompanion(bool nullToAbsent) {
    return VariantsCompanion(
      id: Value(id),
      productId: Value(productId),
      name: Value(name),
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
      breaksIntoVariantId: breaksIntoVariantId == null && nullToAbsent
          ? const Value.absent()
          : Value(breaksIntoVariantId),
      breaksIntoQty: breaksIntoQty == null && nullToAbsent
          ? const Value.absent()
          : Value(breaksIntoQty),
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
      name: serializer.fromJson<String>(json['name']),
      sku: serializer.fromJson<String>(json['sku']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      cost: serializer.fromJson<int>(json['cost']),
      reorderPoint: serializer.fromJson<double>(json['reorderPoint']),
      active: serializer.fromJson<bool>(json['active']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      breaksIntoVariantId: serializer.fromJson<String?>(
        json['breaksIntoVariantId'],
      ),
      breaksIntoQty: serializer.fromJson<int?>(json['breaksIntoQty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'productId': serializer.toJson<String>(productId),
      'name': serializer.toJson<String>(name),
      'sku': serializer.toJson<String>(sku),
      'barcode': serializer.toJson<String?>(barcode),
      'isDefault': serializer.toJson<bool>(isDefault),
      'cost': serializer.toJson<int>(cost),
      'reorderPoint': serializer.toJson<double>(reorderPoint),
      'active': serializer.toJson<bool>(active),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'breaksIntoVariantId': serializer.toJson<String?>(breaksIntoVariantId),
      'breaksIntoQty': serializer.toJson<int?>(breaksIntoQty),
    };
  }

  Variant copyWith({
    String? id,
    String? productId,
    String? name,
    String? sku,
    Value<String?> barcode = const Value.absent(),
    bool? isDefault,
    int? cost,
    double? reorderPoint,
    bool? active,
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
    Value<String?> breaksIntoVariantId = const Value.absent(),
    Value<int?> breaksIntoQty = const Value.absent(),
  }) => Variant(
    id: id ?? this.id,
    productId: productId ?? this.productId,
    name: name ?? this.name,
    sku: sku ?? this.sku,
    barcode: barcode.present ? barcode.value : this.barcode,
    isDefault: isDefault ?? this.isDefault,
    cost: cost ?? this.cost,
    reorderPoint: reorderPoint ?? this.reorderPoint,
    active: active ?? this.active,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    breaksIntoVariantId: breaksIntoVariantId.present
        ? breaksIntoVariantId.value
        : this.breaksIntoVariantId,
    breaksIntoQty: breaksIntoQty.present
        ? breaksIntoQty.value
        : this.breaksIntoQty,
  );
  Variant copyWithCompanion(VariantsCompanion data) {
    return Variant(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      name: data.name.present ? data.name.value : this.name,
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
      breaksIntoVariantId: data.breaksIntoVariantId.present
          ? data.breaksIntoVariantId.value
          : this.breaksIntoVariantId,
      breaksIntoQty: data.breaksIntoQty.present
          ? data.breaksIntoQty.value
          : this.breaksIntoQty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Variant(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('name: $name, ')
          ..write('sku: $sku, ')
          ..write('barcode: $barcode, ')
          ..write('isDefault: $isDefault, ')
          ..write('cost: $cost, ')
          ..write('reorderPoint: $reorderPoint, ')
          ..write('active: $active, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('breaksIntoVariantId: $breaksIntoVariantId, ')
          ..write('breaksIntoQty: $breaksIntoQty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    productId,
    name,
    sku,
    barcode,
    isDefault,
    cost,
    reorderPoint,
    active,
    updatedAt,
    deletedAt,
    breaksIntoVariantId,
    breaksIntoQty,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Variant &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.name == this.name &&
          other.sku == this.sku &&
          other.barcode == this.barcode &&
          other.isDefault == this.isDefault &&
          other.cost == this.cost &&
          other.reorderPoint == this.reorderPoint &&
          other.active == this.active &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.breaksIntoVariantId == this.breaksIntoVariantId &&
          other.breaksIntoQty == this.breaksIntoQty);
}

class VariantsCompanion extends UpdateCompanion<Variant> {
  final Value<String> id;
  final Value<String> productId;
  final Value<String> name;
  final Value<String> sku;
  final Value<String?> barcode;
  final Value<bool> isDefault;
  final Value<int> cost;
  final Value<double> reorderPoint;
  final Value<bool> active;
  final Value<String?> updatedAt;
  final Value<String?> deletedAt;
  final Value<String?> breaksIntoVariantId;
  final Value<int?> breaksIntoQty;
  final Value<int> rowid;
  const VariantsCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.name = const Value.absent(),
    this.sku = const Value.absent(),
    this.barcode = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.cost = const Value.absent(),
    this.reorderPoint = const Value.absent(),
    this.active = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.breaksIntoVariantId = const Value.absent(),
    this.breaksIntoQty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VariantsCompanion.insert({
    required String id,
    required String productId,
    this.name = const Value.absent(),
    required String sku,
    this.barcode = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.cost = const Value.absent(),
    this.reorderPoint = const Value.absent(),
    this.active = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.breaksIntoVariantId = const Value.absent(),
    this.breaksIntoQty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       productId = Value(productId),
       sku = Value(sku);
  static Insertable<Variant> custom({
    Expression<String>? id,
    Expression<String>? productId,
    Expression<String>? name,
    Expression<String>? sku,
    Expression<String>? barcode,
    Expression<bool>? isDefault,
    Expression<int>? cost,
    Expression<double>? reorderPoint,
    Expression<bool>? active,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? breaksIntoVariantId,
    Expression<int>? breaksIntoQty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (name != null) 'name': name,
      if (sku != null) 'sku': sku,
      if (barcode != null) 'barcode': barcode,
      if (isDefault != null) 'is_default': isDefault,
      if (cost != null) 'cost': cost,
      if (reorderPoint != null) 'reorder_point': reorderPoint,
      if (active != null) 'active': active,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (breaksIntoVariantId != null)
        'breaks_into_variant_id': breaksIntoVariantId,
      if (breaksIntoQty != null) 'breaks_into_qty': breaksIntoQty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VariantsCompanion copyWith({
    Value<String>? id,
    Value<String>? productId,
    Value<String>? name,
    Value<String>? sku,
    Value<String?>? barcode,
    Value<bool>? isDefault,
    Value<int>? cost,
    Value<double>? reorderPoint,
    Value<bool>? active,
    Value<String?>? updatedAt,
    Value<String?>? deletedAt,
    Value<String?>? breaksIntoVariantId,
    Value<int?>? breaksIntoQty,
    Value<int>? rowid,
  }) {
    return VariantsCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      isDefault: isDefault ?? this.isDefault,
      cost: cost ?? this.cost,
      reorderPoint: reorderPoint ?? this.reorderPoint,
      active: active ?? this.active,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      breaksIntoVariantId: breaksIntoVariantId ?? this.breaksIntoVariantId,
      breaksIntoQty: breaksIntoQty ?? this.breaksIntoQty,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
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
    if (breaksIntoVariantId.present) {
      map['breaks_into_variant_id'] = Variable<String>(
        breaksIntoVariantId.value,
      );
    }
    if (breaksIntoQty.present) {
      map['breaks_into_qty'] = Variable<int>(breaksIntoQty.value);
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
          ..write('name: $name, ')
          ..write('sku: $sku, ')
          ..write('barcode: $barcode, ')
          ..write('isDefault: $isDefault, ')
          ..write('cost: $cost, ')
          ..write('reorderPoint: $reorderPoint, ')
          ..write('active: $active, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('breaksIntoVariantId: $breaksIntoVariantId, ')
          ..write('breaksIntoQty: $breaksIntoQty, ')
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
  static const VerificationMeta _dueOnMeta = const VerificationMeta('dueOn');
  @override
  late final GeneratedColumn<String> dueOn = GeneratedColumn<String>(
    'due_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    phone,
    updatedAt,
    deletedAt,
    dueOn,
  ];
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
    if (data.containsKey('due_on')) {
      context.handle(
        _dueOnMeta,
        dueOn.isAcceptableOrUnknown(data['due_on']!, _dueOnMeta),
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
      dueOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_on'],
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

  /// The date the customer promised to pay, 'YYYY-MM-DD' (schema v9, P8-10); null = none. Text compares as a date.
  final String? dueOn;
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.updatedAt,
    this.deletedAt,
    this.dueOn,
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
    if (!nullToAbsent || dueOn != null) {
      map['due_on'] = Variable<String>(dueOn);
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
      dueOn: dueOn == null && nullToAbsent
          ? const Value.absent()
          : Value(dueOn),
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
      dueOn: serializer.fromJson<String?>(json['dueOn']),
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
      'dueOn': serializer.toJson<String?>(dueOn),
    };
  }

  Customer copyWith({
    String? id,
    String? name,
    Value<String?> phone = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
    Value<String?> dueOn = const Value.absent(),
  }) => Customer(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone.present ? phone.value : this.phone,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    dueOn: dueOn.present ? dueOn.value : this.dueOn,
  );
  Customer copyWithCompanion(CustomersCompanion data) {
    return Customer(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      dueOn: data.dueOn.present ? data.dueOn.value : this.dueOn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Customer(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dueOn: $dueOn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, phone, updatedAt, deletedAt, dueOn);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Customer &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.dueOn == this.dueOn);
}

class CustomersCompanion extends UpdateCompanion<Customer> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> phone;
  final Value<String?> updatedAt;
  final Value<String?> deletedAt;
  final Value<String?> dueOn;
  final Value<int> rowid;
  const CustomersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dueOn = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomersCompanion.insert({
    required String id,
    required String name,
    this.phone = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dueOn = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Customer> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? dueOn,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (dueOn != null) 'due_on': dueOn,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? phone,
    Value<String?>? updatedAt,
    Value<String?>? deletedAt,
    Value<String?>? dueOn,
    Value<int>? rowid,
  }) {
    return CustomersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dueOn: dueOn ?? this.dueOn,
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
    if (dueOn.present) {
      map['due_on'] = Variable<String>(dueOn.value);
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
          ..write('dueOn: $dueOn, ')
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
  static const VerificationMeta _locationIdMeta = const VerificationMeta(
    'locationId',
  );
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
    'location_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('cash'),
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
    locationId,
    method,
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
    if (data.containsKey('location_id')) {
      context.handle(
        _locationIdMeta,
        locationId.isAcceptableOrUnknown(data['location_id']!, _locationIdMeta),
      );
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
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
      locationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_id'],
      ),
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
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

  /// The store where the entry happened (schema v13, F-01); null = not known yet (filled on the next pull).
  final String? locationId;

  /// cash | ewallet: how an utang payment was handed over (schema v13, F-01). Only cash counts in the drawer.
  final String method;
  const ServerLedgerData({
    required this.id,
    required this.customerId,
    required this.kind,
    required this.amount,
    this.saleId,
    this.note,
    required this.occurredAt,
    required this.createdAt,
    this.locationId,
    required this.method,
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
    if (!nullToAbsent || locationId != null) {
      map['location_id'] = Variable<String>(locationId);
    }
    map['method'] = Variable<String>(method);
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
      locationId: locationId == null && nullToAbsent
          ? const Value.absent()
          : Value(locationId),
      method: Value(method),
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
      locationId: serializer.fromJson<String?>(json['locationId']),
      method: serializer.fromJson<String>(json['method']),
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
      'locationId': serializer.toJson<String?>(locationId),
      'method': serializer.toJson<String>(method),
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
    Value<String?> locationId = const Value.absent(),
    String? method,
  }) => ServerLedgerData(
    id: id ?? this.id,
    customerId: customerId ?? this.customerId,
    kind: kind ?? this.kind,
    amount: amount ?? this.amount,
    saleId: saleId.present ? saleId.value : this.saleId,
    note: note.present ? note.value : this.note,
    occurredAt: occurredAt ?? this.occurredAt,
    createdAt: createdAt ?? this.createdAt,
    locationId: locationId.present ? locationId.value : this.locationId,
    method: method ?? this.method,
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
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
      method: data.method.present ? data.method.value : this.method,
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
          ..write('createdAt: $createdAt, ')
          ..write('locationId: $locationId, ')
          ..write('method: $method')
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
    locationId,
    method,
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
          other.createdAt == this.createdAt &&
          other.locationId == this.locationId &&
          other.method == this.method);
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
  final Value<String?> locationId;
  final Value<String> method;
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
    this.locationId = const Value.absent(),
    this.method = const Value.absent(),
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
    this.locationId = const Value.absent(),
    this.method = const Value.absent(),
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
    Expression<String>? locationId,
    Expression<String>? method,
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
      if (locationId != null) 'location_id': locationId,
      if (method != null) 'method': method,
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
    Value<String?>? locationId,
    Value<String>? method,
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
      locationId: locationId ?? this.locationId,
      method: method ?? this.method,
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
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
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
          ..write('locationId: $locationId, ')
          ..write('method: $method, ')
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
  static const VerificationMeta _locationIdMeta = const VerificationMeta(
    'locationId',
  );
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
    'location_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('cash'),
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
    locationId,
    method,
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
    if (data.containsKey('location_id')) {
      context.handle(
        _locationIdMeta,
        locationId.isAcceptableOrUnknown(data['location_id']!, _locationIdMeta),
      );
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
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
      locationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_id'],
      ),
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
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

  /// The store the entry was made for (schema v13, F-01): the active store, or the sale's store.
  final String? locationId;

  /// cash | ewallet (schema v13, F-01); only a payment is ever ewallet.
  final String method;
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
    this.locationId,
    required this.method,
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
    if (!nullToAbsent || locationId != null) {
      map['location_id'] = Variable<String>(locationId);
    }
    map['method'] = Variable<String>(method);
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
      locationId: locationId == null && nullToAbsent
          ? const Value.absent()
          : Value(locationId),
      method: Value(method),
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
      locationId: serializer.fromJson<String?>(json['locationId']),
      method: serializer.fromJson<String>(json['method']),
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
      'locationId': serializer.toJson<String?>(locationId),
      'method': serializer.toJson<String>(method),
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
    Value<String?> locationId = const Value.absent(),
    String? method,
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
    locationId: locationId.present ? locationId.value : this.locationId,
    method: method ?? this.method,
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
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
      method: data.method.present ? data.method.value : this.method,
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
          ..write('confirmedAfter: $confirmedAfter, ')
          ..write('locationId: $locationId, ')
          ..write('method: $method')
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
    locationId,
    method,
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
          other.confirmedAfter == this.confirmedAfter &&
          other.locationId == this.locationId &&
          other.method == this.method);
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
  final Value<String?> locationId;
  final Value<String> method;
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
    this.locationId = const Value.absent(),
    this.method = const Value.absent(),
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
    this.locationId = const Value.absent(),
    this.method = const Value.absent(),
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
    Expression<String>? locationId,
    Expression<String>? method,
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
      if (locationId != null) 'location_id': locationId,
      if (method != null) 'method': method,
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
    Value<String?>? locationId,
    Value<String>? method,
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
      locationId: locationId ?? this.locationId,
      method: method ?? this.method,
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
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
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
          ..write('confirmedAfter: $confirmedAfter, ')
          ..write('locationId: $locationId, ')
          ..write('method: $method')
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
  static const VerificationMeta _avgCostMeta = const VerificationMeta(
    'avgCost',
  );
  @override
  late final GeneratedColumn<int> avgCost = GeneratedColumn<int>(
    'avg_cost',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countedMeta = const VerificationMeta(
    'counted',
  );
  @override
  late final GeneratedColumn<bool> counted = GeneratedColumn<bool>(
    'counted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("counted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  List<GeneratedColumn> get $columns => [
    locationId,
    variantId,
    qty,
    avgCost,
    counted,
    updatedAt,
  ];
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
    if (data.containsKey('avg_cost')) {
      context.handle(
        _avgCostMeta,
        avgCost.isAcceptableOrUnknown(data['avg_cost']!, _avgCostMeta),
      );
    }
    if (data.containsKey('counted')) {
      context.handle(
        _countedMeta,
        counted.isAcceptableOrUnknown(data['counted']!, _countedMeta),
      );
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
      avgCost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}avg_cost'],
      ),
      counted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}counted'],
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
  final int? avgCost;

  /// Someone has told the system how many there are (opening stock, stock in, a count). Sales alone do not count.
  final bool counted;
  final String updatedAt;
  const StockLevel({
    required this.locationId,
    required this.variantId,
    required this.qty,
    this.avgCost,
    required this.counted,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['location_id'] = Variable<String>(locationId);
    map['variant_id'] = Variable<String>(variantId);
    map['qty'] = Variable<double>(qty);
    if (!nullToAbsent || avgCost != null) {
      map['avg_cost'] = Variable<int>(avgCost);
    }
    map['counted'] = Variable<bool>(counted);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  StockLevelsCompanion toCompanion(bool nullToAbsent) {
    return StockLevelsCompanion(
      locationId: Value(locationId),
      variantId: Value(variantId),
      qty: Value(qty),
      avgCost: avgCost == null && nullToAbsent
          ? const Value.absent()
          : Value(avgCost),
      counted: Value(counted),
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
      avgCost: serializer.fromJson<int?>(json['avgCost']),
      counted: serializer.fromJson<bool>(json['counted']),
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
      'avgCost': serializer.toJson<int?>(avgCost),
      'counted': serializer.toJson<bool>(counted),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  StockLevel copyWith({
    String? locationId,
    String? variantId,
    double? qty,
    Value<int?> avgCost = const Value.absent(),
    bool? counted,
    String? updatedAt,
  }) => StockLevel(
    locationId: locationId ?? this.locationId,
    variantId: variantId ?? this.variantId,
    qty: qty ?? this.qty,
    avgCost: avgCost.present ? avgCost.value : this.avgCost,
    counted: counted ?? this.counted,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StockLevel copyWithCompanion(StockLevelsCompanion data) {
    return StockLevel(
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
      variantId: data.variantId.present ? data.variantId.value : this.variantId,
      qty: data.qty.present ? data.qty.value : this.qty,
      avgCost: data.avgCost.present ? data.avgCost.value : this.avgCost,
      counted: data.counted.present ? data.counted.value : this.counted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockLevel(')
          ..write('locationId: $locationId, ')
          ..write('variantId: $variantId, ')
          ..write('qty: $qty, ')
          ..write('avgCost: $avgCost, ')
          ..write('counted: $counted, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(locationId, variantId, qty, avgCost, counted, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockLevel &&
          other.locationId == this.locationId &&
          other.variantId == this.variantId &&
          other.qty == this.qty &&
          other.avgCost == this.avgCost &&
          other.counted == this.counted &&
          other.updatedAt == this.updatedAt);
}

class StockLevelsCompanion extends UpdateCompanion<StockLevel> {
  final Value<String> locationId;
  final Value<String> variantId;
  final Value<double> qty;
  final Value<int?> avgCost;
  final Value<bool> counted;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const StockLevelsCompanion({
    this.locationId = const Value.absent(),
    this.variantId = const Value.absent(),
    this.qty = const Value.absent(),
    this.avgCost = const Value.absent(),
    this.counted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StockLevelsCompanion.insert({
    required String locationId,
    required String variantId,
    required double qty,
    this.avgCost = const Value.absent(),
    this.counted = const Value.absent(),
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
    Expression<int>? avgCost,
    Expression<bool>? counted,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (locationId != null) 'location_id': locationId,
      if (variantId != null) 'variant_id': variantId,
      if (qty != null) 'qty': qty,
      if (avgCost != null) 'avg_cost': avgCost,
      if (counted != null) 'counted': counted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StockLevelsCompanion copyWith({
    Value<String>? locationId,
    Value<String>? variantId,
    Value<double>? qty,
    Value<int?>? avgCost,
    Value<bool>? counted,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return StockLevelsCompanion(
      locationId: locationId ?? this.locationId,
      variantId: variantId ?? this.variantId,
      qty: qty ?? this.qty,
      avgCost: avgCost ?? this.avgCost,
      counted: counted ?? this.counted,
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
    if (avgCost.present) {
      map['avg_cost'] = Variable<int>(avgCost.value);
    }
    if (counted.present) {
      map['counted'] = Variable<bool>(counted.value);
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
          ..write('avgCost: $avgCost, ')
          ..write('counted: $counted, ')
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
  static const VerificationMeta _countsMeta = const VerificationMeta('counts');
  @override
  late final GeneratedColumn<bool> counts = GeneratedColumn<bool>(
    'counts',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("counts" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _unitCostMeta = const VerificationMeta(
    'unitCost',
  );
  @override
  late final GeneratedColumn<int> unitCost = GeneratedColumn<int>(
    'unit_cost',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalCostMeta = const VerificationMeta(
    'totalCost',
  );
  @override
  late final GeneratedColumn<int> totalCost = GeneratedColumn<int>(
    'total_cost',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationIdMeta = const VerificationMeta(
    'locationId',
  );
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
    'location_id',
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
    counts,
    confirmedAfter,
    unitCost,
    totalCost,
    locationId,
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
    if (data.containsKey('counts')) {
      context.handle(
        _countsMeta,
        counts.isAcceptableOrUnknown(data['counts']!, _countsMeta),
      );
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
    if (data.containsKey('unit_cost')) {
      context.handle(
        _unitCostMeta,
        unitCost.isAcceptableOrUnknown(data['unit_cost']!, _unitCostMeta),
      );
    }
    if (data.containsKey('total_cost')) {
      context.handle(
        _totalCostMeta,
        totalCost.isAcceptableOrUnknown(data['total_cost']!, _totalCostMeta),
      );
    }
    if (data.containsKey('location_id')) {
      context.handle(
        _locationIdMeta,
        locationId.isAcceptableOrUnknown(data['location_id']!, _locationIdMeta),
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
      counts: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}counts'],
      )!,
      confirmedAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confirmed_after'],
      ),
      unitCost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_cost'],
      ),
      totalCost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_cost'],
      ),
      locationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_id'],
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

  /// Opening stock, stock in or a count: makes the product "counted". A sale does not.
  final bool counts;
  final String? confirmedAfter;

  /// Stock in with a cost (schema v8): centavos per unit; moves the average cost like the server's receipt.
  final int? unitCost;

  /// Pieces from an opened pack (schema v8): the value they carry in centavos; moves the piece's average cost.
  final int? totalCost;

  /// The store whose stock this moves (schema v13, F-01); matched against `stock_levels.location_id`.
  final String? locationId;
  const LocalMovement({
    required this.id,
    required this.opId,
    required this.variantId,
    required this.qty,
    required this.counts,
    this.confirmedAfter,
    this.unitCost,
    this.totalCost,
    this.locationId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['op_id'] = Variable<String>(opId);
    map['variant_id'] = Variable<String>(variantId);
    map['qty'] = Variable<double>(qty);
    map['counts'] = Variable<bool>(counts);
    if (!nullToAbsent || confirmedAfter != null) {
      map['confirmed_after'] = Variable<String>(confirmedAfter);
    }
    if (!nullToAbsent || unitCost != null) {
      map['unit_cost'] = Variable<int>(unitCost);
    }
    if (!nullToAbsent || totalCost != null) {
      map['total_cost'] = Variable<int>(totalCost);
    }
    if (!nullToAbsent || locationId != null) {
      map['location_id'] = Variable<String>(locationId);
    }
    return map;
  }

  LocalMovementsCompanion toCompanion(bool nullToAbsent) {
    return LocalMovementsCompanion(
      id: Value(id),
      opId: Value(opId),
      variantId: Value(variantId),
      qty: Value(qty),
      counts: Value(counts),
      confirmedAfter: confirmedAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(confirmedAfter),
      unitCost: unitCost == null && nullToAbsent
          ? const Value.absent()
          : Value(unitCost),
      totalCost: totalCost == null && nullToAbsent
          ? const Value.absent()
          : Value(totalCost),
      locationId: locationId == null && nullToAbsent
          ? const Value.absent()
          : Value(locationId),
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
      counts: serializer.fromJson<bool>(json['counts']),
      confirmedAfter: serializer.fromJson<String?>(json['confirmedAfter']),
      unitCost: serializer.fromJson<int?>(json['unitCost']),
      totalCost: serializer.fromJson<int?>(json['totalCost']),
      locationId: serializer.fromJson<String?>(json['locationId']),
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
      'counts': serializer.toJson<bool>(counts),
      'confirmedAfter': serializer.toJson<String?>(confirmedAfter),
      'unitCost': serializer.toJson<int?>(unitCost),
      'totalCost': serializer.toJson<int?>(totalCost),
      'locationId': serializer.toJson<String?>(locationId),
    };
  }

  LocalMovement copyWith({
    int? id,
    String? opId,
    String? variantId,
    double? qty,
    bool? counts,
    Value<String?> confirmedAfter = const Value.absent(),
    Value<int?> unitCost = const Value.absent(),
    Value<int?> totalCost = const Value.absent(),
    Value<String?> locationId = const Value.absent(),
  }) => LocalMovement(
    id: id ?? this.id,
    opId: opId ?? this.opId,
    variantId: variantId ?? this.variantId,
    qty: qty ?? this.qty,
    counts: counts ?? this.counts,
    confirmedAfter: confirmedAfter.present
        ? confirmedAfter.value
        : this.confirmedAfter,
    unitCost: unitCost.present ? unitCost.value : this.unitCost,
    totalCost: totalCost.present ? totalCost.value : this.totalCost,
    locationId: locationId.present ? locationId.value : this.locationId,
  );
  LocalMovement copyWithCompanion(LocalMovementsCompanion data) {
    return LocalMovement(
      id: data.id.present ? data.id.value : this.id,
      opId: data.opId.present ? data.opId.value : this.opId,
      variantId: data.variantId.present ? data.variantId.value : this.variantId,
      qty: data.qty.present ? data.qty.value : this.qty,
      counts: data.counts.present ? data.counts.value : this.counts,
      confirmedAfter: data.confirmedAfter.present
          ? data.confirmedAfter.value
          : this.confirmedAfter,
      unitCost: data.unitCost.present ? data.unitCost.value : this.unitCost,
      totalCost: data.totalCost.present ? data.totalCost.value : this.totalCost,
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMovement(')
          ..write('id: $id, ')
          ..write('opId: $opId, ')
          ..write('variantId: $variantId, ')
          ..write('qty: $qty, ')
          ..write('counts: $counts, ')
          ..write('confirmedAfter: $confirmedAfter, ')
          ..write('unitCost: $unitCost, ')
          ..write('totalCost: $totalCost, ')
          ..write('locationId: $locationId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    opId,
    variantId,
    qty,
    counts,
    confirmedAfter,
    unitCost,
    totalCost,
    locationId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMovement &&
          other.id == this.id &&
          other.opId == this.opId &&
          other.variantId == this.variantId &&
          other.qty == this.qty &&
          other.counts == this.counts &&
          other.confirmedAfter == this.confirmedAfter &&
          other.unitCost == this.unitCost &&
          other.totalCost == this.totalCost &&
          other.locationId == this.locationId);
}

class LocalMovementsCompanion extends UpdateCompanion<LocalMovement> {
  final Value<int> id;
  final Value<String> opId;
  final Value<String> variantId;
  final Value<double> qty;
  final Value<bool> counts;
  final Value<String?> confirmedAfter;
  final Value<int?> unitCost;
  final Value<int?> totalCost;
  final Value<String?> locationId;
  const LocalMovementsCompanion({
    this.id = const Value.absent(),
    this.opId = const Value.absent(),
    this.variantId = const Value.absent(),
    this.qty = const Value.absent(),
    this.counts = const Value.absent(),
    this.confirmedAfter = const Value.absent(),
    this.unitCost = const Value.absent(),
    this.totalCost = const Value.absent(),
    this.locationId = const Value.absent(),
  });
  LocalMovementsCompanion.insert({
    this.id = const Value.absent(),
    required String opId,
    required String variantId,
    required double qty,
    this.counts = const Value.absent(),
    this.confirmedAfter = const Value.absent(),
    this.unitCost = const Value.absent(),
    this.totalCost = const Value.absent(),
    this.locationId = const Value.absent(),
  }) : opId = Value(opId),
       variantId = Value(variantId),
       qty = Value(qty);
  static Insertable<LocalMovement> custom({
    Expression<int>? id,
    Expression<String>? opId,
    Expression<String>? variantId,
    Expression<double>? qty,
    Expression<bool>? counts,
    Expression<String>? confirmedAfter,
    Expression<int>? unitCost,
    Expression<int>? totalCost,
    Expression<String>? locationId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (opId != null) 'op_id': opId,
      if (variantId != null) 'variant_id': variantId,
      if (qty != null) 'qty': qty,
      if (counts != null) 'counts': counts,
      if (confirmedAfter != null) 'confirmed_after': confirmedAfter,
      if (unitCost != null) 'unit_cost': unitCost,
      if (totalCost != null) 'total_cost': totalCost,
      if (locationId != null) 'location_id': locationId,
    });
  }

  LocalMovementsCompanion copyWith({
    Value<int>? id,
    Value<String>? opId,
    Value<String>? variantId,
    Value<double>? qty,
    Value<bool>? counts,
    Value<String?>? confirmedAfter,
    Value<int?>? unitCost,
    Value<int?>? totalCost,
    Value<String?>? locationId,
  }) {
    return LocalMovementsCompanion(
      id: id ?? this.id,
      opId: opId ?? this.opId,
      variantId: variantId ?? this.variantId,
      qty: qty ?? this.qty,
      counts: counts ?? this.counts,
      confirmedAfter: confirmedAfter ?? this.confirmedAfter,
      unitCost: unitCost ?? this.unitCost,
      totalCost: totalCost ?? this.totalCost,
      locationId: locationId ?? this.locationId,
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
    if (counts.present) {
      map['counts'] = Variable<bool>(counts.value);
    }
    if (confirmedAfter.present) {
      map['confirmed_after'] = Variable<String>(confirmedAfter.value);
    }
    if (unitCost.present) {
      map['unit_cost'] = Variable<int>(unitCost.value);
    }
    if (totalCost.present) {
      map['total_cost'] = Variable<int>(totalCost.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
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
          ..write('counts: $counts, ')
          ..write('confirmedAfter: $confirmedAfter, ')
          ..write('unitCost: $unitCost, ')
          ..write('totalCost: $totalCost, ')
          ..write('locationId: $locationId')
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
  static const VerificationMeta _locationIdMeta = const VerificationMeta(
    'locationId',
  );
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
    'location_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _saleNoMeta = const VerificationMeta('saleNo');
  @override
  late final GeneratedColumn<String> saleNo = GeneratedColumn<String>(
    'sale_no',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    locationId,
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
    saleNo,
    deviceId,
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
    if (data.containsKey('location_id')) {
      context.handle(
        _locationIdMeta,
        locationId.isAcceptableOrUnknown(data['location_id']!, _locationIdMeta),
      );
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
    if (data.containsKey('sale_no')) {
      context.handle(
        _saleNoMeta,
        saleNo.isAcceptableOrUnknown(data['sale_no']!, _saleNoMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
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
      locationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_id'],
      ),
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
      saleNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sale_no'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
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

  /// The store of the sale (schema v13, F-01); null = not known yet (an old row on a device with several stores).
  final String? locationId;
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

  /// The server's number `<store code>-<YYMMDD>-<NNNN>` (schema v14, F-02); null until the server has confirmed the sale
  /// (from the op result or the sales pull). Shown instead of [localNo] once known.
  final String? saleNo;

  /// The device that rang the sale up (schema v14, F-02): this phone's id for its own sales, the server's for pulled ones.
  final String? deviceId;
  const Sale({
    required this.id,
    this.locationId,
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
    this.saleNo,
    this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || locationId != null) {
      map['location_id'] = Variable<String>(locationId);
    }
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
    if (!nullToAbsent || saleNo != null) {
      map['sale_no'] = Variable<String>(saleNo);
    }
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    return map;
  }

  SalesCompanion toCompanion(bool nullToAbsent) {
    return SalesCompanion(
      id: Value(id),
      locationId: locationId == null && nullToAbsent
          ? const Value.absent()
          : Value(locationId),
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
      saleNo: saleNo == null && nullToAbsent
          ? const Value.absent()
          : Value(saleNo),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
    );
  }

  factory Sale.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Sale(
      id: serializer.fromJson<String>(json['id']),
      locationId: serializer.fromJson<String?>(json['locationId']),
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
      saleNo: serializer.fromJson<String?>(json['saleNo']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'locationId': serializer.toJson<String?>(locationId),
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
      'saleNo': serializer.toJson<String?>(saleNo),
      'deviceId': serializer.toJson<String?>(deviceId),
    };
  }

  Sale copyWith({
    String? id,
    Value<String?> locationId = const Value.absent(),
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
    Value<String?> saleNo = const Value.absent(),
    Value<String?> deviceId = const Value.absent(),
  }) => Sale(
    id: id ?? this.id,
    locationId: locationId.present ? locationId.value : this.locationId,
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
    saleNo: saleNo.present ? saleNo.value : this.saleNo,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
  );
  Sale copyWithCompanion(SalesCompanion data) {
    return Sale(
      id: data.id.present ? data.id.value : this.id,
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
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
      saleNo: data.saleNo.present ? data.saleNo.value : this.saleNo,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Sale(')
          ..write('id: $id, ')
          ..write('locationId: $locationId, ')
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
          ..write('saleNo: $saleNo, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    locationId,
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
    saleNo,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sale &&
          other.id == this.id &&
          other.locationId == this.locationId &&
          other.localNo == this.localNo &&
          other.status == this.status &&
          other.subtotal == this.subtotal &&
          other.discount == this.discount &&
          other.tax == this.tax &&
          other.total == this.total &&
          other.customerId == this.customerId &&
          other.soldAt == this.soldAt &&
          other.voidedAt == this.voidedAt &&
          other.voidReason == this.voidReason &&
          other.saleNo == this.saleNo &&
          other.deviceId == this.deviceId);
}

class SalesCompanion extends UpdateCompanion<Sale> {
  final Value<String> id;
  final Value<String?> locationId;
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
  final Value<String?> saleNo;
  final Value<String?> deviceId;
  final Value<int> rowid;
  const SalesCompanion({
    this.id = const Value.absent(),
    this.locationId = const Value.absent(),
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
    this.saleNo = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SalesCompanion.insert({
    required String id,
    this.locationId = const Value.absent(),
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
    this.saleNo = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       localNo = Value(localNo),
       subtotal = Value(subtotal),
       total = Value(total),
       soldAt = Value(soldAt);
  static Insertable<Sale> custom({
    Expression<String>? id,
    Expression<String>? locationId,
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
    Expression<String>? saleNo,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (locationId != null) 'location_id': locationId,
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
      if (saleNo != null) 'sale_no': saleNo,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SalesCompanion copyWith({
    Value<String>? id,
    Value<String?>? locationId,
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
    Value<String?>? saleNo,
    Value<String?>? deviceId,
    Value<int>? rowid,
  }) {
    return SalesCompanion(
      id: id ?? this.id,
      locationId: locationId ?? this.locationId,
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
      saleNo: saleNo ?? this.saleNo,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
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
    if (saleNo.present) {
      map['sale_no'] = Variable<String>(saleNo.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
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
          ..write('locationId: $locationId, ')
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
          ..write('saleNo: $saleNo, ')
          ..write('deviceId: $deviceId, ')
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
  static const VerificationMeta _walletMeta = const VerificationMeta('wallet');
  @override
  late final GeneratedColumn<String> wallet = GeneratedColumn<String>(
    'wallet',
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
    wallet,
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
    if (data.containsKey('wallet')) {
      context.handle(
        _walletMeta,
        wallet.isAcceptableOrUnknown(data['wallet']!, _walletMeta),
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
      wallet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wallet'],
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

  /// The store wallet an `ewallet` payment went into: gcash | maya | other (schema v12, P8-15); null = not named.
  final String? wallet;
  const SalePayment({
    required this.id,
    required this.saleId,
    required this.method,
    required this.amount,
    this.tendered,
    this.reference,
    this.wallet,
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
    if (!nullToAbsent || wallet != null) {
      map['wallet'] = Variable<String>(wallet);
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
      wallet: wallet == null && nullToAbsent
          ? const Value.absent()
          : Value(wallet),
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
      wallet: serializer.fromJson<String?>(json['wallet']),
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
      'wallet': serializer.toJson<String?>(wallet),
    };
  }

  SalePayment copyWith({
    int? id,
    String? saleId,
    String? method,
    int? amount,
    Value<int?> tendered = const Value.absent(),
    Value<String?> reference = const Value.absent(),
    Value<String?> wallet = const Value.absent(),
  }) => SalePayment(
    id: id ?? this.id,
    saleId: saleId ?? this.saleId,
    method: method ?? this.method,
    amount: amount ?? this.amount,
    tendered: tendered.present ? tendered.value : this.tendered,
    reference: reference.present ? reference.value : this.reference,
    wallet: wallet.present ? wallet.value : this.wallet,
  );
  SalePayment copyWithCompanion(SalePaymentsCompanion data) {
    return SalePayment(
      id: data.id.present ? data.id.value : this.id,
      saleId: data.saleId.present ? data.saleId.value : this.saleId,
      method: data.method.present ? data.method.value : this.method,
      amount: data.amount.present ? data.amount.value : this.amount,
      tendered: data.tendered.present ? data.tendered.value : this.tendered,
      reference: data.reference.present ? data.reference.value : this.reference,
      wallet: data.wallet.present ? data.wallet.value : this.wallet,
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
          ..write('reference: $reference, ')
          ..write('wallet: $wallet')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, saleId, method, amount, tendered, reference, wallet);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SalePayment &&
          other.id == this.id &&
          other.saleId == this.saleId &&
          other.method == this.method &&
          other.amount == this.amount &&
          other.tendered == this.tendered &&
          other.reference == this.reference &&
          other.wallet == this.wallet);
}

class SalePaymentsCompanion extends UpdateCompanion<SalePayment> {
  final Value<int> id;
  final Value<String> saleId;
  final Value<String> method;
  final Value<int> amount;
  final Value<int?> tendered;
  final Value<String?> reference;
  final Value<String?> wallet;
  const SalePaymentsCompanion({
    this.id = const Value.absent(),
    this.saleId = const Value.absent(),
    this.method = const Value.absent(),
    this.amount = const Value.absent(),
    this.tendered = const Value.absent(),
    this.reference = const Value.absent(),
    this.wallet = const Value.absent(),
  });
  SalePaymentsCompanion.insert({
    this.id = const Value.absent(),
    required String saleId,
    required String method,
    required int amount,
    this.tendered = const Value.absent(),
    this.reference = const Value.absent(),
    this.wallet = const Value.absent(),
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
    Expression<String>? wallet,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (saleId != null) 'sale_id': saleId,
      if (method != null) 'method': method,
      if (amount != null) 'amount': amount,
      if (tendered != null) 'tendered': tendered,
      if (reference != null) 'reference': reference,
      if (wallet != null) 'wallet': wallet,
    });
  }

  SalePaymentsCompanion copyWith({
    Value<int>? id,
    Value<String>? saleId,
    Value<String>? method,
    Value<int>? amount,
    Value<int?>? tendered,
    Value<String?>? reference,
    Value<String?>? wallet,
  }) {
    return SalePaymentsCompanion(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      method: method ?? this.method,
      amount: amount ?? this.amount,
      tendered: tendered ?? this.tendered,
      reference: reference ?? this.reference,
      wallet: wallet ?? this.wallet,
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
    if (wallet.present) {
      map['wallet'] = Variable<String>(wallet.value);
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
          ..write('reference: $reference, ')
          ..write('wallet: $wallet')
          ..write(')'))
        .toString();
  }
}

class $ExpensesTable extends Expenses with TableInfo<$ExpensesTable, Expense> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationIdMeta = const VerificationMeta(
    'locationId',
  );
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
    'location_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paidFromMeta = const VerificationMeta(
    'paidFrom',
  );
  @override
  late final GeneratedColumn<String> paidFrom = GeneratedColumn<String>(
    'paid_from',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('cash'),
  );
  static const VerificationMeta _walletMeta = const VerificationMeta('wallet');
  @override
  late final GeneratedColumn<String> wallet = GeneratedColumn<String>(
    'wallet',
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
  static const VerificationMeta _spentAtMeta = const VerificationMeta(
    'spentAt',
  );
  @override
  late final GeneratedColumn<String> spentAt = GeneratedColumn<String>(
    'spent_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _approvedByMeta = const VerificationMeta(
    'approvedBy',
  );
  @override
  late final GeneratedColumn<String> approvedBy = GeneratedColumn<String>(
    'approved_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _voidApprovedByMeta = const VerificationMeta(
    'voidApprovedBy',
  );
  @override
  late final GeneratedColumn<String> voidApprovedBy = GeneratedColumn<String>(
    'void_approved_by',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    locationId,
    amount,
    currency,
    category,
    paidFrom,
    wallet,
    note,
    spentAt,
    createdBy,
    approvedBy,
    voidedAt,
    voidReason,
    voidApprovedBy,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expenses';
  @override
  VerificationContext validateIntegrity(
    Insertable<Expense> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('location_id')) {
      context.handle(
        _locationIdMeta,
        locationId.isAcceptableOrUnknown(data['location_id']!, _locationIdMeta),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('paid_from')) {
      context.handle(
        _paidFromMeta,
        paidFrom.isAcceptableOrUnknown(data['paid_from']!, _paidFromMeta),
      );
    }
    if (data.containsKey('wallet')) {
      context.handle(
        _walletMeta,
        wallet.isAcceptableOrUnknown(data['wallet']!, _walletMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('spent_at')) {
      context.handle(
        _spentAtMeta,
        spentAt.isAcceptableOrUnknown(data['spent_at']!, _spentAtMeta),
      );
    } else if (isInserting) {
      context.missing(_spentAtMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('approved_by')) {
      context.handle(
        _approvedByMeta,
        approvedBy.isAcceptableOrUnknown(data['approved_by']!, _approvedByMeta),
      );
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
    if (data.containsKey('void_approved_by')) {
      context.handle(
        _voidApprovedByMeta,
        voidApprovedBy.isAcceptableOrUnknown(
          data['void_approved_by']!,
          _voidApprovedByMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Expense map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Expense(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      locationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_id'],
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      paidFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paid_from'],
      )!,
      wallet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wallet'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      spentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}spent_at'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      approvedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}approved_by'],
      ),
      voidedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voided_at'],
      ),
      voidReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}void_reason'],
      ),
      voidApprovedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}void_approved_by'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $ExpensesTable createAlias(String alias) {
    return $ExpensesTable(attachedDatabase, alias);
  }
}

class Expense extends DataClass implements Insertable<Expense> {
  final String id;
  final String? locationId;
  final int amount;
  final String currency;
  final String category;
  final String paidFrom;

  /// The store wallet an `ewallet` expense was paid from: gcash | maya | other (schema v12, P8-15); null = not named.
  final String? wallet;
  final String? note;

  /// UTC ISO-8601, normalised (the same format as `sales.sold_at`), so text comparison orders correctly.
  final String spentAt;
  final String? createdBy;
  final String? approvedBy;
  final String? voidedAt;
  final String? voidReason;
  final String? voidApprovedBy;
  final String? updatedAt;
  const Expense({
    required this.id,
    this.locationId,
    required this.amount,
    required this.currency,
    required this.category,
    required this.paidFrom,
    this.wallet,
    this.note,
    required this.spentAt,
    this.createdBy,
    this.approvedBy,
    this.voidedAt,
    this.voidReason,
    this.voidApprovedBy,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || locationId != null) {
      map['location_id'] = Variable<String>(locationId);
    }
    map['amount'] = Variable<int>(amount);
    map['currency'] = Variable<String>(currency);
    map['category'] = Variable<String>(category);
    map['paid_from'] = Variable<String>(paidFrom);
    if (!nullToAbsent || wallet != null) {
      map['wallet'] = Variable<String>(wallet);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['spent_at'] = Variable<String>(spentAt);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || approvedBy != null) {
      map['approved_by'] = Variable<String>(approvedBy);
    }
    if (!nullToAbsent || voidedAt != null) {
      map['voided_at'] = Variable<String>(voidedAt);
    }
    if (!nullToAbsent || voidReason != null) {
      map['void_reason'] = Variable<String>(voidReason);
    }
    if (!nullToAbsent || voidApprovedBy != null) {
      map['void_approved_by'] = Variable<String>(voidApprovedBy);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    return map;
  }

  ExpensesCompanion toCompanion(bool nullToAbsent) {
    return ExpensesCompanion(
      id: Value(id),
      locationId: locationId == null && nullToAbsent
          ? const Value.absent()
          : Value(locationId),
      amount: Value(amount),
      currency: Value(currency),
      category: Value(category),
      paidFrom: Value(paidFrom),
      wallet: wallet == null && nullToAbsent
          ? const Value.absent()
          : Value(wallet),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      spentAt: Value(spentAt),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      approvedBy: approvedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(approvedBy),
      voidedAt: voidedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(voidedAt),
      voidReason: voidReason == null && nullToAbsent
          ? const Value.absent()
          : Value(voidReason),
      voidApprovedBy: voidApprovedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(voidApprovedBy),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory Expense.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Expense(
      id: serializer.fromJson<String>(json['id']),
      locationId: serializer.fromJson<String?>(json['locationId']),
      amount: serializer.fromJson<int>(json['amount']),
      currency: serializer.fromJson<String>(json['currency']),
      category: serializer.fromJson<String>(json['category']),
      paidFrom: serializer.fromJson<String>(json['paidFrom']),
      wallet: serializer.fromJson<String?>(json['wallet']),
      note: serializer.fromJson<String?>(json['note']),
      spentAt: serializer.fromJson<String>(json['spentAt']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      approvedBy: serializer.fromJson<String?>(json['approvedBy']),
      voidedAt: serializer.fromJson<String?>(json['voidedAt']),
      voidReason: serializer.fromJson<String?>(json['voidReason']),
      voidApprovedBy: serializer.fromJson<String?>(json['voidApprovedBy']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'locationId': serializer.toJson<String?>(locationId),
      'amount': serializer.toJson<int>(amount),
      'currency': serializer.toJson<String>(currency),
      'category': serializer.toJson<String>(category),
      'paidFrom': serializer.toJson<String>(paidFrom),
      'wallet': serializer.toJson<String?>(wallet),
      'note': serializer.toJson<String?>(note),
      'spentAt': serializer.toJson<String>(spentAt),
      'createdBy': serializer.toJson<String?>(createdBy),
      'approvedBy': serializer.toJson<String?>(approvedBy),
      'voidedAt': serializer.toJson<String?>(voidedAt),
      'voidReason': serializer.toJson<String?>(voidReason),
      'voidApprovedBy': serializer.toJson<String?>(voidApprovedBy),
      'updatedAt': serializer.toJson<String?>(updatedAt),
    };
  }

  Expense copyWith({
    String? id,
    Value<String?> locationId = const Value.absent(),
    int? amount,
    String? currency,
    String? category,
    String? paidFrom,
    Value<String?> wallet = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? spentAt,
    Value<String?> createdBy = const Value.absent(),
    Value<String?> approvedBy = const Value.absent(),
    Value<String?> voidedAt = const Value.absent(),
    Value<String?> voidReason = const Value.absent(),
    Value<String?> voidApprovedBy = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
  }) => Expense(
    id: id ?? this.id,
    locationId: locationId.present ? locationId.value : this.locationId,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    category: category ?? this.category,
    paidFrom: paidFrom ?? this.paidFrom,
    wallet: wallet.present ? wallet.value : this.wallet,
    note: note.present ? note.value : this.note,
    spentAt: spentAt ?? this.spentAt,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    approvedBy: approvedBy.present ? approvedBy.value : this.approvedBy,
    voidedAt: voidedAt.present ? voidedAt.value : this.voidedAt,
    voidReason: voidReason.present ? voidReason.value : this.voidReason,
    voidApprovedBy: voidApprovedBy.present
        ? voidApprovedBy.value
        : this.voidApprovedBy,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  Expense copyWithCompanion(ExpensesCompanion data) {
    return Expense(
      id: data.id.present ? data.id.value : this.id,
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      category: data.category.present ? data.category.value : this.category,
      paidFrom: data.paidFrom.present ? data.paidFrom.value : this.paidFrom,
      wallet: data.wallet.present ? data.wallet.value : this.wallet,
      note: data.note.present ? data.note.value : this.note,
      spentAt: data.spentAt.present ? data.spentAt.value : this.spentAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      approvedBy: data.approvedBy.present
          ? data.approvedBy.value
          : this.approvedBy,
      voidedAt: data.voidedAt.present ? data.voidedAt.value : this.voidedAt,
      voidReason: data.voidReason.present
          ? data.voidReason.value
          : this.voidReason,
      voidApprovedBy: data.voidApprovedBy.present
          ? data.voidApprovedBy.value
          : this.voidApprovedBy,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Expense(')
          ..write('id: $id, ')
          ..write('locationId: $locationId, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('category: $category, ')
          ..write('paidFrom: $paidFrom, ')
          ..write('wallet: $wallet, ')
          ..write('note: $note, ')
          ..write('spentAt: $spentAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('approvedBy: $approvedBy, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('voidReason: $voidReason, ')
          ..write('voidApprovedBy: $voidApprovedBy, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    locationId,
    amount,
    currency,
    category,
    paidFrom,
    wallet,
    note,
    spentAt,
    createdBy,
    approvedBy,
    voidedAt,
    voidReason,
    voidApprovedBy,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Expense &&
          other.id == this.id &&
          other.locationId == this.locationId &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.category == this.category &&
          other.paidFrom == this.paidFrom &&
          other.wallet == this.wallet &&
          other.note == this.note &&
          other.spentAt == this.spentAt &&
          other.createdBy == this.createdBy &&
          other.approvedBy == this.approvedBy &&
          other.voidedAt == this.voidedAt &&
          other.voidReason == this.voidReason &&
          other.voidApprovedBy == this.voidApprovedBy &&
          other.updatedAt == this.updatedAt);
}

class ExpensesCompanion extends UpdateCompanion<Expense> {
  final Value<String> id;
  final Value<String?> locationId;
  final Value<int> amount;
  final Value<String> currency;
  final Value<String> category;
  final Value<String> paidFrom;
  final Value<String?> wallet;
  final Value<String?> note;
  final Value<String> spentAt;
  final Value<String?> createdBy;
  final Value<String?> approvedBy;
  final Value<String?> voidedAt;
  final Value<String?> voidReason;
  final Value<String?> voidApprovedBy;
  final Value<String?> updatedAt;
  final Value<int> rowid;
  const ExpensesCompanion({
    this.id = const Value.absent(),
    this.locationId = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.category = const Value.absent(),
    this.paidFrom = const Value.absent(),
    this.wallet = const Value.absent(),
    this.note = const Value.absent(),
    this.spentAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.approvedBy = const Value.absent(),
    this.voidedAt = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.voidApprovedBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExpensesCompanion.insert({
    required String id,
    this.locationId = const Value.absent(),
    required int amount,
    required String currency,
    required String category,
    this.paidFrom = const Value.absent(),
    this.wallet = const Value.absent(),
    this.note = const Value.absent(),
    required String spentAt,
    this.createdBy = const Value.absent(),
    this.approvedBy = const Value.absent(),
    this.voidedAt = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.voidApprovedBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       amount = Value(amount),
       currency = Value(currency),
       category = Value(category),
       spentAt = Value(spentAt);
  static Insertable<Expense> custom({
    Expression<String>? id,
    Expression<String>? locationId,
    Expression<int>? amount,
    Expression<String>? currency,
    Expression<String>? category,
    Expression<String>? paidFrom,
    Expression<String>? wallet,
    Expression<String>? note,
    Expression<String>? spentAt,
    Expression<String>? createdBy,
    Expression<String>? approvedBy,
    Expression<String>? voidedAt,
    Expression<String>? voidReason,
    Expression<String>? voidApprovedBy,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (locationId != null) 'location_id': locationId,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (category != null) 'category': category,
      if (paidFrom != null) 'paid_from': paidFrom,
      if (wallet != null) 'wallet': wallet,
      if (note != null) 'note': note,
      if (spentAt != null) 'spent_at': spentAt,
      if (createdBy != null) 'created_by': createdBy,
      if (approvedBy != null) 'approved_by': approvedBy,
      if (voidedAt != null) 'voided_at': voidedAt,
      if (voidReason != null) 'void_reason': voidReason,
      if (voidApprovedBy != null) 'void_approved_by': voidApprovedBy,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExpensesCompanion copyWith({
    Value<String>? id,
    Value<String?>? locationId,
    Value<int>? amount,
    Value<String>? currency,
    Value<String>? category,
    Value<String>? paidFrom,
    Value<String?>? wallet,
    Value<String?>? note,
    Value<String>? spentAt,
    Value<String?>? createdBy,
    Value<String?>? approvedBy,
    Value<String?>? voidedAt,
    Value<String?>? voidReason,
    Value<String?>? voidApprovedBy,
    Value<String?>? updatedAt,
    Value<int>? rowid,
  }) {
    return ExpensesCompanion(
      id: id ?? this.id,
      locationId: locationId ?? this.locationId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      paidFrom: paidFrom ?? this.paidFrom,
      wallet: wallet ?? this.wallet,
      note: note ?? this.note,
      spentAt: spentAt ?? this.spentAt,
      createdBy: createdBy ?? this.createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      voidedAt: voidedAt ?? this.voidedAt,
      voidReason: voidReason ?? this.voidReason,
      voidApprovedBy: voidApprovedBy ?? this.voidApprovedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (paidFrom.present) {
      map['paid_from'] = Variable<String>(paidFrom.value);
    }
    if (wallet.present) {
      map['wallet'] = Variable<String>(wallet.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (spentAt.present) {
      map['spent_at'] = Variable<String>(spentAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (approvedBy.present) {
      map['approved_by'] = Variable<String>(approvedBy.value);
    }
    if (voidedAt.present) {
      map['voided_at'] = Variable<String>(voidedAt.value);
    }
    if (voidReason.present) {
      map['void_reason'] = Variable<String>(voidReason.value);
    }
    if (voidApprovedBy.present) {
      map['void_approved_by'] = Variable<String>(voidApprovedBy.value);
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
    return (StringBuffer('ExpensesCompanion(')
          ..write('id: $id, ')
          ..write('locationId: $locationId, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('category: $category, ')
          ..write('paidFrom: $paidFrom, ')
          ..write('wallet: $wallet, ')
          ..write('note: $note, ')
          ..write('spentAt: $spentAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('approvedBy: $approvedBy, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('voidReason: $voidReason, ')
          ..write('voidApprovedBy: $voidApprovedBy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DayClosesTable extends DayCloses
    with TableInfo<$DayClosesTable, DayClose> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DayClosesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationIdMeta = const VerificationMeta(
    'locationId',
  );
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
    'location_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
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
  static const VerificationMeta _expectedCashMeta = const VerificationMeta(
    'expectedCash',
  );
  @override
  late final GeneratedColumn<int> expectedCash = GeneratedColumn<int>(
    'expected_cash',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countedCashMeta = const VerificationMeta(
    'countedCash',
  );
  @override
  late final GeneratedColumn<int> countedCash = GeneratedColumn<int>(
    'counted_cash',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _differenceMeta = const VerificationMeta(
    'difference',
  );
  @override
  late final GeneratedColumn<int> difference = GeneratedColumn<int>(
    'difference',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverExpectedCashMeta =
      const VerificationMeta('serverExpectedCash');
  @override
  late final GeneratedColumn<int> serverExpectedCash = GeneratedColumn<int>(
    'server_expected_cash',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  static const VerificationMeta _closedByMeta = const VerificationMeta(
    'closedBy',
  );
  @override
  late final GeneratedColumn<String> closedBy = GeneratedColumn<String>(
    'closed_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _approvedByMeta = const VerificationMeta(
    'approvedBy',
  );
  @override
  late final GeneratedColumn<String> approvedBy = GeneratedColumn<String>(
    'approved_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _closedAtMeta = const VerificationMeta(
    'closedAt',
  );
  @override
  late final GeneratedColumn<String> closedAt = GeneratedColumn<String>(
    'closed_at',
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
  static const VerificationMeta _openingCashMeta = const VerificationMeta(
    'openingCash',
  );
  @override
  late final GeneratedColumn<int> openingCash = GeneratedColumn<int>(
    'opening_cash',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    locationId,
    day,
    currency,
    expectedCash,
    countedCash,
    difference,
    serverExpectedCash,
    note,
    closedBy,
    approvedBy,
    closedAt,
    updatedAt,
    openingCash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_closes';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayClose> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('location_id')) {
      context.handle(
        _locationIdMeta,
        locationId.isAcceptableOrUnknown(data['location_id']!, _locationIdMeta),
      );
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('expected_cash')) {
      context.handle(
        _expectedCashMeta,
        expectedCash.isAcceptableOrUnknown(
          data['expected_cash']!,
          _expectedCashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_expectedCashMeta);
    }
    if (data.containsKey('counted_cash')) {
      context.handle(
        _countedCashMeta,
        countedCash.isAcceptableOrUnknown(
          data['counted_cash']!,
          _countedCashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_countedCashMeta);
    }
    if (data.containsKey('difference')) {
      context.handle(
        _differenceMeta,
        difference.isAcceptableOrUnknown(data['difference']!, _differenceMeta),
      );
    } else if (isInserting) {
      context.missing(_differenceMeta);
    }
    if (data.containsKey('server_expected_cash')) {
      context.handle(
        _serverExpectedCashMeta,
        serverExpectedCash.isAcceptableOrUnknown(
          data['server_expected_cash']!,
          _serverExpectedCashMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('closed_by')) {
      context.handle(
        _closedByMeta,
        closedBy.isAcceptableOrUnknown(data['closed_by']!, _closedByMeta),
      );
    }
    if (data.containsKey('approved_by')) {
      context.handle(
        _approvedByMeta,
        approvedBy.isAcceptableOrUnknown(data['approved_by']!, _approvedByMeta),
      );
    }
    if (data.containsKey('closed_at')) {
      context.handle(
        _closedAtMeta,
        closedAt.isAcceptableOrUnknown(data['closed_at']!, _closedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_closedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('opening_cash')) {
      context.handle(
        _openingCashMeta,
        openingCash.isAcceptableOrUnknown(
          data['opening_cash']!,
          _openingCashMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DayClose map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayClose(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      locationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_id'],
      ),
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      expectedCash: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_cash'],
      )!,
      countedCash: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}counted_cash'],
      )!,
      difference: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}difference'],
      )!,
      serverExpectedCash: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_expected_cash'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      closedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}closed_by'],
      ),
      approvedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}approved_by'],
      ),
      closedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}closed_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      openingCash: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opening_cash'],
      )!,
    );
  }

  @override
  $DayClosesTable createAlias(String alias) {
    return $DayClosesTable(attachedDatabase, alias);
  }
}

class DayClose extends DataClass implements Insertable<DayClose> {
  final String id;
  final String? locationId;

  /// The business day, YYYY-MM-DD (device local date = tenant timezone for the solo store).
  final String day;
  final String currency;
  final int expectedCash;
  final int countedCash;
  final int difference;

  /// What the server computed from its own data when it applied the close; null until pulled.
  final int? serverExpectedCash;
  final String? note;
  final String? closedBy;
  final String? approvedBy;
  final String closedAt;
  final String? updatedAt;

  /// Cash the drawer started the day with (sukli), centavos >= 0 (schema v11, P8-14). Part of [expectedCash].
  final int openingCash;
  const DayClose({
    required this.id,
    this.locationId,
    required this.day,
    required this.currency,
    required this.expectedCash,
    required this.countedCash,
    required this.difference,
    this.serverExpectedCash,
    this.note,
    this.closedBy,
    this.approvedBy,
    required this.closedAt,
    this.updatedAt,
    required this.openingCash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || locationId != null) {
      map['location_id'] = Variable<String>(locationId);
    }
    map['day'] = Variable<String>(day);
    map['currency'] = Variable<String>(currency);
    map['expected_cash'] = Variable<int>(expectedCash);
    map['counted_cash'] = Variable<int>(countedCash);
    map['difference'] = Variable<int>(difference);
    if (!nullToAbsent || serverExpectedCash != null) {
      map['server_expected_cash'] = Variable<int>(serverExpectedCash);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || closedBy != null) {
      map['closed_by'] = Variable<String>(closedBy);
    }
    if (!nullToAbsent || approvedBy != null) {
      map['approved_by'] = Variable<String>(approvedBy);
    }
    map['closed_at'] = Variable<String>(closedAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    map['opening_cash'] = Variable<int>(openingCash);
    return map;
  }

  DayClosesCompanion toCompanion(bool nullToAbsent) {
    return DayClosesCompanion(
      id: Value(id),
      locationId: locationId == null && nullToAbsent
          ? const Value.absent()
          : Value(locationId),
      day: Value(day),
      currency: Value(currency),
      expectedCash: Value(expectedCash),
      countedCash: Value(countedCash),
      difference: Value(difference),
      serverExpectedCash: serverExpectedCash == null && nullToAbsent
          ? const Value.absent()
          : Value(serverExpectedCash),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      closedBy: closedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(closedBy),
      approvedBy: approvedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(approvedBy),
      closedAt: Value(closedAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      openingCash: Value(openingCash),
    );
  }

  factory DayClose.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayClose(
      id: serializer.fromJson<String>(json['id']),
      locationId: serializer.fromJson<String?>(json['locationId']),
      day: serializer.fromJson<String>(json['day']),
      currency: serializer.fromJson<String>(json['currency']),
      expectedCash: serializer.fromJson<int>(json['expectedCash']),
      countedCash: serializer.fromJson<int>(json['countedCash']),
      difference: serializer.fromJson<int>(json['difference']),
      serverExpectedCash: serializer.fromJson<int?>(json['serverExpectedCash']),
      note: serializer.fromJson<String?>(json['note']),
      closedBy: serializer.fromJson<String?>(json['closedBy']),
      approvedBy: serializer.fromJson<String?>(json['approvedBy']),
      closedAt: serializer.fromJson<String>(json['closedAt']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      openingCash: serializer.fromJson<int>(json['openingCash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'locationId': serializer.toJson<String?>(locationId),
      'day': serializer.toJson<String>(day),
      'currency': serializer.toJson<String>(currency),
      'expectedCash': serializer.toJson<int>(expectedCash),
      'countedCash': serializer.toJson<int>(countedCash),
      'difference': serializer.toJson<int>(difference),
      'serverExpectedCash': serializer.toJson<int?>(serverExpectedCash),
      'note': serializer.toJson<String?>(note),
      'closedBy': serializer.toJson<String?>(closedBy),
      'approvedBy': serializer.toJson<String?>(approvedBy),
      'closedAt': serializer.toJson<String>(closedAt),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'openingCash': serializer.toJson<int>(openingCash),
    };
  }

  DayClose copyWith({
    String? id,
    Value<String?> locationId = const Value.absent(),
    String? day,
    String? currency,
    int? expectedCash,
    int? countedCash,
    int? difference,
    Value<int?> serverExpectedCash = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> closedBy = const Value.absent(),
    Value<String?> approvedBy = const Value.absent(),
    String? closedAt,
    Value<String?> updatedAt = const Value.absent(),
    int? openingCash,
  }) => DayClose(
    id: id ?? this.id,
    locationId: locationId.present ? locationId.value : this.locationId,
    day: day ?? this.day,
    currency: currency ?? this.currency,
    expectedCash: expectedCash ?? this.expectedCash,
    countedCash: countedCash ?? this.countedCash,
    difference: difference ?? this.difference,
    serverExpectedCash: serverExpectedCash.present
        ? serverExpectedCash.value
        : this.serverExpectedCash,
    note: note.present ? note.value : this.note,
    closedBy: closedBy.present ? closedBy.value : this.closedBy,
    approvedBy: approvedBy.present ? approvedBy.value : this.approvedBy,
    closedAt: closedAt ?? this.closedAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    openingCash: openingCash ?? this.openingCash,
  );
  DayClose copyWithCompanion(DayClosesCompanion data) {
    return DayClose(
      id: data.id.present ? data.id.value : this.id,
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
      day: data.day.present ? data.day.value : this.day,
      currency: data.currency.present ? data.currency.value : this.currency,
      expectedCash: data.expectedCash.present
          ? data.expectedCash.value
          : this.expectedCash,
      countedCash: data.countedCash.present
          ? data.countedCash.value
          : this.countedCash,
      difference: data.difference.present
          ? data.difference.value
          : this.difference,
      serverExpectedCash: data.serverExpectedCash.present
          ? data.serverExpectedCash.value
          : this.serverExpectedCash,
      note: data.note.present ? data.note.value : this.note,
      closedBy: data.closedBy.present ? data.closedBy.value : this.closedBy,
      approvedBy: data.approvedBy.present
          ? data.approvedBy.value
          : this.approvedBy,
      closedAt: data.closedAt.present ? data.closedAt.value : this.closedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      openingCash: data.openingCash.present
          ? data.openingCash.value
          : this.openingCash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayClose(')
          ..write('id: $id, ')
          ..write('locationId: $locationId, ')
          ..write('day: $day, ')
          ..write('currency: $currency, ')
          ..write('expectedCash: $expectedCash, ')
          ..write('countedCash: $countedCash, ')
          ..write('difference: $difference, ')
          ..write('serverExpectedCash: $serverExpectedCash, ')
          ..write('note: $note, ')
          ..write('closedBy: $closedBy, ')
          ..write('approvedBy: $approvedBy, ')
          ..write('closedAt: $closedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('openingCash: $openingCash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    locationId,
    day,
    currency,
    expectedCash,
    countedCash,
    difference,
    serverExpectedCash,
    note,
    closedBy,
    approvedBy,
    closedAt,
    updatedAt,
    openingCash,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayClose &&
          other.id == this.id &&
          other.locationId == this.locationId &&
          other.day == this.day &&
          other.currency == this.currency &&
          other.expectedCash == this.expectedCash &&
          other.countedCash == this.countedCash &&
          other.difference == this.difference &&
          other.serverExpectedCash == this.serverExpectedCash &&
          other.note == this.note &&
          other.closedBy == this.closedBy &&
          other.approvedBy == this.approvedBy &&
          other.closedAt == this.closedAt &&
          other.updatedAt == this.updatedAt &&
          other.openingCash == this.openingCash);
}

class DayClosesCompanion extends UpdateCompanion<DayClose> {
  final Value<String> id;
  final Value<String?> locationId;
  final Value<String> day;
  final Value<String> currency;
  final Value<int> expectedCash;
  final Value<int> countedCash;
  final Value<int> difference;
  final Value<int?> serverExpectedCash;
  final Value<String?> note;
  final Value<String?> closedBy;
  final Value<String?> approvedBy;
  final Value<String> closedAt;
  final Value<String?> updatedAt;
  final Value<int> openingCash;
  final Value<int> rowid;
  const DayClosesCompanion({
    this.id = const Value.absent(),
    this.locationId = const Value.absent(),
    this.day = const Value.absent(),
    this.currency = const Value.absent(),
    this.expectedCash = const Value.absent(),
    this.countedCash = const Value.absent(),
    this.difference = const Value.absent(),
    this.serverExpectedCash = const Value.absent(),
    this.note = const Value.absent(),
    this.closedBy = const Value.absent(),
    this.approvedBy = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.openingCash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DayClosesCompanion.insert({
    required String id,
    this.locationId = const Value.absent(),
    required String day,
    required String currency,
    required int expectedCash,
    required int countedCash,
    required int difference,
    this.serverExpectedCash = const Value.absent(),
    this.note = const Value.absent(),
    this.closedBy = const Value.absent(),
    this.approvedBy = const Value.absent(),
    required String closedAt,
    this.updatedAt = const Value.absent(),
    this.openingCash = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       day = Value(day),
       currency = Value(currency),
       expectedCash = Value(expectedCash),
       countedCash = Value(countedCash),
       difference = Value(difference),
       closedAt = Value(closedAt);
  static Insertable<DayClose> custom({
    Expression<String>? id,
    Expression<String>? locationId,
    Expression<String>? day,
    Expression<String>? currency,
    Expression<int>? expectedCash,
    Expression<int>? countedCash,
    Expression<int>? difference,
    Expression<int>? serverExpectedCash,
    Expression<String>? note,
    Expression<String>? closedBy,
    Expression<String>? approvedBy,
    Expression<String>? closedAt,
    Expression<String>? updatedAt,
    Expression<int>? openingCash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (locationId != null) 'location_id': locationId,
      if (day != null) 'day': day,
      if (currency != null) 'currency': currency,
      if (expectedCash != null) 'expected_cash': expectedCash,
      if (countedCash != null) 'counted_cash': countedCash,
      if (difference != null) 'difference': difference,
      if (serverExpectedCash != null)
        'server_expected_cash': serverExpectedCash,
      if (note != null) 'note': note,
      if (closedBy != null) 'closed_by': closedBy,
      if (approvedBy != null) 'approved_by': approvedBy,
      if (closedAt != null) 'closed_at': closedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (openingCash != null) 'opening_cash': openingCash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DayClosesCompanion copyWith({
    Value<String>? id,
    Value<String?>? locationId,
    Value<String>? day,
    Value<String>? currency,
    Value<int>? expectedCash,
    Value<int>? countedCash,
    Value<int>? difference,
    Value<int?>? serverExpectedCash,
    Value<String?>? note,
    Value<String?>? closedBy,
    Value<String?>? approvedBy,
    Value<String>? closedAt,
    Value<String?>? updatedAt,
    Value<int>? openingCash,
    Value<int>? rowid,
  }) {
    return DayClosesCompanion(
      id: id ?? this.id,
      locationId: locationId ?? this.locationId,
      day: day ?? this.day,
      currency: currency ?? this.currency,
      expectedCash: expectedCash ?? this.expectedCash,
      countedCash: countedCash ?? this.countedCash,
      difference: difference ?? this.difference,
      serverExpectedCash: serverExpectedCash ?? this.serverExpectedCash,
      note: note ?? this.note,
      closedBy: closedBy ?? this.closedBy,
      approvedBy: approvedBy ?? this.approvedBy,
      closedAt: closedAt ?? this.closedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      openingCash: openingCash ?? this.openingCash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (expectedCash.present) {
      map['expected_cash'] = Variable<int>(expectedCash.value);
    }
    if (countedCash.present) {
      map['counted_cash'] = Variable<int>(countedCash.value);
    }
    if (difference.present) {
      map['difference'] = Variable<int>(difference.value);
    }
    if (serverExpectedCash.present) {
      map['server_expected_cash'] = Variable<int>(serverExpectedCash.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (closedBy.present) {
      map['closed_by'] = Variable<String>(closedBy.value);
    }
    if (approvedBy.present) {
      map['approved_by'] = Variable<String>(approvedBy.value);
    }
    if (closedAt.present) {
      map['closed_at'] = Variable<String>(closedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (openingCash.present) {
      map['opening_cash'] = Variable<int>(openingCash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DayClosesCompanion(')
          ..write('id: $id, ')
          ..write('locationId: $locationId, ')
          ..write('day: $day, ')
          ..write('currency: $currency, ')
          ..write('expectedCash: $expectedCash, ')
          ..write('countedCash: $countedCash, ')
          ..write('difference: $difference, ')
          ..write('serverExpectedCash: $serverExpectedCash, ')
          ..write('note: $note, ')
          ..write('closedBy: $closedBy, ')
          ..write('approvedBy: $approvedBy, ')
          ..write('closedAt: $closedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('openingCash: $openingCash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ServiceTxnsTable extends ServiceTxns
    with TableInfo<$ServiceTxnsTable, ServiceTxn> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServiceTxnsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationIdMeta = const VerificationMeta(
    'locationId',
  );
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
    'location_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _walletMeta = const VerificationMeta('wallet');
  @override
  late final GeneratedColumn<String> wallet = GeneratedColumn<String>(
    'wallet',
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
  static const VerificationMeta _feeMeta = const VerificationMeta('fee');
  @override
  late final GeneratedColumn<int> fee = GeneratedColumn<int>(
    'fee',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<int> price = GeneratedColumn<int>(
    'price',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _refMeta = const VerificationMeta('ref');
  @override
  late final GeneratedColumn<String> ref = GeneratedColumn<String>(
    'ref',
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
  static const VerificationMeta _txnAtMeta = const VerificationMeta('txnAt');
  @override
  late final GeneratedColumn<String> txnAt = GeneratedColumn<String>(
    'txn_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _approvedByMeta = const VerificationMeta(
    'approvedBy',
  );
  @override
  late final GeneratedColumn<String> approvedBy = GeneratedColumn<String>(
    'approved_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _voidApprovedByMeta = const VerificationMeta(
    'voidApprovedBy',
  );
  @override
  late final GeneratedColumn<String> voidApprovedBy = GeneratedColumn<String>(
    'void_approved_by',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    locationId,
    kind,
    wallet,
    amount,
    fee,
    price,
    currency,
    ref,
    note,
    txnAt,
    createdBy,
    approvedBy,
    voidedAt,
    voidReason,
    voidApprovedBy,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'service_txns';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServiceTxn> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('location_id')) {
      context.handle(
        _locationIdMeta,
        locationId.isAcceptableOrUnknown(data['location_id']!, _locationIdMeta),
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
    if (data.containsKey('wallet')) {
      context.handle(
        _walletMeta,
        wallet.isAcceptableOrUnknown(data['wallet']!, _walletMeta),
      );
    } else if (isInserting) {
      context.missing(_walletMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('fee')) {
      context.handle(
        _feeMeta,
        fee.isAcceptableOrUnknown(data['fee']!, _feeMeta),
      );
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('ref')) {
      context.handle(
        _refMeta,
        ref.isAcceptableOrUnknown(data['ref']!, _refMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('txn_at')) {
      context.handle(
        _txnAtMeta,
        txnAt.isAcceptableOrUnknown(data['txn_at']!, _txnAtMeta),
      );
    } else if (isInserting) {
      context.missing(_txnAtMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('approved_by')) {
      context.handle(
        _approvedByMeta,
        approvedBy.isAcceptableOrUnknown(data['approved_by']!, _approvedByMeta),
      );
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
    if (data.containsKey('void_approved_by')) {
      context.handle(
        _voidApprovedByMeta,
        voidApprovedBy.isAcceptableOrUnknown(
          data['void_approved_by']!,
          _voidApprovedByMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ServiceTxn map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServiceTxn(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      locationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_id'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      wallet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wallet'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      fee: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fee'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      ref: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      txnAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}txn_at'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      approvedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}approved_by'],
      ),
      voidedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voided_at'],
      ),
      voidReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}void_reason'],
      ),
      voidApprovedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}void_approved_by'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $ServiceTxnsTable createAlias(String alias) {
    return $ServiceTxnsTable(attachedDatabase, alias);
  }
}

class ServiceTxn extends DataClass implements Insertable<ServiceTxn> {
  final String id;
  final String? locationId;

  /// cash_in | cash_out | load | float_topup | float_withdraw | float_adjust
  final String kind;

  /// gcash | maya | load | other
  final String wallet;

  /// Centavos; > 0, except a float_adjust (signed, never 0).
  final int amount;
  final int fee;

  /// Cash the customer paid for a load (load only).
  final int? price;
  final String currency;

  /// Customer reference (phone, wallet reference no.). Sensitive: shown in the list only.
  final String? ref;
  final String? note;

  /// UTC ISO-8601, normalised (same format as `sales.sold_at`).
  final String txnAt;
  final String? createdBy;
  final String? approvedBy;
  final String? voidedAt;
  final String? voidReason;
  final String? voidApprovedBy;
  final String? updatedAt;
  const ServiceTxn({
    required this.id,
    this.locationId,
    required this.kind,
    required this.wallet,
    required this.amount,
    required this.fee,
    this.price,
    required this.currency,
    this.ref,
    this.note,
    required this.txnAt,
    this.createdBy,
    this.approvedBy,
    this.voidedAt,
    this.voidReason,
    this.voidApprovedBy,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || locationId != null) {
      map['location_id'] = Variable<String>(locationId);
    }
    map['kind'] = Variable<String>(kind);
    map['wallet'] = Variable<String>(wallet);
    map['amount'] = Variable<int>(amount);
    map['fee'] = Variable<int>(fee);
    if (!nullToAbsent || price != null) {
      map['price'] = Variable<int>(price);
    }
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || ref != null) {
      map['ref'] = Variable<String>(ref);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['txn_at'] = Variable<String>(txnAt);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || approvedBy != null) {
      map['approved_by'] = Variable<String>(approvedBy);
    }
    if (!nullToAbsent || voidedAt != null) {
      map['voided_at'] = Variable<String>(voidedAt);
    }
    if (!nullToAbsent || voidReason != null) {
      map['void_reason'] = Variable<String>(voidReason);
    }
    if (!nullToAbsent || voidApprovedBy != null) {
      map['void_approved_by'] = Variable<String>(voidApprovedBy);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    return map;
  }

  ServiceTxnsCompanion toCompanion(bool nullToAbsent) {
    return ServiceTxnsCompanion(
      id: Value(id),
      locationId: locationId == null && nullToAbsent
          ? const Value.absent()
          : Value(locationId),
      kind: Value(kind),
      wallet: Value(wallet),
      amount: Value(amount),
      fee: Value(fee),
      price: price == null && nullToAbsent
          ? const Value.absent()
          : Value(price),
      currency: Value(currency),
      ref: ref == null && nullToAbsent ? const Value.absent() : Value(ref),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      txnAt: Value(txnAt),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      approvedBy: approvedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(approvedBy),
      voidedAt: voidedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(voidedAt),
      voidReason: voidReason == null && nullToAbsent
          ? const Value.absent()
          : Value(voidReason),
      voidApprovedBy: voidApprovedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(voidApprovedBy),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory ServiceTxn.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServiceTxn(
      id: serializer.fromJson<String>(json['id']),
      locationId: serializer.fromJson<String?>(json['locationId']),
      kind: serializer.fromJson<String>(json['kind']),
      wallet: serializer.fromJson<String>(json['wallet']),
      amount: serializer.fromJson<int>(json['amount']),
      fee: serializer.fromJson<int>(json['fee']),
      price: serializer.fromJson<int?>(json['price']),
      currency: serializer.fromJson<String>(json['currency']),
      ref: serializer.fromJson<String?>(json['ref']),
      note: serializer.fromJson<String?>(json['note']),
      txnAt: serializer.fromJson<String>(json['txnAt']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      approvedBy: serializer.fromJson<String?>(json['approvedBy']),
      voidedAt: serializer.fromJson<String?>(json['voidedAt']),
      voidReason: serializer.fromJson<String?>(json['voidReason']),
      voidApprovedBy: serializer.fromJson<String?>(json['voidApprovedBy']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'locationId': serializer.toJson<String?>(locationId),
      'kind': serializer.toJson<String>(kind),
      'wallet': serializer.toJson<String>(wallet),
      'amount': serializer.toJson<int>(amount),
      'fee': serializer.toJson<int>(fee),
      'price': serializer.toJson<int?>(price),
      'currency': serializer.toJson<String>(currency),
      'ref': serializer.toJson<String?>(ref),
      'note': serializer.toJson<String?>(note),
      'txnAt': serializer.toJson<String>(txnAt),
      'createdBy': serializer.toJson<String?>(createdBy),
      'approvedBy': serializer.toJson<String?>(approvedBy),
      'voidedAt': serializer.toJson<String?>(voidedAt),
      'voidReason': serializer.toJson<String?>(voidReason),
      'voidApprovedBy': serializer.toJson<String?>(voidApprovedBy),
      'updatedAt': serializer.toJson<String?>(updatedAt),
    };
  }

  ServiceTxn copyWith({
    String? id,
    Value<String?> locationId = const Value.absent(),
    String? kind,
    String? wallet,
    int? amount,
    int? fee,
    Value<int?> price = const Value.absent(),
    String? currency,
    Value<String?> ref = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? txnAt,
    Value<String?> createdBy = const Value.absent(),
    Value<String?> approvedBy = const Value.absent(),
    Value<String?> voidedAt = const Value.absent(),
    Value<String?> voidReason = const Value.absent(),
    Value<String?> voidApprovedBy = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
  }) => ServiceTxn(
    id: id ?? this.id,
    locationId: locationId.present ? locationId.value : this.locationId,
    kind: kind ?? this.kind,
    wallet: wallet ?? this.wallet,
    amount: amount ?? this.amount,
    fee: fee ?? this.fee,
    price: price.present ? price.value : this.price,
    currency: currency ?? this.currency,
    ref: ref.present ? ref.value : this.ref,
    note: note.present ? note.value : this.note,
    txnAt: txnAt ?? this.txnAt,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    approvedBy: approvedBy.present ? approvedBy.value : this.approvedBy,
    voidedAt: voidedAt.present ? voidedAt.value : this.voidedAt,
    voidReason: voidReason.present ? voidReason.value : this.voidReason,
    voidApprovedBy: voidApprovedBy.present
        ? voidApprovedBy.value
        : this.voidApprovedBy,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  ServiceTxn copyWithCompanion(ServiceTxnsCompanion data) {
    return ServiceTxn(
      id: data.id.present ? data.id.value : this.id,
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
      kind: data.kind.present ? data.kind.value : this.kind,
      wallet: data.wallet.present ? data.wallet.value : this.wallet,
      amount: data.amount.present ? data.amount.value : this.amount,
      fee: data.fee.present ? data.fee.value : this.fee,
      price: data.price.present ? data.price.value : this.price,
      currency: data.currency.present ? data.currency.value : this.currency,
      ref: data.ref.present ? data.ref.value : this.ref,
      note: data.note.present ? data.note.value : this.note,
      txnAt: data.txnAt.present ? data.txnAt.value : this.txnAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      approvedBy: data.approvedBy.present
          ? data.approvedBy.value
          : this.approvedBy,
      voidedAt: data.voidedAt.present ? data.voidedAt.value : this.voidedAt,
      voidReason: data.voidReason.present
          ? data.voidReason.value
          : this.voidReason,
      voidApprovedBy: data.voidApprovedBy.present
          ? data.voidApprovedBy.value
          : this.voidApprovedBy,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServiceTxn(')
          ..write('id: $id, ')
          ..write('locationId: $locationId, ')
          ..write('kind: $kind, ')
          ..write('wallet: $wallet, ')
          ..write('amount: $amount, ')
          ..write('fee: $fee, ')
          ..write('price: $price, ')
          ..write('currency: $currency, ')
          ..write('ref: $ref, ')
          ..write('note: $note, ')
          ..write('txnAt: $txnAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('approvedBy: $approvedBy, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('voidReason: $voidReason, ')
          ..write('voidApprovedBy: $voidApprovedBy, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    locationId,
    kind,
    wallet,
    amount,
    fee,
    price,
    currency,
    ref,
    note,
    txnAt,
    createdBy,
    approvedBy,
    voidedAt,
    voidReason,
    voidApprovedBy,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServiceTxn &&
          other.id == this.id &&
          other.locationId == this.locationId &&
          other.kind == this.kind &&
          other.wallet == this.wallet &&
          other.amount == this.amount &&
          other.fee == this.fee &&
          other.price == this.price &&
          other.currency == this.currency &&
          other.ref == this.ref &&
          other.note == this.note &&
          other.txnAt == this.txnAt &&
          other.createdBy == this.createdBy &&
          other.approvedBy == this.approvedBy &&
          other.voidedAt == this.voidedAt &&
          other.voidReason == this.voidReason &&
          other.voidApprovedBy == this.voidApprovedBy &&
          other.updatedAt == this.updatedAt);
}

class ServiceTxnsCompanion extends UpdateCompanion<ServiceTxn> {
  final Value<String> id;
  final Value<String?> locationId;
  final Value<String> kind;
  final Value<String> wallet;
  final Value<int> amount;
  final Value<int> fee;
  final Value<int?> price;
  final Value<String> currency;
  final Value<String?> ref;
  final Value<String?> note;
  final Value<String> txnAt;
  final Value<String?> createdBy;
  final Value<String?> approvedBy;
  final Value<String?> voidedAt;
  final Value<String?> voidReason;
  final Value<String?> voidApprovedBy;
  final Value<String?> updatedAt;
  final Value<int> rowid;
  const ServiceTxnsCompanion({
    this.id = const Value.absent(),
    this.locationId = const Value.absent(),
    this.kind = const Value.absent(),
    this.wallet = const Value.absent(),
    this.amount = const Value.absent(),
    this.fee = const Value.absent(),
    this.price = const Value.absent(),
    this.currency = const Value.absent(),
    this.ref = const Value.absent(),
    this.note = const Value.absent(),
    this.txnAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.approvedBy = const Value.absent(),
    this.voidedAt = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.voidApprovedBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServiceTxnsCompanion.insert({
    required String id,
    this.locationId = const Value.absent(),
    required String kind,
    required String wallet,
    required int amount,
    this.fee = const Value.absent(),
    this.price = const Value.absent(),
    required String currency,
    this.ref = const Value.absent(),
    this.note = const Value.absent(),
    required String txnAt,
    this.createdBy = const Value.absent(),
    this.approvedBy = const Value.absent(),
    this.voidedAt = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.voidApprovedBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       wallet = Value(wallet),
       amount = Value(amount),
       currency = Value(currency),
       txnAt = Value(txnAt);
  static Insertable<ServiceTxn> custom({
    Expression<String>? id,
    Expression<String>? locationId,
    Expression<String>? kind,
    Expression<String>? wallet,
    Expression<int>? amount,
    Expression<int>? fee,
    Expression<int>? price,
    Expression<String>? currency,
    Expression<String>? ref,
    Expression<String>? note,
    Expression<String>? txnAt,
    Expression<String>? createdBy,
    Expression<String>? approvedBy,
    Expression<String>? voidedAt,
    Expression<String>? voidReason,
    Expression<String>? voidApprovedBy,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (locationId != null) 'location_id': locationId,
      if (kind != null) 'kind': kind,
      if (wallet != null) 'wallet': wallet,
      if (amount != null) 'amount': amount,
      if (fee != null) 'fee': fee,
      if (price != null) 'price': price,
      if (currency != null) 'currency': currency,
      if (ref != null) 'ref': ref,
      if (note != null) 'note': note,
      if (txnAt != null) 'txn_at': txnAt,
      if (createdBy != null) 'created_by': createdBy,
      if (approvedBy != null) 'approved_by': approvedBy,
      if (voidedAt != null) 'voided_at': voidedAt,
      if (voidReason != null) 'void_reason': voidReason,
      if (voidApprovedBy != null) 'void_approved_by': voidApprovedBy,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServiceTxnsCompanion copyWith({
    Value<String>? id,
    Value<String?>? locationId,
    Value<String>? kind,
    Value<String>? wallet,
    Value<int>? amount,
    Value<int>? fee,
    Value<int?>? price,
    Value<String>? currency,
    Value<String?>? ref,
    Value<String?>? note,
    Value<String>? txnAt,
    Value<String?>? createdBy,
    Value<String?>? approvedBy,
    Value<String?>? voidedAt,
    Value<String?>? voidReason,
    Value<String?>? voidApprovedBy,
    Value<String?>? updatedAt,
    Value<int>? rowid,
  }) {
    return ServiceTxnsCompanion(
      id: id ?? this.id,
      locationId: locationId ?? this.locationId,
      kind: kind ?? this.kind,
      wallet: wallet ?? this.wallet,
      amount: amount ?? this.amount,
      fee: fee ?? this.fee,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      ref: ref ?? this.ref,
      note: note ?? this.note,
      txnAt: txnAt ?? this.txnAt,
      createdBy: createdBy ?? this.createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      voidedAt: voidedAt ?? this.voidedAt,
      voidReason: voidReason ?? this.voidReason,
      voidApprovedBy: voidApprovedBy ?? this.voidApprovedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (wallet.present) {
      map['wallet'] = Variable<String>(wallet.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (fee.present) {
      map['fee'] = Variable<int>(fee.value);
    }
    if (price.present) {
      map['price'] = Variable<int>(price.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (ref.present) {
      map['ref'] = Variable<String>(ref.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (txnAt.present) {
      map['txn_at'] = Variable<String>(txnAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (approvedBy.present) {
      map['approved_by'] = Variable<String>(approvedBy.value);
    }
    if (voidedAt.present) {
      map['voided_at'] = Variable<String>(voidedAt.value);
    }
    if (voidReason.present) {
      map['void_reason'] = Variable<String>(voidReason.value);
    }
    if (voidApprovedBy.present) {
      map['void_approved_by'] = Variable<String>(voidApprovedBy.value);
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
    return (StringBuffer('ServiceTxnsCompanion(')
          ..write('id: $id, ')
          ..write('locationId: $locationId, ')
          ..write('kind: $kind, ')
          ..write('wallet: $wallet, ')
          ..write('amount: $amount, ')
          ..write('fee: $fee, ')
          ..write('price: $price, ')
          ..write('currency: $currency, ')
          ..write('ref: $ref, ')
          ..write('note: $note, ')
          ..write('txnAt: $txnAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('approvedBy: $approvedBy, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('voidReason: $voidReason, ')
          ..write('voidApprovedBy: $voidApprovedBy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WalletFloatsTable extends WalletFloats
    with TableInfo<$WalletFloatsTable, WalletFloat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletFloatsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _walletMeta = const VerificationMeta('wallet');
  @override
  late final GeneratedColumn<String> wallet = GeneratedColumn<String>(
    'wallet',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _balanceMeta = const VerificationMeta(
    'balance',
  );
  @override
  late final GeneratedColumn<int> balance = GeneratedColumn<int>(
    'balance',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _txnCountMeta = const VerificationMeta(
    'txnCount',
  );
  @override
  late final GeneratedColumn<int> txnCount = GeneratedColumn<int>(
    'txn_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  @override
  List<GeneratedColumn> get $columns => [
    locationId,
    wallet,
    balance,
    txnCount,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallet_float';
  @override
  VerificationContext validateIntegrity(
    Insertable<WalletFloat> instance, {
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
    if (data.containsKey('wallet')) {
      context.handle(
        _walletMeta,
        wallet.isAcceptableOrUnknown(data['wallet']!, _walletMeta),
      );
    } else if (isInserting) {
      context.missing(_walletMeta);
    }
    if (data.containsKey('balance')) {
      context.handle(
        _balanceMeta,
        balance.isAcceptableOrUnknown(data['balance']!, _balanceMeta),
      );
    } else if (isInserting) {
      context.missing(_balanceMeta);
    }
    if (data.containsKey('txn_count')) {
      context.handle(
        _txnCountMeta,
        txnCount.isAcceptableOrUnknown(data['txn_count']!, _txnCountMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {locationId, wallet};
  @override
  WalletFloat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalletFloat(
      locationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_id'],
      )!,
      wallet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wallet'],
      )!,
      balance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}balance'],
      )!,
      txnCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}txn_count'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $WalletFloatsTable createAlias(String alias) {
    return $WalletFloatsTable(attachedDatabase, alias);
  }
}

class WalletFloat extends DataClass implements Insertable<WalletFloat> {
  final String locationId;
  final String wallet;
  final int balance;
  final int txnCount;
  final String? updatedAt;
  const WalletFloat({
    required this.locationId,
    required this.wallet,
    required this.balance,
    required this.txnCount,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['location_id'] = Variable<String>(locationId);
    map['wallet'] = Variable<String>(wallet);
    map['balance'] = Variable<int>(balance);
    map['txn_count'] = Variable<int>(txnCount);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    return map;
  }

  WalletFloatsCompanion toCompanion(bool nullToAbsent) {
    return WalletFloatsCompanion(
      locationId: Value(locationId),
      wallet: Value(wallet),
      balance: Value(balance),
      txnCount: Value(txnCount),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory WalletFloat.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalletFloat(
      locationId: serializer.fromJson<String>(json['locationId']),
      wallet: serializer.fromJson<String>(json['wallet']),
      balance: serializer.fromJson<int>(json['balance']),
      txnCount: serializer.fromJson<int>(json['txnCount']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'locationId': serializer.toJson<String>(locationId),
      'wallet': serializer.toJson<String>(wallet),
      'balance': serializer.toJson<int>(balance),
      'txnCount': serializer.toJson<int>(txnCount),
      'updatedAt': serializer.toJson<String?>(updatedAt),
    };
  }

  WalletFloat copyWith({
    String? locationId,
    String? wallet,
    int? balance,
    int? txnCount,
    Value<String?> updatedAt = const Value.absent(),
  }) => WalletFloat(
    locationId: locationId ?? this.locationId,
    wallet: wallet ?? this.wallet,
    balance: balance ?? this.balance,
    txnCount: txnCount ?? this.txnCount,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  WalletFloat copyWithCompanion(WalletFloatsCompanion data) {
    return WalletFloat(
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
      wallet: data.wallet.present ? data.wallet.value : this.wallet,
      balance: data.balance.present ? data.balance.value : this.balance,
      txnCount: data.txnCount.present ? data.txnCount.value : this.txnCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalletFloat(')
          ..write('locationId: $locationId, ')
          ..write('wallet: $wallet, ')
          ..write('balance: $balance, ')
          ..write('txnCount: $txnCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(locationId, wallet, balance, txnCount, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalletFloat &&
          other.locationId == this.locationId &&
          other.wallet == this.wallet &&
          other.balance == this.balance &&
          other.txnCount == this.txnCount &&
          other.updatedAt == this.updatedAt);
}

class WalletFloatsCompanion extends UpdateCompanion<WalletFloat> {
  final Value<String> locationId;
  final Value<String> wallet;
  final Value<int> balance;
  final Value<int> txnCount;
  final Value<String?> updatedAt;
  final Value<int> rowid;
  const WalletFloatsCompanion({
    this.locationId = const Value.absent(),
    this.wallet = const Value.absent(),
    this.balance = const Value.absent(),
    this.txnCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WalletFloatsCompanion.insert({
    required String locationId,
    required String wallet,
    required int balance,
    this.txnCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : locationId = Value(locationId),
       wallet = Value(wallet),
       balance = Value(balance);
  static Insertable<WalletFloat> custom({
    Expression<String>? locationId,
    Expression<String>? wallet,
    Expression<int>? balance,
    Expression<int>? txnCount,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (locationId != null) 'location_id': locationId,
      if (wallet != null) 'wallet': wallet,
      if (balance != null) 'balance': balance,
      if (txnCount != null) 'txn_count': txnCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WalletFloatsCompanion copyWith({
    Value<String>? locationId,
    Value<String>? wallet,
    Value<int>? balance,
    Value<int>? txnCount,
    Value<String?>? updatedAt,
    Value<int>? rowid,
  }) {
    return WalletFloatsCompanion(
      locationId: locationId ?? this.locationId,
      wallet: wallet ?? this.wallet,
      balance: balance ?? this.balance,
      txnCount: txnCount ?? this.txnCount,
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
    if (wallet.present) {
      map['wallet'] = Variable<String>(wallet.value);
    }
    if (balance.present) {
      map['balance'] = Variable<int>(balance.value);
    }
    if (txnCount.present) {
      map['txn_count'] = Variable<int>(txnCount.value);
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
    return (StringBuffer('WalletFloatsCompanion(')
          ..write('locationId: $locationId, ')
          ..write('wallet: $wallet, ')
          ..write('balance: $balance, ')
          ..write('txnCount: $txnCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalFloatEffectsTable extends LocalFloatEffects
    with TableInfo<$LocalFloatEffectsTable, LocalFloatEffect> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalFloatEffectsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _txnIdMeta = const VerificationMeta('txnId');
  @override
  late final GeneratedColumn<String> txnId = GeneratedColumn<String>(
    'txn_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _walletMeta = const VerificationMeta('wallet');
  @override
  late final GeneratedColumn<String> wallet = GeneratedColumn<String>(
    'wallet',
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
  static const VerificationMeta _locationIdMeta = const VerificationMeta(
    'locationId',
  );
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
    'location_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    opId,
    txnId,
    wallet,
    amount,
    confirmedAfter,
    locationId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_float_effects';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalFloatEffect> instance, {
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
    if (data.containsKey('txn_id')) {
      context.handle(
        _txnIdMeta,
        txnId.isAcceptableOrUnknown(data['txn_id']!, _txnIdMeta),
      );
    } else if (isInserting) {
      context.missing(_txnIdMeta);
    }
    if (data.containsKey('wallet')) {
      context.handle(
        _walletMeta,
        wallet.isAcceptableOrUnknown(data['wallet']!, _walletMeta),
      );
    } else if (isInserting) {
      context.missing(_walletMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
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
    if (data.containsKey('location_id')) {
      context.handle(
        _locationIdMeta,
        locationId.isAcceptableOrUnknown(data['location_id']!, _locationIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalFloatEffect map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalFloatEffect(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      opId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op_id'],
      )!,
      txnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}txn_id'],
      )!,
      wallet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wallet'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      confirmedAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confirmed_after'],
      ),
      locationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_id'],
      ),
    );
  }

  @override
  $LocalFloatEffectsTable createAlias(String alias) {
    return $LocalFloatEffectsTable(attachedDatabase, alias);
  }
}

class LocalFloatEffect extends DataClass
    implements Insertable<LocalFloatEffect> {
  final int id;
  final String opId;
  final String txnId;
  final String wallet;
  final int amount;
  final String? confirmedAfter;

  /// The store whose wallet this moves (schema v13, F-01); matched against `wallet_float.location_id`.
  final String? locationId;
  const LocalFloatEffect({
    required this.id,
    required this.opId,
    required this.txnId,
    required this.wallet,
    required this.amount,
    this.confirmedAfter,
    this.locationId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['op_id'] = Variable<String>(opId);
    map['txn_id'] = Variable<String>(txnId);
    map['wallet'] = Variable<String>(wallet);
    map['amount'] = Variable<int>(amount);
    if (!nullToAbsent || confirmedAfter != null) {
      map['confirmed_after'] = Variable<String>(confirmedAfter);
    }
    if (!nullToAbsent || locationId != null) {
      map['location_id'] = Variable<String>(locationId);
    }
    return map;
  }

  LocalFloatEffectsCompanion toCompanion(bool nullToAbsent) {
    return LocalFloatEffectsCompanion(
      id: Value(id),
      opId: Value(opId),
      txnId: Value(txnId),
      wallet: Value(wallet),
      amount: Value(amount),
      confirmedAfter: confirmedAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(confirmedAfter),
      locationId: locationId == null && nullToAbsent
          ? const Value.absent()
          : Value(locationId),
    );
  }

  factory LocalFloatEffect.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalFloatEffect(
      id: serializer.fromJson<int>(json['id']),
      opId: serializer.fromJson<String>(json['opId']),
      txnId: serializer.fromJson<String>(json['txnId']),
      wallet: serializer.fromJson<String>(json['wallet']),
      amount: serializer.fromJson<int>(json['amount']),
      confirmedAfter: serializer.fromJson<String?>(json['confirmedAfter']),
      locationId: serializer.fromJson<String?>(json['locationId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'opId': serializer.toJson<String>(opId),
      'txnId': serializer.toJson<String>(txnId),
      'wallet': serializer.toJson<String>(wallet),
      'amount': serializer.toJson<int>(amount),
      'confirmedAfter': serializer.toJson<String?>(confirmedAfter),
      'locationId': serializer.toJson<String?>(locationId),
    };
  }

  LocalFloatEffect copyWith({
    int? id,
    String? opId,
    String? txnId,
    String? wallet,
    int? amount,
    Value<String?> confirmedAfter = const Value.absent(),
    Value<String?> locationId = const Value.absent(),
  }) => LocalFloatEffect(
    id: id ?? this.id,
    opId: opId ?? this.opId,
    txnId: txnId ?? this.txnId,
    wallet: wallet ?? this.wallet,
    amount: amount ?? this.amount,
    confirmedAfter: confirmedAfter.present
        ? confirmedAfter.value
        : this.confirmedAfter,
    locationId: locationId.present ? locationId.value : this.locationId,
  );
  LocalFloatEffect copyWithCompanion(LocalFloatEffectsCompanion data) {
    return LocalFloatEffect(
      id: data.id.present ? data.id.value : this.id,
      opId: data.opId.present ? data.opId.value : this.opId,
      txnId: data.txnId.present ? data.txnId.value : this.txnId,
      wallet: data.wallet.present ? data.wallet.value : this.wallet,
      amount: data.amount.present ? data.amount.value : this.amount,
      confirmedAfter: data.confirmedAfter.present
          ? data.confirmedAfter.value
          : this.confirmedAfter,
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalFloatEffect(')
          ..write('id: $id, ')
          ..write('opId: $opId, ')
          ..write('txnId: $txnId, ')
          ..write('wallet: $wallet, ')
          ..write('amount: $amount, ')
          ..write('confirmedAfter: $confirmedAfter, ')
          ..write('locationId: $locationId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, opId, txnId, wallet, amount, confirmedAfter, locationId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalFloatEffect &&
          other.id == this.id &&
          other.opId == this.opId &&
          other.txnId == this.txnId &&
          other.wallet == this.wallet &&
          other.amount == this.amount &&
          other.confirmedAfter == this.confirmedAfter &&
          other.locationId == this.locationId);
}

class LocalFloatEffectsCompanion extends UpdateCompanion<LocalFloatEffect> {
  final Value<int> id;
  final Value<String> opId;
  final Value<String> txnId;
  final Value<String> wallet;
  final Value<int> amount;
  final Value<String?> confirmedAfter;
  final Value<String?> locationId;
  const LocalFloatEffectsCompanion({
    this.id = const Value.absent(),
    this.opId = const Value.absent(),
    this.txnId = const Value.absent(),
    this.wallet = const Value.absent(),
    this.amount = const Value.absent(),
    this.confirmedAfter = const Value.absent(),
    this.locationId = const Value.absent(),
  });
  LocalFloatEffectsCompanion.insert({
    this.id = const Value.absent(),
    required String opId,
    required String txnId,
    required String wallet,
    required int amount,
    this.confirmedAfter = const Value.absent(),
    this.locationId = const Value.absent(),
  }) : opId = Value(opId),
       txnId = Value(txnId),
       wallet = Value(wallet),
       amount = Value(amount);
  static Insertable<LocalFloatEffect> custom({
    Expression<int>? id,
    Expression<String>? opId,
    Expression<String>? txnId,
    Expression<String>? wallet,
    Expression<int>? amount,
    Expression<String>? confirmedAfter,
    Expression<String>? locationId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (opId != null) 'op_id': opId,
      if (txnId != null) 'txn_id': txnId,
      if (wallet != null) 'wallet': wallet,
      if (amount != null) 'amount': amount,
      if (confirmedAfter != null) 'confirmed_after': confirmedAfter,
      if (locationId != null) 'location_id': locationId,
    });
  }

  LocalFloatEffectsCompanion copyWith({
    Value<int>? id,
    Value<String>? opId,
    Value<String>? txnId,
    Value<String>? wallet,
    Value<int>? amount,
    Value<String?>? confirmedAfter,
    Value<String?>? locationId,
  }) {
    return LocalFloatEffectsCompanion(
      id: id ?? this.id,
      opId: opId ?? this.opId,
      txnId: txnId ?? this.txnId,
      wallet: wallet ?? this.wallet,
      amount: amount ?? this.amount,
      confirmedAfter: confirmedAfter ?? this.confirmedAfter,
      locationId: locationId ?? this.locationId,
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
    if (txnId.present) {
      map['txn_id'] = Variable<String>(txnId.value);
    }
    if (wallet.present) {
      map['wallet'] = Variable<String>(wallet.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (confirmedAfter.present) {
      map['confirmed_after'] = Variable<String>(confirmedAfter.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalFloatEffectsCompanion(')
          ..write('id: $id, ')
          ..write('opId: $opId, ')
          ..write('txnId: $txnId, ')
          ..write('wallet: $wallet, ')
          ..write('amount: $amount, ')
          ..write('confirmedAfter: $confirmedAfter, ')
          ..write('locationId: $locationId')
          ..write(')'))
        .toString();
  }
}

class $ConversionsTable extends Conversions
    with TableInfo<$ConversionsTable, Conversion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationIdMeta = const VerificationMeta(
    'locationId',
  );
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
    'location_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _packVariantIdMeta = const VerificationMeta(
    'packVariantId',
  );
  @override
  late final GeneratedColumn<String> packVariantId = GeneratedColumn<String>(
    'pack_variant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pieceVariantIdMeta = const VerificationMeta(
    'pieceVariantId',
  );
  @override
  late final GeneratedColumn<String> pieceVariantId = GeneratedColumn<String>(
    'piece_variant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packsMeta = const VerificationMeta('packs');
  @override
  late final GeneratedColumn<int> packs = GeneratedColumn<int>(
    'packs',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ratioMeta = const VerificationMeta('ratio');
  @override
  late final GeneratedColumn<int> ratio = GeneratedColumn<int>(
    'ratio',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _piecesMeta = const VerificationMeta('pieces');
  @override
  late final GeneratedColumn<int> pieces = GeneratedColumn<int>(
    'pieces',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packCostMeta = const VerificationMeta(
    'packCost',
  );
  @override
  late final GeneratedColumn<int> packCost = GeneratedColumn<int>(
    'pack_cost',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalCostMeta = const VerificationMeta(
    'totalCost',
  );
  @override
  late final GeneratedColumn<int> totalCost = GeneratedColumn<int>(
    'total_cost',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pieceCostMeta = const VerificationMeta(
    'pieceCost',
  );
  @override
  late final GeneratedColumn<int> pieceCost = GeneratedColumn<int>(
    'piece_cost',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  static const VerificationMeta _convertedAtMeta = const VerificationMeta(
    'convertedAt',
  );
  @override
  late final GeneratedColumn<String> convertedAt = GeneratedColumn<String>(
    'converted_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    locationId,
    packVariantId,
    pieceVariantId,
    packs,
    ratio,
    pieces,
    packCost,
    totalCost,
    pieceCost,
    note,
    convertedAt,
    createdBy,
    voidedAt,
    voidReason,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Conversion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('location_id')) {
      context.handle(
        _locationIdMeta,
        locationId.isAcceptableOrUnknown(data['location_id']!, _locationIdMeta),
      );
    }
    if (data.containsKey('pack_variant_id')) {
      context.handle(
        _packVariantIdMeta,
        packVariantId.isAcceptableOrUnknown(
          data['pack_variant_id']!,
          _packVariantIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_packVariantIdMeta);
    }
    if (data.containsKey('piece_variant_id')) {
      context.handle(
        _pieceVariantIdMeta,
        pieceVariantId.isAcceptableOrUnknown(
          data['piece_variant_id']!,
          _pieceVariantIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pieceVariantIdMeta);
    }
    if (data.containsKey('packs')) {
      context.handle(
        _packsMeta,
        packs.isAcceptableOrUnknown(data['packs']!, _packsMeta),
      );
    } else if (isInserting) {
      context.missing(_packsMeta);
    }
    if (data.containsKey('ratio')) {
      context.handle(
        _ratioMeta,
        ratio.isAcceptableOrUnknown(data['ratio']!, _ratioMeta),
      );
    } else if (isInserting) {
      context.missing(_ratioMeta);
    }
    if (data.containsKey('pieces')) {
      context.handle(
        _piecesMeta,
        pieces.isAcceptableOrUnknown(data['pieces']!, _piecesMeta),
      );
    } else if (isInserting) {
      context.missing(_piecesMeta);
    }
    if (data.containsKey('pack_cost')) {
      context.handle(
        _packCostMeta,
        packCost.isAcceptableOrUnknown(data['pack_cost']!, _packCostMeta),
      );
    }
    if (data.containsKey('total_cost')) {
      context.handle(
        _totalCostMeta,
        totalCost.isAcceptableOrUnknown(data['total_cost']!, _totalCostMeta),
      );
    }
    if (data.containsKey('piece_cost')) {
      context.handle(
        _pieceCostMeta,
        pieceCost.isAcceptableOrUnknown(data['piece_cost']!, _pieceCostMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('converted_at')) {
      context.handle(
        _convertedAtMeta,
        convertedAt.isAcceptableOrUnknown(
          data['converted_at']!,
          _convertedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_convertedAtMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Conversion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conversion(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      locationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_id'],
      ),
      packVariantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pack_variant_id'],
      )!,
      pieceVariantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}piece_variant_id'],
      )!,
      packs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}packs'],
      )!,
      ratio: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ratio'],
      )!,
      pieces: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pieces'],
      )!,
      packCost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pack_cost'],
      ),
      totalCost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_cost'],
      ),
      pieceCost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}piece_cost'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      convertedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}converted_at'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      voidedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voided_at'],
      ),
      voidReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}void_reason'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $ConversionsTable createAlias(String alias) {
    return $ConversionsTable(attachedDatabase, alias);
  }
}

class Conversion extends DataClass implements Insertable<Conversion> {
  final String id;
  final String? locationId;
  final String packVariantId;
  final String pieceVariantId;
  final int packs;

  /// Pieces per pack at the time of opening.
  final int ratio;
  final int pieces;

  /// Centavos: pack cost used, packs x pack cost, half_up(total / pieces). Null when no cost was known.
  final int? packCost;
  final int? totalCost;
  final int? pieceCost;
  final String? note;

  /// UTC ISO-8601, normalised (same format as `sales.sold_at`).
  final String convertedAt;
  final String? createdBy;
  final String? voidedAt;
  final String? voidReason;
  final String? updatedAt;
  const Conversion({
    required this.id,
    this.locationId,
    required this.packVariantId,
    required this.pieceVariantId,
    required this.packs,
    required this.ratio,
    required this.pieces,
    this.packCost,
    this.totalCost,
    this.pieceCost,
    this.note,
    required this.convertedAt,
    this.createdBy,
    this.voidedAt,
    this.voidReason,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || locationId != null) {
      map['location_id'] = Variable<String>(locationId);
    }
    map['pack_variant_id'] = Variable<String>(packVariantId);
    map['piece_variant_id'] = Variable<String>(pieceVariantId);
    map['packs'] = Variable<int>(packs);
    map['ratio'] = Variable<int>(ratio);
    map['pieces'] = Variable<int>(pieces);
    if (!nullToAbsent || packCost != null) {
      map['pack_cost'] = Variable<int>(packCost);
    }
    if (!nullToAbsent || totalCost != null) {
      map['total_cost'] = Variable<int>(totalCost);
    }
    if (!nullToAbsent || pieceCost != null) {
      map['piece_cost'] = Variable<int>(pieceCost);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['converted_at'] = Variable<String>(convertedAt);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || voidedAt != null) {
      map['voided_at'] = Variable<String>(voidedAt);
    }
    if (!nullToAbsent || voidReason != null) {
      map['void_reason'] = Variable<String>(voidReason);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    return map;
  }

  ConversionsCompanion toCompanion(bool nullToAbsent) {
    return ConversionsCompanion(
      id: Value(id),
      locationId: locationId == null && nullToAbsent
          ? const Value.absent()
          : Value(locationId),
      packVariantId: Value(packVariantId),
      pieceVariantId: Value(pieceVariantId),
      packs: Value(packs),
      ratio: Value(ratio),
      pieces: Value(pieces),
      packCost: packCost == null && nullToAbsent
          ? const Value.absent()
          : Value(packCost),
      totalCost: totalCost == null && nullToAbsent
          ? const Value.absent()
          : Value(totalCost),
      pieceCost: pieceCost == null && nullToAbsent
          ? const Value.absent()
          : Value(pieceCost),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      convertedAt: Value(convertedAt),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      voidedAt: voidedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(voidedAt),
      voidReason: voidReason == null && nullToAbsent
          ? const Value.absent()
          : Value(voidReason),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory Conversion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conversion(
      id: serializer.fromJson<String>(json['id']),
      locationId: serializer.fromJson<String?>(json['locationId']),
      packVariantId: serializer.fromJson<String>(json['packVariantId']),
      pieceVariantId: serializer.fromJson<String>(json['pieceVariantId']),
      packs: serializer.fromJson<int>(json['packs']),
      ratio: serializer.fromJson<int>(json['ratio']),
      pieces: serializer.fromJson<int>(json['pieces']),
      packCost: serializer.fromJson<int?>(json['packCost']),
      totalCost: serializer.fromJson<int?>(json['totalCost']),
      pieceCost: serializer.fromJson<int?>(json['pieceCost']),
      note: serializer.fromJson<String?>(json['note']),
      convertedAt: serializer.fromJson<String>(json['convertedAt']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      voidedAt: serializer.fromJson<String?>(json['voidedAt']),
      voidReason: serializer.fromJson<String?>(json['voidReason']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'locationId': serializer.toJson<String?>(locationId),
      'packVariantId': serializer.toJson<String>(packVariantId),
      'pieceVariantId': serializer.toJson<String>(pieceVariantId),
      'packs': serializer.toJson<int>(packs),
      'ratio': serializer.toJson<int>(ratio),
      'pieces': serializer.toJson<int>(pieces),
      'packCost': serializer.toJson<int?>(packCost),
      'totalCost': serializer.toJson<int?>(totalCost),
      'pieceCost': serializer.toJson<int?>(pieceCost),
      'note': serializer.toJson<String?>(note),
      'convertedAt': serializer.toJson<String>(convertedAt),
      'createdBy': serializer.toJson<String?>(createdBy),
      'voidedAt': serializer.toJson<String?>(voidedAt),
      'voidReason': serializer.toJson<String?>(voidReason),
      'updatedAt': serializer.toJson<String?>(updatedAt),
    };
  }

  Conversion copyWith({
    String? id,
    Value<String?> locationId = const Value.absent(),
    String? packVariantId,
    String? pieceVariantId,
    int? packs,
    int? ratio,
    int? pieces,
    Value<int?> packCost = const Value.absent(),
    Value<int?> totalCost = const Value.absent(),
    Value<int?> pieceCost = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? convertedAt,
    Value<String?> createdBy = const Value.absent(),
    Value<String?> voidedAt = const Value.absent(),
    Value<String?> voidReason = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
  }) => Conversion(
    id: id ?? this.id,
    locationId: locationId.present ? locationId.value : this.locationId,
    packVariantId: packVariantId ?? this.packVariantId,
    pieceVariantId: pieceVariantId ?? this.pieceVariantId,
    packs: packs ?? this.packs,
    ratio: ratio ?? this.ratio,
    pieces: pieces ?? this.pieces,
    packCost: packCost.present ? packCost.value : this.packCost,
    totalCost: totalCost.present ? totalCost.value : this.totalCost,
    pieceCost: pieceCost.present ? pieceCost.value : this.pieceCost,
    note: note.present ? note.value : this.note,
    convertedAt: convertedAt ?? this.convertedAt,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    voidedAt: voidedAt.present ? voidedAt.value : this.voidedAt,
    voidReason: voidReason.present ? voidReason.value : this.voidReason,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  Conversion copyWithCompanion(ConversionsCompanion data) {
    return Conversion(
      id: data.id.present ? data.id.value : this.id,
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
      packVariantId: data.packVariantId.present
          ? data.packVariantId.value
          : this.packVariantId,
      pieceVariantId: data.pieceVariantId.present
          ? data.pieceVariantId.value
          : this.pieceVariantId,
      packs: data.packs.present ? data.packs.value : this.packs,
      ratio: data.ratio.present ? data.ratio.value : this.ratio,
      pieces: data.pieces.present ? data.pieces.value : this.pieces,
      packCost: data.packCost.present ? data.packCost.value : this.packCost,
      totalCost: data.totalCost.present ? data.totalCost.value : this.totalCost,
      pieceCost: data.pieceCost.present ? data.pieceCost.value : this.pieceCost,
      note: data.note.present ? data.note.value : this.note,
      convertedAt: data.convertedAt.present
          ? data.convertedAt.value
          : this.convertedAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      voidedAt: data.voidedAt.present ? data.voidedAt.value : this.voidedAt,
      voidReason: data.voidReason.present
          ? data.voidReason.value
          : this.voidReason,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conversion(')
          ..write('id: $id, ')
          ..write('locationId: $locationId, ')
          ..write('packVariantId: $packVariantId, ')
          ..write('pieceVariantId: $pieceVariantId, ')
          ..write('packs: $packs, ')
          ..write('ratio: $ratio, ')
          ..write('pieces: $pieces, ')
          ..write('packCost: $packCost, ')
          ..write('totalCost: $totalCost, ')
          ..write('pieceCost: $pieceCost, ')
          ..write('note: $note, ')
          ..write('convertedAt: $convertedAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('voidReason: $voidReason, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    locationId,
    packVariantId,
    pieceVariantId,
    packs,
    ratio,
    pieces,
    packCost,
    totalCost,
    pieceCost,
    note,
    convertedAt,
    createdBy,
    voidedAt,
    voidReason,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conversion &&
          other.id == this.id &&
          other.locationId == this.locationId &&
          other.packVariantId == this.packVariantId &&
          other.pieceVariantId == this.pieceVariantId &&
          other.packs == this.packs &&
          other.ratio == this.ratio &&
          other.pieces == this.pieces &&
          other.packCost == this.packCost &&
          other.totalCost == this.totalCost &&
          other.pieceCost == this.pieceCost &&
          other.note == this.note &&
          other.convertedAt == this.convertedAt &&
          other.createdBy == this.createdBy &&
          other.voidedAt == this.voidedAt &&
          other.voidReason == this.voidReason &&
          other.updatedAt == this.updatedAt);
}

class ConversionsCompanion extends UpdateCompanion<Conversion> {
  final Value<String> id;
  final Value<String?> locationId;
  final Value<String> packVariantId;
  final Value<String> pieceVariantId;
  final Value<int> packs;
  final Value<int> ratio;
  final Value<int> pieces;
  final Value<int?> packCost;
  final Value<int?> totalCost;
  final Value<int?> pieceCost;
  final Value<String?> note;
  final Value<String> convertedAt;
  final Value<String?> createdBy;
  final Value<String?> voidedAt;
  final Value<String?> voidReason;
  final Value<String?> updatedAt;
  final Value<int> rowid;
  const ConversionsCompanion({
    this.id = const Value.absent(),
    this.locationId = const Value.absent(),
    this.packVariantId = const Value.absent(),
    this.pieceVariantId = const Value.absent(),
    this.packs = const Value.absent(),
    this.ratio = const Value.absent(),
    this.pieces = const Value.absent(),
    this.packCost = const Value.absent(),
    this.totalCost = const Value.absent(),
    this.pieceCost = const Value.absent(),
    this.note = const Value.absent(),
    this.convertedAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.voidedAt = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversionsCompanion.insert({
    required String id,
    this.locationId = const Value.absent(),
    required String packVariantId,
    required String pieceVariantId,
    required int packs,
    required int ratio,
    required int pieces,
    this.packCost = const Value.absent(),
    this.totalCost = const Value.absent(),
    this.pieceCost = const Value.absent(),
    this.note = const Value.absent(),
    required String convertedAt,
    this.createdBy = const Value.absent(),
    this.voidedAt = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       packVariantId = Value(packVariantId),
       pieceVariantId = Value(pieceVariantId),
       packs = Value(packs),
       ratio = Value(ratio),
       pieces = Value(pieces),
       convertedAt = Value(convertedAt);
  static Insertable<Conversion> custom({
    Expression<String>? id,
    Expression<String>? locationId,
    Expression<String>? packVariantId,
    Expression<String>? pieceVariantId,
    Expression<int>? packs,
    Expression<int>? ratio,
    Expression<int>? pieces,
    Expression<int>? packCost,
    Expression<int>? totalCost,
    Expression<int>? pieceCost,
    Expression<String>? note,
    Expression<String>? convertedAt,
    Expression<String>? createdBy,
    Expression<String>? voidedAt,
    Expression<String>? voidReason,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (locationId != null) 'location_id': locationId,
      if (packVariantId != null) 'pack_variant_id': packVariantId,
      if (pieceVariantId != null) 'piece_variant_id': pieceVariantId,
      if (packs != null) 'packs': packs,
      if (ratio != null) 'ratio': ratio,
      if (pieces != null) 'pieces': pieces,
      if (packCost != null) 'pack_cost': packCost,
      if (totalCost != null) 'total_cost': totalCost,
      if (pieceCost != null) 'piece_cost': pieceCost,
      if (note != null) 'note': note,
      if (convertedAt != null) 'converted_at': convertedAt,
      if (createdBy != null) 'created_by': createdBy,
      if (voidedAt != null) 'voided_at': voidedAt,
      if (voidReason != null) 'void_reason': voidReason,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? locationId,
    Value<String>? packVariantId,
    Value<String>? pieceVariantId,
    Value<int>? packs,
    Value<int>? ratio,
    Value<int>? pieces,
    Value<int?>? packCost,
    Value<int?>? totalCost,
    Value<int?>? pieceCost,
    Value<String?>? note,
    Value<String>? convertedAt,
    Value<String?>? createdBy,
    Value<String?>? voidedAt,
    Value<String?>? voidReason,
    Value<String?>? updatedAt,
    Value<int>? rowid,
  }) {
    return ConversionsCompanion(
      id: id ?? this.id,
      locationId: locationId ?? this.locationId,
      packVariantId: packVariantId ?? this.packVariantId,
      pieceVariantId: pieceVariantId ?? this.pieceVariantId,
      packs: packs ?? this.packs,
      ratio: ratio ?? this.ratio,
      pieces: pieces ?? this.pieces,
      packCost: packCost ?? this.packCost,
      totalCost: totalCost ?? this.totalCost,
      pieceCost: pieceCost ?? this.pieceCost,
      note: note ?? this.note,
      convertedAt: convertedAt ?? this.convertedAt,
      createdBy: createdBy ?? this.createdBy,
      voidedAt: voidedAt ?? this.voidedAt,
      voidReason: voidReason ?? this.voidReason,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (packVariantId.present) {
      map['pack_variant_id'] = Variable<String>(packVariantId.value);
    }
    if (pieceVariantId.present) {
      map['piece_variant_id'] = Variable<String>(pieceVariantId.value);
    }
    if (packs.present) {
      map['packs'] = Variable<int>(packs.value);
    }
    if (ratio.present) {
      map['ratio'] = Variable<int>(ratio.value);
    }
    if (pieces.present) {
      map['pieces'] = Variable<int>(pieces.value);
    }
    if (packCost.present) {
      map['pack_cost'] = Variable<int>(packCost.value);
    }
    if (totalCost.present) {
      map['total_cost'] = Variable<int>(totalCost.value);
    }
    if (pieceCost.present) {
      map['piece_cost'] = Variable<int>(pieceCost.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (convertedAt.present) {
      map['converted_at'] = Variable<String>(convertedAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (voidedAt.present) {
      map['voided_at'] = Variable<String>(voidedAt.value);
    }
    if (voidReason.present) {
      map['void_reason'] = Variable<String>(voidReason.value);
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
    return (StringBuffer('ConversionsCompanion(')
          ..write('id: $id, ')
          ..write('locationId: $locationId, ')
          ..write('packVariantId: $packVariantId, ')
          ..write('pieceVariantId: $pieceVariantId, ')
          ..write('packs: $packs, ')
          ..write('ratio: $ratio, ')
          ..write('pieces: $pieces, ')
          ..write('packCost: $packCost, ')
          ..write('totalCost: $totalCost, ')
          ..write('pieceCost: $pieceCost, ')
          ..write('note: $note, ')
          ..write('convertedAt: $convertedAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('voidReason: $voidReason, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StockExpiryTable extends StockExpiry
    with TableInfo<$StockExpiryTable, StockExpiryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockExpiryTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _locationIdMeta = const VerificationMeta(
    'locationId',
  );
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
    'location_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _expiresOnMeta = const VerificationMeta(
    'expiresOn',
  );
  @override
  late final GeneratedColumn<String> expiresOn = GeneratedColumn<String>(
    'expires_on',
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
  @override
  List<GeneratedColumn> get $columns => [
    variantId,
    locationId,
    expiresOn,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_expiry';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockExpiryData> instance, {
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
    if (data.containsKey('location_id')) {
      context.handle(
        _locationIdMeta,
        locationId.isAcceptableOrUnknown(data['location_id']!, _locationIdMeta),
      );
    }
    if (data.containsKey('expires_on')) {
      context.handle(
        _expiresOnMeta,
        expiresOn.isAcceptableOrUnknown(data['expires_on']!, _expiresOnMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {locationId, variantId};
  @override
  StockExpiryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockExpiryData(
      variantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variant_id'],
      )!,
      locationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_id'],
      )!,
      expiresOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expires_on'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $StockExpiryTable createAlias(String alias) {
    return $StockExpiryTable(attachedDatabase, alias);
  }
}

class StockExpiryData extends DataClass implements Insertable<StockExpiryData> {
  final String variantId;
  final String locationId;
  final String? expiresOn;
  final String? updatedAt;
  const StockExpiryData({
    required this.variantId,
    required this.locationId,
    this.expiresOn,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['variant_id'] = Variable<String>(variantId);
    map['location_id'] = Variable<String>(locationId);
    if (!nullToAbsent || expiresOn != null) {
      map['expires_on'] = Variable<String>(expiresOn);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    return map;
  }

  StockExpiryCompanion toCompanion(bool nullToAbsent) {
    return StockExpiryCompanion(
      variantId: Value(variantId),
      locationId: Value(locationId),
      expiresOn: expiresOn == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresOn),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory StockExpiryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockExpiryData(
      variantId: serializer.fromJson<String>(json['variantId']),
      locationId: serializer.fromJson<String>(json['locationId']),
      expiresOn: serializer.fromJson<String?>(json['expiresOn']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'variantId': serializer.toJson<String>(variantId),
      'locationId': serializer.toJson<String>(locationId),
      'expiresOn': serializer.toJson<String?>(expiresOn),
      'updatedAt': serializer.toJson<String?>(updatedAt),
    };
  }

  StockExpiryData copyWith({
    String? variantId,
    String? locationId,
    Value<String?> expiresOn = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
  }) => StockExpiryData(
    variantId: variantId ?? this.variantId,
    locationId: locationId ?? this.locationId,
    expiresOn: expiresOn.present ? expiresOn.value : this.expiresOn,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  StockExpiryData copyWithCompanion(StockExpiryCompanion data) {
    return StockExpiryData(
      variantId: data.variantId.present ? data.variantId.value : this.variantId,
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
      expiresOn: data.expiresOn.present ? data.expiresOn.value : this.expiresOn,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockExpiryData(')
          ..write('variantId: $variantId, ')
          ..write('locationId: $locationId, ')
          ..write('expiresOn: $expiresOn, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(variantId, locationId, expiresOn, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockExpiryData &&
          other.variantId == this.variantId &&
          other.locationId == this.locationId &&
          other.expiresOn == this.expiresOn &&
          other.updatedAt == this.updatedAt);
}

class StockExpiryCompanion extends UpdateCompanion<StockExpiryData> {
  final Value<String> variantId;
  final Value<String> locationId;
  final Value<String?> expiresOn;
  final Value<String?> updatedAt;
  final Value<int> rowid;
  const StockExpiryCompanion({
    this.variantId = const Value.absent(),
    this.locationId = const Value.absent(),
    this.expiresOn = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StockExpiryCompanion.insert({
    required String variantId,
    this.locationId = const Value.absent(),
    this.expiresOn = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : variantId = Value(variantId);
  static Insertable<StockExpiryData> custom({
    Expression<String>? variantId,
    Expression<String>? locationId,
    Expression<String>? expiresOn,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (variantId != null) 'variant_id': variantId,
      if (locationId != null) 'location_id': locationId,
      if (expiresOn != null) 'expires_on': expiresOn,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StockExpiryCompanion copyWith({
    Value<String>? variantId,
    Value<String>? locationId,
    Value<String?>? expiresOn,
    Value<String?>? updatedAt,
    Value<int>? rowid,
  }) {
    return StockExpiryCompanion(
      variantId: variantId ?? this.variantId,
      locationId: locationId ?? this.locationId,
      expiresOn: expiresOn ?? this.expiresOn,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (variantId.present) {
      map['variant_id'] = Variable<String>(variantId.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (expiresOn.present) {
      map['expires_on'] = Variable<String>(expiresOn.value);
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
    return (StringBuffer('StockExpiryCompanion(')
          ..write('variantId: $variantId, ')
          ..write('locationId: $locationId, ')
          ..write('expiresOn: $expiresOn, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WarehousesTable extends Warehouses
    with TableInfo<$WarehousesTable, Warehouse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WarehousesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
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
  static const VerificationMeta _binsEnabledMeta = const VerificationMeta(
    'binsEnabled',
  );
  @override
  late final GeneratedColumn<bool> binsEnabled = GeneratedColumn<bool>(
    'bins_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("bins_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    code,
    name,
    binsEnabled,
    active,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'warehouses';
  @override
  VerificationContext validateIntegrity(
    Insertable<Warehouse> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('bins_enabled')) {
      context.handle(
        _binsEnabledMeta,
        binsEnabled.isAcceptableOrUnknown(
          data['bins_enabled']!,
          _binsEnabledMeta,
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
  Warehouse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Warehouse(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      binsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}bins_enabled'],
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
  $WarehousesTable createAlias(String alias) {
    return $WarehousesTable(attachedDatabase, alias);
  }
}

class Warehouse extends DataClass implements Insertable<Warehouse> {
  final String id;
  final String code;
  final String name;
  final bool binsEnabled;
  final bool active;
  final String? updatedAt;
  final String? deletedAt;
  const Warehouse({
    required this.id,
    required this.code,
    required this.name,
    required this.binsEnabled,
    required this.active,
    this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['bins_enabled'] = Variable<bool>(binsEnabled);
    map['active'] = Variable<bool>(active);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  WarehousesCompanion toCompanion(bool nullToAbsent) {
    return WarehousesCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      binsEnabled: Value(binsEnabled),
      active: Value(active),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Warehouse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Warehouse(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      binsEnabled: serializer.fromJson<bool>(json['binsEnabled']),
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
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'binsEnabled': serializer.toJson<bool>(binsEnabled),
      'active': serializer.toJson<bool>(active),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  Warehouse copyWith({
    String? id,
    String? code,
    String? name,
    bool? binsEnabled,
    bool? active,
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
  }) => Warehouse(
    id: id ?? this.id,
    code: code ?? this.code,
    name: name ?? this.name,
    binsEnabled: binsEnabled ?? this.binsEnabled,
    active: active ?? this.active,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Warehouse copyWithCompanion(WarehousesCompanion data) {
    return Warehouse(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      binsEnabled: data.binsEnabled.present
          ? data.binsEnabled.value
          : this.binsEnabled,
      active: data.active.present ? data.active.value : this.active,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Warehouse(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('binsEnabled: $binsEnabled, ')
          ..write('active: $active, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, code, name, binsEnabled, active, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Warehouse &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.binsEnabled == this.binsEnabled &&
          other.active == this.active &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class WarehousesCompanion extends UpdateCompanion<Warehouse> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> name;
  final Value<bool> binsEnabled;
  final Value<bool> active;
  final Value<String?> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const WarehousesCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.binsEnabled = const Value.absent(),
    this.active = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WarehousesCompanion.insert({
    required String id,
    required String code,
    required String name,
    this.binsEnabled = const Value.absent(),
    this.active = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       code = Value(code),
       name = Value(name);
  static Insertable<Warehouse> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<bool>? binsEnabled,
    Expression<bool>? active,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (binsEnabled != null) 'bins_enabled': binsEnabled,
      if (active != null) 'active': active,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WarehousesCompanion copyWith({
    Value<String>? id,
    Value<String>? code,
    Value<String>? name,
    Value<bool>? binsEnabled,
    Value<bool>? active,
    Value<String?>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return WarehousesCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      binsEnabled: binsEnabled ?? this.binsEnabled,
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
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (binsEnabled.present) {
      map['bins_enabled'] = Variable<bool>(binsEnabled.value);
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
    return (StringBuffer('WarehousesCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('binsEnabled: $binsEnabled, ')
          ..write('active: $active, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WhBinsTable extends WhBins with TableInfo<$WhBinsTable, WhBin> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WhBinsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _warehouseIdMeta = const VerificationMeta(
    'warehouseId',
  );
  @override
  late final GeneratedColumn<String> warehouseId = GeneratedColumn<String>(
    'warehouse_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _zoneIdMeta = const VerificationMeta('zoneId');
  @override
  late final GeneratedColumn<String> zoneId = GeneratedColumn<String>(
    'zone_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aisleMeta = const VerificationMeta('aisle');
  @override
  late final GeneratedColumn<String> aisle = GeneratedColumn<String>(
    'aisle',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rackMeta = const VerificationMeta('rack');
  @override
  late final GeneratedColumn<String> rack = GeneratedColumn<String>(
    'rack',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shelfMeta = const VerificationMeta('shelf');
  @override
  late final GeneratedColumn<String> shelf = GeneratedColumn<String>(
    'shelf',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<String> position = GeneratedColumn<String>(
    'position',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('shelf'),
  );
  static const VerificationMeta _maxQtyMeta = const VerificationMeta('maxQty');
  @override
  late final GeneratedColumn<double> maxQty = GeneratedColumn<double>(
    'max_qty',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
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
    warehouseId,
    zoneId,
    code,
    aisle,
    rack,
    shelf,
    position,
    type,
    maxQty,
    active,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wh_bins';
  @override
  VerificationContext validateIntegrity(
    Insertable<WhBin> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('warehouse_id')) {
      context.handle(
        _warehouseIdMeta,
        warehouseId.isAcceptableOrUnknown(
          data['warehouse_id']!,
          _warehouseIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_warehouseIdMeta);
    }
    if (data.containsKey('zone_id')) {
      context.handle(
        _zoneIdMeta,
        zoneId.isAcceptableOrUnknown(data['zone_id']!, _zoneIdMeta),
      );
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('aisle')) {
      context.handle(
        _aisleMeta,
        aisle.isAcceptableOrUnknown(data['aisle']!, _aisleMeta),
      );
    }
    if (data.containsKey('rack')) {
      context.handle(
        _rackMeta,
        rack.isAcceptableOrUnknown(data['rack']!, _rackMeta),
      );
    }
    if (data.containsKey('shelf')) {
      context.handle(
        _shelfMeta,
        shelf.isAcceptableOrUnknown(data['shelf']!, _shelfMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('max_qty')) {
      context.handle(
        _maxQtyMeta,
        maxQty.isAcceptableOrUnknown(data['max_qty']!, _maxQtyMeta),
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
  WhBin map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WhBin(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      warehouseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}warehouse_id'],
      )!,
      zoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}zone_id'],
      ),
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      aisle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aisle'],
      ),
      rack: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rack'],
      ),
      shelf: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shelf'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}position'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      maxQty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_qty'],
      ),
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
  $WhBinsTable createAlias(String alias) {
    return $WhBinsTable(attachedDatabase, alias);
  }
}

class WhBin extends DataClass implements Insertable<WhBin> {
  final String id;
  final String warehouseId;
  final String? zoneId;
  final String code;
  final String? aisle;
  final String? rack;
  final String? shelf;
  final String? position;
  final String type;
  final double? maxQty;
  final bool active;
  final String? updatedAt;
  final String? deletedAt;
  const WhBin({
    required this.id,
    required this.warehouseId,
    this.zoneId,
    required this.code,
    this.aisle,
    this.rack,
    this.shelf,
    this.position,
    required this.type,
    this.maxQty,
    required this.active,
    this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['warehouse_id'] = Variable<String>(warehouseId);
    if (!nullToAbsent || zoneId != null) {
      map['zone_id'] = Variable<String>(zoneId);
    }
    map['code'] = Variable<String>(code);
    if (!nullToAbsent || aisle != null) {
      map['aisle'] = Variable<String>(aisle);
    }
    if (!nullToAbsent || rack != null) {
      map['rack'] = Variable<String>(rack);
    }
    if (!nullToAbsent || shelf != null) {
      map['shelf'] = Variable<String>(shelf);
    }
    if (!nullToAbsent || position != null) {
      map['position'] = Variable<String>(position);
    }
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || maxQty != null) {
      map['max_qty'] = Variable<double>(maxQty);
    }
    map['active'] = Variable<bool>(active);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  WhBinsCompanion toCompanion(bool nullToAbsent) {
    return WhBinsCompanion(
      id: Value(id),
      warehouseId: Value(warehouseId),
      zoneId: zoneId == null && nullToAbsent
          ? const Value.absent()
          : Value(zoneId),
      code: Value(code),
      aisle: aisle == null && nullToAbsent
          ? const Value.absent()
          : Value(aisle),
      rack: rack == null && nullToAbsent ? const Value.absent() : Value(rack),
      shelf: shelf == null && nullToAbsent
          ? const Value.absent()
          : Value(shelf),
      position: position == null && nullToAbsent
          ? const Value.absent()
          : Value(position),
      type: Value(type),
      maxQty: maxQty == null && nullToAbsent
          ? const Value.absent()
          : Value(maxQty),
      active: Value(active),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory WhBin.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WhBin(
      id: serializer.fromJson<String>(json['id']),
      warehouseId: serializer.fromJson<String>(json['warehouseId']),
      zoneId: serializer.fromJson<String?>(json['zoneId']),
      code: serializer.fromJson<String>(json['code']),
      aisle: serializer.fromJson<String?>(json['aisle']),
      rack: serializer.fromJson<String?>(json['rack']),
      shelf: serializer.fromJson<String?>(json['shelf']),
      position: serializer.fromJson<String?>(json['position']),
      type: serializer.fromJson<String>(json['type']),
      maxQty: serializer.fromJson<double?>(json['maxQty']),
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
      'warehouseId': serializer.toJson<String>(warehouseId),
      'zoneId': serializer.toJson<String?>(zoneId),
      'code': serializer.toJson<String>(code),
      'aisle': serializer.toJson<String?>(aisle),
      'rack': serializer.toJson<String?>(rack),
      'shelf': serializer.toJson<String?>(shelf),
      'position': serializer.toJson<String?>(position),
      'type': serializer.toJson<String>(type),
      'maxQty': serializer.toJson<double?>(maxQty),
      'active': serializer.toJson<bool>(active),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  WhBin copyWith({
    String? id,
    String? warehouseId,
    Value<String?> zoneId = const Value.absent(),
    String? code,
    Value<String?> aisle = const Value.absent(),
    Value<String?> rack = const Value.absent(),
    Value<String?> shelf = const Value.absent(),
    Value<String?> position = const Value.absent(),
    String? type,
    Value<double?> maxQty = const Value.absent(),
    bool? active,
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
  }) => WhBin(
    id: id ?? this.id,
    warehouseId: warehouseId ?? this.warehouseId,
    zoneId: zoneId.present ? zoneId.value : this.zoneId,
    code: code ?? this.code,
    aisle: aisle.present ? aisle.value : this.aisle,
    rack: rack.present ? rack.value : this.rack,
    shelf: shelf.present ? shelf.value : this.shelf,
    position: position.present ? position.value : this.position,
    type: type ?? this.type,
    maxQty: maxQty.present ? maxQty.value : this.maxQty,
    active: active ?? this.active,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  WhBin copyWithCompanion(WhBinsCompanion data) {
    return WhBin(
      id: data.id.present ? data.id.value : this.id,
      warehouseId: data.warehouseId.present
          ? data.warehouseId.value
          : this.warehouseId,
      zoneId: data.zoneId.present ? data.zoneId.value : this.zoneId,
      code: data.code.present ? data.code.value : this.code,
      aisle: data.aisle.present ? data.aisle.value : this.aisle,
      rack: data.rack.present ? data.rack.value : this.rack,
      shelf: data.shelf.present ? data.shelf.value : this.shelf,
      position: data.position.present ? data.position.value : this.position,
      type: data.type.present ? data.type.value : this.type,
      maxQty: data.maxQty.present ? data.maxQty.value : this.maxQty,
      active: data.active.present ? data.active.value : this.active,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WhBin(')
          ..write('id: $id, ')
          ..write('warehouseId: $warehouseId, ')
          ..write('zoneId: $zoneId, ')
          ..write('code: $code, ')
          ..write('aisle: $aisle, ')
          ..write('rack: $rack, ')
          ..write('shelf: $shelf, ')
          ..write('position: $position, ')
          ..write('type: $type, ')
          ..write('maxQty: $maxQty, ')
          ..write('active: $active, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    warehouseId,
    zoneId,
    code,
    aisle,
    rack,
    shelf,
    position,
    type,
    maxQty,
    active,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WhBin &&
          other.id == this.id &&
          other.warehouseId == this.warehouseId &&
          other.zoneId == this.zoneId &&
          other.code == this.code &&
          other.aisle == this.aisle &&
          other.rack == this.rack &&
          other.shelf == this.shelf &&
          other.position == this.position &&
          other.type == this.type &&
          other.maxQty == this.maxQty &&
          other.active == this.active &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class WhBinsCompanion extends UpdateCompanion<WhBin> {
  final Value<String> id;
  final Value<String> warehouseId;
  final Value<String?> zoneId;
  final Value<String> code;
  final Value<String?> aisle;
  final Value<String?> rack;
  final Value<String?> shelf;
  final Value<String?> position;
  final Value<String> type;
  final Value<double?> maxQty;
  final Value<bool> active;
  final Value<String?> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const WhBinsCompanion({
    this.id = const Value.absent(),
    this.warehouseId = const Value.absent(),
    this.zoneId = const Value.absent(),
    this.code = const Value.absent(),
    this.aisle = const Value.absent(),
    this.rack = const Value.absent(),
    this.shelf = const Value.absent(),
    this.position = const Value.absent(),
    this.type = const Value.absent(),
    this.maxQty = const Value.absent(),
    this.active = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WhBinsCompanion.insert({
    required String id,
    required String warehouseId,
    this.zoneId = const Value.absent(),
    required String code,
    this.aisle = const Value.absent(),
    this.rack = const Value.absent(),
    this.shelf = const Value.absent(),
    this.position = const Value.absent(),
    this.type = const Value.absent(),
    this.maxQty = const Value.absent(),
    this.active = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       warehouseId = Value(warehouseId),
       code = Value(code);
  static Insertable<WhBin> custom({
    Expression<String>? id,
    Expression<String>? warehouseId,
    Expression<String>? zoneId,
    Expression<String>? code,
    Expression<String>? aisle,
    Expression<String>? rack,
    Expression<String>? shelf,
    Expression<String>? position,
    Expression<String>? type,
    Expression<double>? maxQty,
    Expression<bool>? active,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (warehouseId != null) 'warehouse_id': warehouseId,
      if (zoneId != null) 'zone_id': zoneId,
      if (code != null) 'code': code,
      if (aisle != null) 'aisle': aisle,
      if (rack != null) 'rack': rack,
      if (shelf != null) 'shelf': shelf,
      if (position != null) 'position': position,
      if (type != null) 'type': type,
      if (maxQty != null) 'max_qty': maxQty,
      if (active != null) 'active': active,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WhBinsCompanion copyWith({
    Value<String>? id,
    Value<String>? warehouseId,
    Value<String?>? zoneId,
    Value<String>? code,
    Value<String?>? aisle,
    Value<String?>? rack,
    Value<String?>? shelf,
    Value<String?>? position,
    Value<String>? type,
    Value<double?>? maxQty,
    Value<bool>? active,
    Value<String?>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return WhBinsCompanion(
      id: id ?? this.id,
      warehouseId: warehouseId ?? this.warehouseId,
      zoneId: zoneId ?? this.zoneId,
      code: code ?? this.code,
      aisle: aisle ?? this.aisle,
      rack: rack ?? this.rack,
      shelf: shelf ?? this.shelf,
      position: position ?? this.position,
      type: type ?? this.type,
      maxQty: maxQty ?? this.maxQty,
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
    if (warehouseId.present) {
      map['warehouse_id'] = Variable<String>(warehouseId.value);
    }
    if (zoneId.present) {
      map['zone_id'] = Variable<String>(zoneId.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (aisle.present) {
      map['aisle'] = Variable<String>(aisle.value);
    }
    if (rack.present) {
      map['rack'] = Variable<String>(rack.value);
    }
    if (shelf.present) {
      map['shelf'] = Variable<String>(shelf.value);
    }
    if (position.present) {
      map['position'] = Variable<String>(position.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (maxQty.present) {
      map['max_qty'] = Variable<double>(maxQty.value);
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
    return (StringBuffer('WhBinsCompanion(')
          ..write('id: $id, ')
          ..write('warehouseId: $warehouseId, ')
          ..write('zoneId: $zoneId, ')
          ..write('code: $code, ')
          ..write('aisle: $aisle, ')
          ..write('rack: $rack, ')
          ..write('shelf: $shelf, ')
          ..write('position: $position, ')
          ..write('type: $type, ')
          ..write('maxQty: $maxQty, ')
          ..write('active: $active, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WhBinStockTable extends WhBinStock
    with TableInfo<$WhBinStockTable, WhBinStockData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WhBinStockTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _binIdMeta = const VerificationMeta('binId');
  @override
  late final GeneratedColumn<String> binId = GeneratedColumn<String>(
    'bin_id',
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
  List<GeneratedColumn> get $columns => [binId, variantId, qty, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wh_bin_stock';
  @override
  VerificationContext validateIntegrity(
    Insertable<WhBinStockData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('bin_id')) {
      context.handle(
        _binIdMeta,
        binId.isAcceptableOrUnknown(data['bin_id']!, _binIdMeta),
      );
    } else if (isInserting) {
      context.missing(_binIdMeta);
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
  Set<GeneratedColumn> get $primaryKey => {binId, variantId};
  @override
  WhBinStockData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WhBinStockData(
      binId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bin_id'],
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
  $WhBinStockTable createAlias(String alias) {
    return $WhBinStockTable(attachedDatabase, alias);
  }
}

class WhBinStockData extends DataClass implements Insertable<WhBinStockData> {
  final String binId;
  final String variantId;
  final double qty;
  final String updatedAt;
  const WhBinStockData({
    required this.binId,
    required this.variantId,
    required this.qty,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['bin_id'] = Variable<String>(binId);
    map['variant_id'] = Variable<String>(variantId);
    map['qty'] = Variable<double>(qty);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  WhBinStockCompanion toCompanion(bool nullToAbsent) {
    return WhBinStockCompanion(
      binId: Value(binId),
      variantId: Value(variantId),
      qty: Value(qty),
      updatedAt: Value(updatedAt),
    );
  }

  factory WhBinStockData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WhBinStockData(
      binId: serializer.fromJson<String>(json['binId']),
      variantId: serializer.fromJson<String>(json['variantId']),
      qty: serializer.fromJson<double>(json['qty']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'binId': serializer.toJson<String>(binId),
      'variantId': serializer.toJson<String>(variantId),
      'qty': serializer.toJson<double>(qty),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  WhBinStockData copyWith({
    String? binId,
    String? variantId,
    double? qty,
    String? updatedAt,
  }) => WhBinStockData(
    binId: binId ?? this.binId,
    variantId: variantId ?? this.variantId,
    qty: qty ?? this.qty,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WhBinStockData copyWithCompanion(WhBinStockCompanion data) {
    return WhBinStockData(
      binId: data.binId.present ? data.binId.value : this.binId,
      variantId: data.variantId.present ? data.variantId.value : this.variantId,
      qty: data.qty.present ? data.qty.value : this.qty,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WhBinStockData(')
          ..write('binId: $binId, ')
          ..write('variantId: $variantId, ')
          ..write('qty: $qty, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(binId, variantId, qty, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WhBinStockData &&
          other.binId == this.binId &&
          other.variantId == this.variantId &&
          other.qty == this.qty &&
          other.updatedAt == this.updatedAt);
}

class WhBinStockCompanion extends UpdateCompanion<WhBinStockData> {
  final Value<String> binId;
  final Value<String> variantId;
  final Value<double> qty;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const WhBinStockCompanion({
    this.binId = const Value.absent(),
    this.variantId = const Value.absent(),
    this.qty = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WhBinStockCompanion.insert({
    required String binId,
    required String variantId,
    required double qty,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : binId = Value(binId),
       variantId = Value(variantId),
       qty = Value(qty),
       updatedAt = Value(updatedAt);
  static Insertable<WhBinStockData> custom({
    Expression<String>? binId,
    Expression<String>? variantId,
    Expression<double>? qty,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (binId != null) 'bin_id': binId,
      if (variantId != null) 'variant_id': variantId,
      if (qty != null) 'qty': qty,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WhBinStockCompanion copyWith({
    Value<String>? binId,
    Value<String>? variantId,
    Value<double>? qty,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return WhBinStockCompanion(
      binId: binId ?? this.binId,
      variantId: variantId ?? this.variantId,
      qty: qty ?? this.qty,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (binId.present) {
      map['bin_id'] = Variable<String>(binId.value);
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
    return (StringBuffer('WhBinStockCompanion(')
          ..write('binId: $binId, ')
          ..write('variantId: $variantId, ')
          ..write('qty: $qty, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WhStockTable extends WhStock with TableInfo<$WhStockTable, WhStockData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WhStockTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _avgCostMeta = const VerificationMeta(
    'avgCost',
  );
  @override
  late final GeneratedColumn<int> avgCost = GeneratedColumn<int>(
    'avg_cost',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  List<GeneratedColumn> get $columns => [
    locationId,
    variantId,
    qty,
    avgCost,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wh_stock';
  @override
  VerificationContext validateIntegrity(
    Insertable<WhStockData> instance, {
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
    if (data.containsKey('avg_cost')) {
      context.handle(
        _avgCostMeta,
        avgCost.isAcceptableOrUnknown(data['avg_cost']!, _avgCostMeta),
      );
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
  WhStockData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WhStockData(
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
      avgCost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}avg_cost'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $WhStockTable createAlias(String alias) {
    return $WhStockTable(attachedDatabase, alias);
  }
}

class WhStockData extends DataClass implements Insertable<WhStockData> {
  final String locationId;
  final String variantId;
  final double qty;
  final int? avgCost;
  final String updatedAt;
  const WhStockData({
    required this.locationId,
    required this.variantId,
    required this.qty,
    this.avgCost,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['location_id'] = Variable<String>(locationId);
    map['variant_id'] = Variable<String>(variantId);
    map['qty'] = Variable<double>(qty);
    if (!nullToAbsent || avgCost != null) {
      map['avg_cost'] = Variable<int>(avgCost);
    }
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  WhStockCompanion toCompanion(bool nullToAbsent) {
    return WhStockCompanion(
      locationId: Value(locationId),
      variantId: Value(variantId),
      qty: Value(qty),
      avgCost: avgCost == null && nullToAbsent
          ? const Value.absent()
          : Value(avgCost),
      updatedAt: Value(updatedAt),
    );
  }

  factory WhStockData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WhStockData(
      locationId: serializer.fromJson<String>(json['locationId']),
      variantId: serializer.fromJson<String>(json['variantId']),
      qty: serializer.fromJson<double>(json['qty']),
      avgCost: serializer.fromJson<int?>(json['avgCost']),
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
      'avgCost': serializer.toJson<int?>(avgCost),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  WhStockData copyWith({
    String? locationId,
    String? variantId,
    double? qty,
    Value<int?> avgCost = const Value.absent(),
    String? updatedAt,
  }) => WhStockData(
    locationId: locationId ?? this.locationId,
    variantId: variantId ?? this.variantId,
    qty: qty ?? this.qty,
    avgCost: avgCost.present ? avgCost.value : this.avgCost,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WhStockData copyWithCompanion(WhStockCompanion data) {
    return WhStockData(
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
      variantId: data.variantId.present ? data.variantId.value : this.variantId,
      qty: data.qty.present ? data.qty.value : this.qty,
      avgCost: data.avgCost.present ? data.avgCost.value : this.avgCost,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WhStockData(')
          ..write('locationId: $locationId, ')
          ..write('variantId: $variantId, ')
          ..write('qty: $qty, ')
          ..write('avgCost: $avgCost, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(locationId, variantId, qty, avgCost, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WhStockData &&
          other.locationId == this.locationId &&
          other.variantId == this.variantId &&
          other.qty == this.qty &&
          other.avgCost == this.avgCost &&
          other.updatedAt == this.updatedAt);
}

class WhStockCompanion extends UpdateCompanion<WhStockData> {
  final Value<String> locationId;
  final Value<String> variantId;
  final Value<double> qty;
  final Value<int?> avgCost;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const WhStockCompanion({
    this.locationId = const Value.absent(),
    this.variantId = const Value.absent(),
    this.qty = const Value.absent(),
    this.avgCost = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WhStockCompanion.insert({
    required String locationId,
    required String variantId,
    required double qty,
    this.avgCost = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : locationId = Value(locationId),
       variantId = Value(variantId),
       qty = Value(qty),
       updatedAt = Value(updatedAt);
  static Insertable<WhStockData> custom({
    Expression<String>? locationId,
    Expression<String>? variantId,
    Expression<double>? qty,
    Expression<int>? avgCost,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (locationId != null) 'location_id': locationId,
      if (variantId != null) 'variant_id': variantId,
      if (qty != null) 'qty': qty,
      if (avgCost != null) 'avg_cost': avgCost,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WhStockCompanion copyWith({
    Value<String>? locationId,
    Value<String>? variantId,
    Value<double>? qty,
    Value<int?>? avgCost,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return WhStockCompanion(
      locationId: locationId ?? this.locationId,
      variantId: variantId ?? this.variantId,
      qty: qty ?? this.qty,
      avgCost: avgCost ?? this.avgCost,
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
    if (avgCost.present) {
      map['avg_cost'] = Variable<int>(avgCost.value);
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
    return (StringBuffer('WhStockCompanion(')
          ..write('locationId: $locationId, ')
          ..write('variantId: $variantId, ')
          ..write('qty: $qty, ')
          ..write('avgCost: $avgCost, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SuppliersTable extends Suppliers
    with TableInfo<$SuppliersTable, Supplier> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SuppliersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _contactNameMeta = const VerificationMeta(
    'contactName',
  );
  @override
  late final GeneratedColumn<String> contactName = GeneratedColumn<String>(
    'contact_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
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
    name,
    contactName,
    phone,
    email,
    notes,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'suppliers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Supplier> instance, {
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
    if (data.containsKey('contact_name')) {
      context.handle(
        _contactNameMeta,
        contactName.isAcceptableOrUnknown(
          data['contact_name']!,
          _contactNameMeta,
        ),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
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
  Supplier map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Supplier(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      contactName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_name'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
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
  $SuppliersTable createAlias(String alias) {
    return $SuppliersTable(attachedDatabase, alias);
  }
}

class Supplier extends DataClass implements Insertable<Supplier> {
  final String id;
  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? notes;
  final String? updatedAt;
  final String? deletedAt;
  const Supplier({
    required this.id,
    required this.name,
    this.contactName,
    this.phone,
    this.email,
    this.notes,
    this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || contactName != null) {
      map['contact_name'] = Variable<String>(contactName);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  SuppliersCompanion toCompanion(bool nullToAbsent) {
    return SuppliersCompanion(
      id: Value(id),
      name: Value(name),
      contactName: contactName == null && nullToAbsent
          ? const Value.absent()
          : Value(contactName),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Supplier.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Supplier(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      contactName: serializer.fromJson<String?>(json['contactName']),
      phone: serializer.fromJson<String?>(json['phone']),
      email: serializer.fromJson<String?>(json['email']),
      notes: serializer.fromJson<String?>(json['notes']),
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
      'contactName': serializer.toJson<String?>(contactName),
      'phone': serializer.toJson<String?>(phone),
      'email': serializer.toJson<String?>(email),
      'notes': serializer.toJson<String?>(notes),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  Supplier copyWith({
    String? id,
    String? name,
    Value<String?> contactName = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
  }) => Supplier(
    id: id ?? this.id,
    name: name ?? this.name,
    contactName: contactName.present ? contactName.value : this.contactName,
    phone: phone.present ? phone.value : this.phone,
    email: email.present ? email.value : this.email,
    notes: notes.present ? notes.value : this.notes,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Supplier copyWithCompanion(SuppliersCompanion data) {
    return Supplier(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      contactName: data.contactName.present
          ? data.contactName.value
          : this.contactName,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      notes: data.notes.present ? data.notes.value : this.notes,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Supplier(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('contactName: $contactName, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    contactName,
    phone,
    email,
    notes,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Supplier &&
          other.id == this.id &&
          other.name == this.name &&
          other.contactName == this.contactName &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.notes == this.notes &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class SuppliersCompanion extends UpdateCompanion<Supplier> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> contactName;
  final Value<String?> phone;
  final Value<String?> email;
  final Value<String?> notes;
  final Value<String?> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const SuppliersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.contactName = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.notes = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SuppliersCompanion.insert({
    required String id,
    required String name,
    this.contactName = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.notes = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Supplier> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? contactName,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<String>? notes,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (contactName != null) 'contact_name': contactName,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (notes != null) 'notes': notes,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SuppliersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? contactName,
    Value<String?>? phone,
    Value<String?>? email,
    Value<String?>? notes,
    Value<String?>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return SuppliersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
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
    if (contactName.present) {
      map['contact_name'] = Variable<String>(contactName.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
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
    return (StringBuffer('SuppliersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('contactName: $contactName, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PurchaseOrdersTable extends PurchaseOrders
    with TableInfo<$PurchaseOrdersTable, PurchaseOrder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PurchaseOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _poNoMeta = const VerificationMeta('poNo');
  @override
  late final GeneratedColumn<String> poNo = GeneratedColumn<String>(
    'po_no',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _warehouseIdMeta = const VerificationMeta(
    'warehouseId',
  );
  @override
  late final GeneratedColumn<String> warehouseId = GeneratedColumn<String>(
    'warehouse_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _supplierIdMeta = const VerificationMeta(
    'supplierId',
  );
  @override
  late final GeneratedColumn<String> supplierId = GeneratedColumn<String>(
    'supplier_id',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expectedAtMeta = const VerificationMeta(
    'expectedAt',
  );
  @override
  late final GeneratedColumn<String> expectedAt = GeneratedColumn<String>(
    'expected_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    poNo,
    warehouseId,
    supplierId,
    status,
    expectedAt,
    notes,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'purchase_orders';
  @override
  VerificationContext validateIntegrity(
    Insertable<PurchaseOrder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('po_no')) {
      context.handle(
        _poNoMeta,
        poNo.isAcceptableOrUnknown(data['po_no']!, _poNoMeta),
      );
    } else if (isInserting) {
      context.missing(_poNoMeta);
    }
    if (data.containsKey('warehouse_id')) {
      context.handle(
        _warehouseIdMeta,
        warehouseId.isAcceptableOrUnknown(
          data['warehouse_id']!,
          _warehouseIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_warehouseIdMeta);
    }
    if (data.containsKey('supplier_id')) {
      context.handle(
        _supplierIdMeta,
        supplierId.isAcceptableOrUnknown(data['supplier_id']!, _supplierIdMeta),
      );
    } else if (isInserting) {
      context.missing(_supplierIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('expected_at')) {
      context.handle(
        _expectedAtMeta,
        expectedAt.isAcceptableOrUnknown(data['expected_at']!, _expectedAtMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PurchaseOrder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PurchaseOrder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      poNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}po_no'],
      )!,
      warehouseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}warehouse_id'],
      )!,
      supplierId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supplier_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      expectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expected_at'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PurchaseOrdersTable createAlias(String alias) {
    return $PurchaseOrdersTable(attachedDatabase, alias);
  }
}

class PurchaseOrder extends DataClass implements Insertable<PurchaseOrder> {
  final String id;
  final String poNo;
  final String warehouseId;
  final String supplierId;
  final String status;
  final String? expectedAt;
  final String? notes;
  final String updatedAt;
  const PurchaseOrder({
    required this.id,
    required this.poNo,
    required this.warehouseId,
    required this.supplierId,
    required this.status,
    this.expectedAt,
    this.notes,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['po_no'] = Variable<String>(poNo);
    map['warehouse_id'] = Variable<String>(warehouseId);
    map['supplier_id'] = Variable<String>(supplierId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || expectedAt != null) {
      map['expected_at'] = Variable<String>(expectedAt);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  PurchaseOrdersCompanion toCompanion(bool nullToAbsent) {
    return PurchaseOrdersCompanion(
      id: Value(id),
      poNo: Value(poNo),
      warehouseId: Value(warehouseId),
      supplierId: Value(supplierId),
      status: Value(status),
      expectedAt: expectedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expectedAt),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      updatedAt: Value(updatedAt),
    );
  }

  factory PurchaseOrder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PurchaseOrder(
      id: serializer.fromJson<String>(json['id']),
      poNo: serializer.fromJson<String>(json['poNo']),
      warehouseId: serializer.fromJson<String>(json['warehouseId']),
      supplierId: serializer.fromJson<String>(json['supplierId']),
      status: serializer.fromJson<String>(json['status']),
      expectedAt: serializer.fromJson<String?>(json['expectedAt']),
      notes: serializer.fromJson<String?>(json['notes']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'poNo': serializer.toJson<String>(poNo),
      'warehouseId': serializer.toJson<String>(warehouseId),
      'supplierId': serializer.toJson<String>(supplierId),
      'status': serializer.toJson<String>(status),
      'expectedAt': serializer.toJson<String?>(expectedAt),
      'notes': serializer.toJson<String?>(notes),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  PurchaseOrder copyWith({
    String? id,
    String? poNo,
    String? warehouseId,
    String? supplierId,
    String? status,
    Value<String?> expectedAt = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? updatedAt,
  }) => PurchaseOrder(
    id: id ?? this.id,
    poNo: poNo ?? this.poNo,
    warehouseId: warehouseId ?? this.warehouseId,
    supplierId: supplierId ?? this.supplierId,
    status: status ?? this.status,
    expectedAt: expectedAt.present ? expectedAt.value : this.expectedAt,
    notes: notes.present ? notes.value : this.notes,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PurchaseOrder copyWithCompanion(PurchaseOrdersCompanion data) {
    return PurchaseOrder(
      id: data.id.present ? data.id.value : this.id,
      poNo: data.poNo.present ? data.poNo.value : this.poNo,
      warehouseId: data.warehouseId.present
          ? data.warehouseId.value
          : this.warehouseId,
      supplierId: data.supplierId.present
          ? data.supplierId.value
          : this.supplierId,
      status: data.status.present ? data.status.value : this.status,
      expectedAt: data.expectedAt.present
          ? data.expectedAt.value
          : this.expectedAt,
      notes: data.notes.present ? data.notes.value : this.notes,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PurchaseOrder(')
          ..write('id: $id, ')
          ..write('poNo: $poNo, ')
          ..write('warehouseId: $warehouseId, ')
          ..write('supplierId: $supplierId, ')
          ..write('status: $status, ')
          ..write('expectedAt: $expectedAt, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    poNo,
    warehouseId,
    supplierId,
    status,
    expectedAt,
    notes,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PurchaseOrder &&
          other.id == this.id &&
          other.poNo == this.poNo &&
          other.warehouseId == this.warehouseId &&
          other.supplierId == this.supplierId &&
          other.status == this.status &&
          other.expectedAt == this.expectedAt &&
          other.notes == this.notes &&
          other.updatedAt == this.updatedAt);
}

class PurchaseOrdersCompanion extends UpdateCompanion<PurchaseOrder> {
  final Value<String> id;
  final Value<String> poNo;
  final Value<String> warehouseId;
  final Value<String> supplierId;
  final Value<String> status;
  final Value<String?> expectedAt;
  final Value<String?> notes;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const PurchaseOrdersCompanion({
    this.id = const Value.absent(),
    this.poNo = const Value.absent(),
    this.warehouseId = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.status = const Value.absent(),
    this.expectedAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PurchaseOrdersCompanion.insert({
    required String id,
    required String poNo,
    required String warehouseId,
    required String supplierId,
    required String status,
    this.expectedAt = const Value.absent(),
    this.notes = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       poNo = Value(poNo),
       warehouseId = Value(warehouseId),
       supplierId = Value(supplierId),
       status = Value(status),
       updatedAt = Value(updatedAt);
  static Insertable<PurchaseOrder> custom({
    Expression<String>? id,
    Expression<String>? poNo,
    Expression<String>? warehouseId,
    Expression<String>? supplierId,
    Expression<String>? status,
    Expression<String>? expectedAt,
    Expression<String>? notes,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (poNo != null) 'po_no': poNo,
      if (warehouseId != null) 'warehouse_id': warehouseId,
      if (supplierId != null) 'supplier_id': supplierId,
      if (status != null) 'status': status,
      if (expectedAt != null) 'expected_at': expectedAt,
      if (notes != null) 'notes': notes,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PurchaseOrdersCompanion copyWith({
    Value<String>? id,
    Value<String>? poNo,
    Value<String>? warehouseId,
    Value<String>? supplierId,
    Value<String>? status,
    Value<String?>? expectedAt,
    Value<String?>? notes,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return PurchaseOrdersCompanion(
      id: id ?? this.id,
      poNo: poNo ?? this.poNo,
      warehouseId: warehouseId ?? this.warehouseId,
      supplierId: supplierId ?? this.supplierId,
      status: status ?? this.status,
      expectedAt: expectedAt ?? this.expectedAt,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (poNo.present) {
      map['po_no'] = Variable<String>(poNo.value);
    }
    if (warehouseId.present) {
      map['warehouse_id'] = Variable<String>(warehouseId.value);
    }
    if (supplierId.present) {
      map['supplier_id'] = Variable<String>(supplierId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (expectedAt.present) {
      map['expected_at'] = Variable<String>(expectedAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
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
    return (StringBuffer('PurchaseOrdersCompanion(')
          ..write('id: $id, ')
          ..write('poNo: $poNo, ')
          ..write('warehouseId: $warehouseId, ')
          ..write('supplierId: $supplierId, ')
          ..write('status: $status, ')
          ..write('expectedAt: $expectedAt, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PoItemsTable extends PoItems with TableInfo<$PoItemsTable, PoItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PoItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _poIdMeta = const VerificationMeta('poId');
  @override
  late final GeneratedColumn<String> poId = GeneratedColumn<String>(
    'po_id',
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
  static const VerificationMeta _qtyOrderedMeta = const VerificationMeta(
    'qtyOrdered',
  );
  @override
  late final GeneratedColumn<double> qtyOrdered = GeneratedColumn<double>(
    'qty_ordered',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qtyReceivedMeta = const VerificationMeta(
    'qtyReceived',
  );
  @override
  late final GeneratedColumn<double> qtyReceived = GeneratedColumn<double>(
    'qty_received',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitCostMeta = const VerificationMeta(
    'unitCost',
  );
  @override
  late final GeneratedColumn<int> unitCost = GeneratedColumn<int>(
    'unit_cost',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    poId,
    variantId,
    qtyOrdered,
    qtyReceived,
    unitCost,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'po_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<PoItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('po_id')) {
      context.handle(
        _poIdMeta,
        poId.isAcceptableOrUnknown(data['po_id']!, _poIdMeta),
      );
    } else if (isInserting) {
      context.missing(_poIdMeta);
    }
    if (data.containsKey('variant_id')) {
      context.handle(
        _variantIdMeta,
        variantId.isAcceptableOrUnknown(data['variant_id']!, _variantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_variantIdMeta);
    }
    if (data.containsKey('qty_ordered')) {
      context.handle(
        _qtyOrderedMeta,
        qtyOrdered.isAcceptableOrUnknown(data['qty_ordered']!, _qtyOrderedMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyOrderedMeta);
    }
    if (data.containsKey('qty_received')) {
      context.handle(
        _qtyReceivedMeta,
        qtyReceived.isAcceptableOrUnknown(
          data['qty_received']!,
          _qtyReceivedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_qtyReceivedMeta);
    }
    if (data.containsKey('unit_cost')) {
      context.handle(
        _unitCostMeta,
        unitCost.isAcceptableOrUnknown(data['unit_cost']!, _unitCostMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PoItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PoItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      poId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}po_id'],
      )!,
      variantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variant_id'],
      )!,
      qtyOrdered: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}qty_ordered'],
      )!,
      qtyReceived: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}qty_received'],
      )!,
      unitCost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_cost'],
      ),
    );
  }

  @override
  $PoItemsTable createAlias(String alias) {
    return $PoItemsTable(attachedDatabase, alias);
  }
}

class PoItem extends DataClass implements Insertable<PoItem> {
  final String id;
  final String poId;
  final String variantId;
  final double qtyOrdered;
  final double qtyReceived;
  final int? unitCost;
  const PoItem({
    required this.id,
    required this.poId,
    required this.variantId,
    required this.qtyOrdered,
    required this.qtyReceived,
    this.unitCost,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['po_id'] = Variable<String>(poId);
    map['variant_id'] = Variable<String>(variantId);
    map['qty_ordered'] = Variable<double>(qtyOrdered);
    map['qty_received'] = Variable<double>(qtyReceived);
    if (!nullToAbsent || unitCost != null) {
      map['unit_cost'] = Variable<int>(unitCost);
    }
    return map;
  }

  PoItemsCompanion toCompanion(bool nullToAbsent) {
    return PoItemsCompanion(
      id: Value(id),
      poId: Value(poId),
      variantId: Value(variantId),
      qtyOrdered: Value(qtyOrdered),
      qtyReceived: Value(qtyReceived),
      unitCost: unitCost == null && nullToAbsent
          ? const Value.absent()
          : Value(unitCost),
    );
  }

  factory PoItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PoItem(
      id: serializer.fromJson<String>(json['id']),
      poId: serializer.fromJson<String>(json['poId']),
      variantId: serializer.fromJson<String>(json['variantId']),
      qtyOrdered: serializer.fromJson<double>(json['qtyOrdered']),
      qtyReceived: serializer.fromJson<double>(json['qtyReceived']),
      unitCost: serializer.fromJson<int?>(json['unitCost']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'poId': serializer.toJson<String>(poId),
      'variantId': serializer.toJson<String>(variantId),
      'qtyOrdered': serializer.toJson<double>(qtyOrdered),
      'qtyReceived': serializer.toJson<double>(qtyReceived),
      'unitCost': serializer.toJson<int?>(unitCost),
    };
  }

  PoItem copyWith({
    String? id,
    String? poId,
    String? variantId,
    double? qtyOrdered,
    double? qtyReceived,
    Value<int?> unitCost = const Value.absent(),
  }) => PoItem(
    id: id ?? this.id,
    poId: poId ?? this.poId,
    variantId: variantId ?? this.variantId,
    qtyOrdered: qtyOrdered ?? this.qtyOrdered,
    qtyReceived: qtyReceived ?? this.qtyReceived,
    unitCost: unitCost.present ? unitCost.value : this.unitCost,
  );
  PoItem copyWithCompanion(PoItemsCompanion data) {
    return PoItem(
      id: data.id.present ? data.id.value : this.id,
      poId: data.poId.present ? data.poId.value : this.poId,
      variantId: data.variantId.present ? data.variantId.value : this.variantId,
      qtyOrdered: data.qtyOrdered.present
          ? data.qtyOrdered.value
          : this.qtyOrdered,
      qtyReceived: data.qtyReceived.present
          ? data.qtyReceived.value
          : this.qtyReceived,
      unitCost: data.unitCost.present ? data.unitCost.value : this.unitCost,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PoItem(')
          ..write('id: $id, ')
          ..write('poId: $poId, ')
          ..write('variantId: $variantId, ')
          ..write('qtyOrdered: $qtyOrdered, ')
          ..write('qtyReceived: $qtyReceived, ')
          ..write('unitCost: $unitCost')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, poId, variantId, qtyOrdered, qtyReceived, unitCost);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PoItem &&
          other.id == this.id &&
          other.poId == this.poId &&
          other.variantId == this.variantId &&
          other.qtyOrdered == this.qtyOrdered &&
          other.qtyReceived == this.qtyReceived &&
          other.unitCost == this.unitCost);
}

class PoItemsCompanion extends UpdateCompanion<PoItem> {
  final Value<String> id;
  final Value<String> poId;
  final Value<String> variantId;
  final Value<double> qtyOrdered;
  final Value<double> qtyReceived;
  final Value<int?> unitCost;
  final Value<int> rowid;
  const PoItemsCompanion({
    this.id = const Value.absent(),
    this.poId = const Value.absent(),
    this.variantId = const Value.absent(),
    this.qtyOrdered = const Value.absent(),
    this.qtyReceived = const Value.absent(),
    this.unitCost = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PoItemsCompanion.insert({
    required String id,
    required String poId,
    required String variantId,
    required double qtyOrdered,
    required double qtyReceived,
    this.unitCost = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       poId = Value(poId),
       variantId = Value(variantId),
       qtyOrdered = Value(qtyOrdered),
       qtyReceived = Value(qtyReceived);
  static Insertable<PoItem> custom({
    Expression<String>? id,
    Expression<String>? poId,
    Expression<String>? variantId,
    Expression<double>? qtyOrdered,
    Expression<double>? qtyReceived,
    Expression<int>? unitCost,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (poId != null) 'po_id': poId,
      if (variantId != null) 'variant_id': variantId,
      if (qtyOrdered != null) 'qty_ordered': qtyOrdered,
      if (qtyReceived != null) 'qty_received': qtyReceived,
      if (unitCost != null) 'unit_cost': unitCost,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PoItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? poId,
    Value<String>? variantId,
    Value<double>? qtyOrdered,
    Value<double>? qtyReceived,
    Value<int?>? unitCost,
    Value<int>? rowid,
  }) {
    return PoItemsCompanion(
      id: id ?? this.id,
      poId: poId ?? this.poId,
      variantId: variantId ?? this.variantId,
      qtyOrdered: qtyOrdered ?? this.qtyOrdered,
      qtyReceived: qtyReceived ?? this.qtyReceived,
      unitCost: unitCost ?? this.unitCost,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (poId.present) {
      map['po_id'] = Variable<String>(poId.value);
    }
    if (variantId.present) {
      map['variant_id'] = Variable<String>(variantId.value);
    }
    if (qtyOrdered.present) {
      map['qty_ordered'] = Variable<double>(qtyOrdered.value);
    }
    if (qtyReceived.present) {
      map['qty_received'] = Variable<double>(qtyReceived.value);
    }
    if (unitCost.present) {
      map['unit_cost'] = Variable<int>(unitCost.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PoItemsCompanion(')
          ..write('id: $id, ')
          ..write('poId: $poId, ')
          ..write('variantId: $variantId, ')
          ..write('qtyOrdered: $qtyOrdered, ')
          ..write('qtyReceived: $qtyReceived, ')
          ..write('unitCost: $unitCost, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WhReceiptsTable extends WhReceipts
    with TableInfo<$WhReceiptsTable, WhReceipt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WhReceiptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _opIdMeta = const VerificationMeta('opId');
  @override
  late final GeneratedColumn<String> opId = GeneratedColumn<String>(
    'op_id',
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
  static const VerificationMeta _warehouseIdMeta = const VerificationMeta(
    'warehouseId',
  );
  @override
  late final GeneratedColumn<String> warehouseId = GeneratedColumn<String>(
    'warehouse_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _poIdMeta = const VerificationMeta('poId');
  @override
  late final GeneratedColumn<String> poId = GeneratedColumn<String>(
    'po_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _poNoMeta = const VerificationMeta('poNo');
  @override
  late final GeneratedColumn<String> poNo = GeneratedColumn<String>(
    'po_no',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _supplierIdMeta = const VerificationMeta(
    'supplierId',
  );
  @override
  late final GeneratedColumn<String> supplierId = GeneratedColumn<String>(
    'supplier_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deliveryRefMeta = const VerificationMeta(
    'deliveryRef',
  );
  @override
  late final GeneratedColumn<String> deliveryRef = GeneratedColumn<String>(
    'delivery_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _grnNoMeta = const VerificationMeta('grnNo');
  @override
  late final GeneratedColumn<String> grnNo = GeneratedColumn<String>(
    'grn_no',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _settledMeta = const VerificationMeta(
    'settled',
  );
  @override
  late final GeneratedColumn<bool> settled = GeneratedColumn<bool>(
    'settled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("settled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    opId,
    kind,
    warehouseId,
    poId,
    poNo,
    supplierId,
    deliveryRef,
    notes,
    createdAt,
    grnNo,
    confirmedAfter,
    settled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wh_receipts';
  @override
  VerificationContext validateIntegrity(
    Insertable<WhReceipt> instance, {
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
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('warehouse_id')) {
      context.handle(
        _warehouseIdMeta,
        warehouseId.isAcceptableOrUnknown(
          data['warehouse_id']!,
          _warehouseIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_warehouseIdMeta);
    }
    if (data.containsKey('po_id')) {
      context.handle(
        _poIdMeta,
        poId.isAcceptableOrUnknown(data['po_id']!, _poIdMeta),
      );
    }
    if (data.containsKey('po_no')) {
      context.handle(
        _poNoMeta,
        poNo.isAcceptableOrUnknown(data['po_no']!, _poNoMeta),
      );
    }
    if (data.containsKey('supplier_id')) {
      context.handle(
        _supplierIdMeta,
        supplierId.isAcceptableOrUnknown(data['supplier_id']!, _supplierIdMeta),
      );
    }
    if (data.containsKey('delivery_ref')) {
      context.handle(
        _deliveryRefMeta,
        deliveryRef.isAcceptableOrUnknown(
          data['delivery_ref']!,
          _deliveryRefMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
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
    if (data.containsKey('grn_no')) {
      context.handle(
        _grnNoMeta,
        grnNo.isAcceptableOrUnknown(data['grn_no']!, _grnNoMeta),
      );
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
    if (data.containsKey('settled')) {
      context.handle(
        _settledMeta,
        settled.isAcceptableOrUnknown(data['settled']!, _settledMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {opId};
  @override
  WhReceipt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WhReceipt(
      opId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      warehouseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}warehouse_id'],
      )!,
      poId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}po_id'],
      ),
      poNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}po_no'],
      ),
      supplierId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supplier_id'],
      ),
      deliveryRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}delivery_ref'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      grnNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grn_no'],
      ),
      confirmedAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confirmed_after'],
      ),
      settled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}settled'],
      )!,
    );
  }

  @override
  $WhReceiptsTable createAlias(String alias) {
    return $WhReceiptsTable(attachedDatabase, alias);
  }
}

class WhReceipt extends DataClass implements Insertable<WhReceipt> {
  final String opId;

  /// `po` or `walkin`.
  final String kind;
  final String warehouseId;
  final String? poId;

  /// Kept with the receipt: the order itself is forgotten once it finishes.
  final String? poNo;
  final String? supplierId;
  final String? deliveryRef;
  final String? notes;
  final String createdAt;

  /// The server's receipt number, once it answered.
  final String? grnNo;

  /// The server's own time of the receipt (set when it answered). The effect stays until a pull has passed this time.
  final String? confirmedAfter;

  /// The server's copy has caught up: the effect is no longer counted on top of it.
  final bool settled;
  const WhReceipt({
    required this.opId,
    required this.kind,
    required this.warehouseId,
    this.poId,
    this.poNo,
    this.supplierId,
    this.deliveryRef,
    this.notes,
    required this.createdAt,
    this.grnNo,
    this.confirmedAfter,
    required this.settled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['op_id'] = Variable<String>(opId);
    map['kind'] = Variable<String>(kind);
    map['warehouse_id'] = Variable<String>(warehouseId);
    if (!nullToAbsent || poId != null) {
      map['po_id'] = Variable<String>(poId);
    }
    if (!nullToAbsent || poNo != null) {
      map['po_no'] = Variable<String>(poNo);
    }
    if (!nullToAbsent || supplierId != null) {
      map['supplier_id'] = Variable<String>(supplierId);
    }
    if (!nullToAbsent || deliveryRef != null) {
      map['delivery_ref'] = Variable<String>(deliveryRef);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<String>(createdAt);
    if (!nullToAbsent || grnNo != null) {
      map['grn_no'] = Variable<String>(grnNo);
    }
    if (!nullToAbsent || confirmedAfter != null) {
      map['confirmed_after'] = Variable<String>(confirmedAfter);
    }
    map['settled'] = Variable<bool>(settled);
    return map;
  }

  WhReceiptsCompanion toCompanion(bool nullToAbsent) {
    return WhReceiptsCompanion(
      opId: Value(opId),
      kind: Value(kind),
      warehouseId: Value(warehouseId),
      poId: poId == null && nullToAbsent ? const Value.absent() : Value(poId),
      poNo: poNo == null && nullToAbsent ? const Value.absent() : Value(poNo),
      supplierId: supplierId == null && nullToAbsent
          ? const Value.absent()
          : Value(supplierId),
      deliveryRef: deliveryRef == null && nullToAbsent
          ? const Value.absent()
          : Value(deliveryRef),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      grnNo: grnNo == null && nullToAbsent
          ? const Value.absent()
          : Value(grnNo),
      confirmedAfter: confirmedAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(confirmedAfter),
      settled: Value(settled),
    );
  }

  factory WhReceipt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WhReceipt(
      opId: serializer.fromJson<String>(json['opId']),
      kind: serializer.fromJson<String>(json['kind']),
      warehouseId: serializer.fromJson<String>(json['warehouseId']),
      poId: serializer.fromJson<String?>(json['poId']),
      poNo: serializer.fromJson<String?>(json['poNo']),
      supplierId: serializer.fromJson<String?>(json['supplierId']),
      deliveryRef: serializer.fromJson<String?>(json['deliveryRef']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      grnNo: serializer.fromJson<String?>(json['grnNo']),
      confirmedAfter: serializer.fromJson<String?>(json['confirmedAfter']),
      settled: serializer.fromJson<bool>(json['settled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'opId': serializer.toJson<String>(opId),
      'kind': serializer.toJson<String>(kind),
      'warehouseId': serializer.toJson<String>(warehouseId),
      'poId': serializer.toJson<String?>(poId),
      'poNo': serializer.toJson<String?>(poNo),
      'supplierId': serializer.toJson<String?>(supplierId),
      'deliveryRef': serializer.toJson<String?>(deliveryRef),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<String>(createdAt),
      'grnNo': serializer.toJson<String?>(grnNo),
      'confirmedAfter': serializer.toJson<String?>(confirmedAfter),
      'settled': serializer.toJson<bool>(settled),
    };
  }

  WhReceipt copyWith({
    String? opId,
    String? kind,
    String? warehouseId,
    Value<String?> poId = const Value.absent(),
    Value<String?> poNo = const Value.absent(),
    Value<String?> supplierId = const Value.absent(),
    Value<String?> deliveryRef = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? createdAt,
    Value<String?> grnNo = const Value.absent(),
    Value<String?> confirmedAfter = const Value.absent(),
    bool? settled,
  }) => WhReceipt(
    opId: opId ?? this.opId,
    kind: kind ?? this.kind,
    warehouseId: warehouseId ?? this.warehouseId,
    poId: poId.present ? poId.value : this.poId,
    poNo: poNo.present ? poNo.value : this.poNo,
    supplierId: supplierId.present ? supplierId.value : this.supplierId,
    deliveryRef: deliveryRef.present ? deliveryRef.value : this.deliveryRef,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    grnNo: grnNo.present ? grnNo.value : this.grnNo,
    confirmedAfter: confirmedAfter.present
        ? confirmedAfter.value
        : this.confirmedAfter,
    settled: settled ?? this.settled,
  );
  WhReceipt copyWithCompanion(WhReceiptsCompanion data) {
    return WhReceipt(
      opId: data.opId.present ? data.opId.value : this.opId,
      kind: data.kind.present ? data.kind.value : this.kind,
      warehouseId: data.warehouseId.present
          ? data.warehouseId.value
          : this.warehouseId,
      poId: data.poId.present ? data.poId.value : this.poId,
      poNo: data.poNo.present ? data.poNo.value : this.poNo,
      supplierId: data.supplierId.present
          ? data.supplierId.value
          : this.supplierId,
      deliveryRef: data.deliveryRef.present
          ? data.deliveryRef.value
          : this.deliveryRef,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      grnNo: data.grnNo.present ? data.grnNo.value : this.grnNo,
      confirmedAfter: data.confirmedAfter.present
          ? data.confirmedAfter.value
          : this.confirmedAfter,
      settled: data.settled.present ? data.settled.value : this.settled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WhReceipt(')
          ..write('opId: $opId, ')
          ..write('kind: $kind, ')
          ..write('warehouseId: $warehouseId, ')
          ..write('poId: $poId, ')
          ..write('poNo: $poNo, ')
          ..write('supplierId: $supplierId, ')
          ..write('deliveryRef: $deliveryRef, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('grnNo: $grnNo, ')
          ..write('confirmedAfter: $confirmedAfter, ')
          ..write('settled: $settled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    opId,
    kind,
    warehouseId,
    poId,
    poNo,
    supplierId,
    deliveryRef,
    notes,
    createdAt,
    grnNo,
    confirmedAfter,
    settled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WhReceipt &&
          other.opId == this.opId &&
          other.kind == this.kind &&
          other.warehouseId == this.warehouseId &&
          other.poId == this.poId &&
          other.poNo == this.poNo &&
          other.supplierId == this.supplierId &&
          other.deliveryRef == this.deliveryRef &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.grnNo == this.grnNo &&
          other.confirmedAfter == this.confirmedAfter &&
          other.settled == this.settled);
}

class WhReceiptsCompanion extends UpdateCompanion<WhReceipt> {
  final Value<String> opId;
  final Value<String> kind;
  final Value<String> warehouseId;
  final Value<String?> poId;
  final Value<String?> poNo;
  final Value<String?> supplierId;
  final Value<String?> deliveryRef;
  final Value<String?> notes;
  final Value<String> createdAt;
  final Value<String?> grnNo;
  final Value<String?> confirmedAfter;
  final Value<bool> settled;
  final Value<int> rowid;
  const WhReceiptsCompanion({
    this.opId = const Value.absent(),
    this.kind = const Value.absent(),
    this.warehouseId = const Value.absent(),
    this.poId = const Value.absent(),
    this.poNo = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.deliveryRef = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.grnNo = const Value.absent(),
    this.confirmedAfter = const Value.absent(),
    this.settled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WhReceiptsCompanion.insert({
    required String opId,
    required String kind,
    required String warehouseId,
    this.poId = const Value.absent(),
    this.poNo = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.deliveryRef = const Value.absent(),
    this.notes = const Value.absent(),
    required String createdAt,
    this.grnNo = const Value.absent(),
    this.confirmedAfter = const Value.absent(),
    this.settled = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : opId = Value(opId),
       kind = Value(kind),
       warehouseId = Value(warehouseId),
       createdAt = Value(createdAt);
  static Insertable<WhReceipt> custom({
    Expression<String>? opId,
    Expression<String>? kind,
    Expression<String>? warehouseId,
    Expression<String>? poId,
    Expression<String>? poNo,
    Expression<String>? supplierId,
    Expression<String>? deliveryRef,
    Expression<String>? notes,
    Expression<String>? createdAt,
    Expression<String>? grnNo,
    Expression<String>? confirmedAfter,
    Expression<bool>? settled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (opId != null) 'op_id': opId,
      if (kind != null) 'kind': kind,
      if (warehouseId != null) 'warehouse_id': warehouseId,
      if (poId != null) 'po_id': poId,
      if (poNo != null) 'po_no': poNo,
      if (supplierId != null) 'supplier_id': supplierId,
      if (deliveryRef != null) 'delivery_ref': deliveryRef,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (grnNo != null) 'grn_no': grnNo,
      if (confirmedAfter != null) 'confirmed_after': confirmedAfter,
      if (settled != null) 'settled': settled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WhReceiptsCompanion copyWith({
    Value<String>? opId,
    Value<String>? kind,
    Value<String>? warehouseId,
    Value<String?>? poId,
    Value<String?>? poNo,
    Value<String?>? supplierId,
    Value<String?>? deliveryRef,
    Value<String?>? notes,
    Value<String>? createdAt,
    Value<String?>? grnNo,
    Value<String?>? confirmedAfter,
    Value<bool>? settled,
    Value<int>? rowid,
  }) {
    return WhReceiptsCompanion(
      opId: opId ?? this.opId,
      kind: kind ?? this.kind,
      warehouseId: warehouseId ?? this.warehouseId,
      poId: poId ?? this.poId,
      poNo: poNo ?? this.poNo,
      supplierId: supplierId ?? this.supplierId,
      deliveryRef: deliveryRef ?? this.deliveryRef,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      grnNo: grnNo ?? this.grnNo,
      confirmedAfter: confirmedAfter ?? this.confirmedAfter,
      settled: settled ?? this.settled,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (opId.present) {
      map['op_id'] = Variable<String>(opId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (warehouseId.present) {
      map['warehouse_id'] = Variable<String>(warehouseId.value);
    }
    if (poId.present) {
      map['po_id'] = Variable<String>(poId.value);
    }
    if (poNo.present) {
      map['po_no'] = Variable<String>(poNo.value);
    }
    if (supplierId.present) {
      map['supplier_id'] = Variable<String>(supplierId.value);
    }
    if (deliveryRef.present) {
      map['delivery_ref'] = Variable<String>(deliveryRef.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (grnNo.present) {
      map['grn_no'] = Variable<String>(grnNo.value);
    }
    if (confirmedAfter.present) {
      map['confirmed_after'] = Variable<String>(confirmedAfter.value);
    }
    if (settled.present) {
      map['settled'] = Variable<bool>(settled.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WhReceiptsCompanion(')
          ..write('opId: $opId, ')
          ..write('kind: $kind, ')
          ..write('warehouseId: $warehouseId, ')
          ..write('poId: $poId, ')
          ..write('poNo: $poNo, ')
          ..write('supplierId: $supplierId, ')
          ..write('deliveryRef: $deliveryRef, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('grnNo: $grnNo, ')
          ..write('confirmedAfter: $confirmedAfter, ')
          ..write('settled: $settled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WhReceiptItemsTable extends WhReceiptItems
    with TableInfo<$WhReceiptItemsTable, WhReceiptItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WhReceiptItemsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _unitCostMeta = const VerificationMeta(
    'unitCost',
  );
  @override
  late final GeneratedColumn<int> unitCost = GeneratedColumn<int>(
    'unit_cost',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, opId, variantId, qty, unitCost];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wh_receipt_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<WhReceiptItem> instance, {
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
    if (data.containsKey('unit_cost')) {
      context.handle(
        _unitCostMeta,
        unitCost.isAcceptableOrUnknown(data['unit_cost']!, _unitCostMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WhReceiptItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WhReceiptItem(
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
      unitCost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_cost'],
      ),
    );
  }

  @override
  $WhReceiptItemsTable createAlias(String alias) {
    return $WhReceiptItemsTable(attachedDatabase, alias);
  }
}

class WhReceiptItem extends DataClass implements Insertable<WhReceiptItem> {
  final int id;
  final String opId;
  final String variantId;
  final double qty;
  final int? unitCost;
  const WhReceiptItem({
    required this.id,
    required this.opId,
    required this.variantId,
    required this.qty,
    this.unitCost,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['op_id'] = Variable<String>(opId);
    map['variant_id'] = Variable<String>(variantId);
    map['qty'] = Variable<double>(qty);
    if (!nullToAbsent || unitCost != null) {
      map['unit_cost'] = Variable<int>(unitCost);
    }
    return map;
  }

  WhReceiptItemsCompanion toCompanion(bool nullToAbsent) {
    return WhReceiptItemsCompanion(
      id: Value(id),
      opId: Value(opId),
      variantId: Value(variantId),
      qty: Value(qty),
      unitCost: unitCost == null && nullToAbsent
          ? const Value.absent()
          : Value(unitCost),
    );
  }

  factory WhReceiptItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WhReceiptItem(
      id: serializer.fromJson<int>(json['id']),
      opId: serializer.fromJson<String>(json['opId']),
      variantId: serializer.fromJson<String>(json['variantId']),
      qty: serializer.fromJson<double>(json['qty']),
      unitCost: serializer.fromJson<int?>(json['unitCost']),
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
      'unitCost': serializer.toJson<int?>(unitCost),
    };
  }

  WhReceiptItem copyWith({
    int? id,
    String? opId,
    String? variantId,
    double? qty,
    Value<int?> unitCost = const Value.absent(),
  }) => WhReceiptItem(
    id: id ?? this.id,
    opId: opId ?? this.opId,
    variantId: variantId ?? this.variantId,
    qty: qty ?? this.qty,
    unitCost: unitCost.present ? unitCost.value : this.unitCost,
  );
  WhReceiptItem copyWithCompanion(WhReceiptItemsCompanion data) {
    return WhReceiptItem(
      id: data.id.present ? data.id.value : this.id,
      opId: data.opId.present ? data.opId.value : this.opId,
      variantId: data.variantId.present ? data.variantId.value : this.variantId,
      qty: data.qty.present ? data.qty.value : this.qty,
      unitCost: data.unitCost.present ? data.unitCost.value : this.unitCost,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WhReceiptItem(')
          ..write('id: $id, ')
          ..write('opId: $opId, ')
          ..write('variantId: $variantId, ')
          ..write('qty: $qty, ')
          ..write('unitCost: $unitCost')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, opId, variantId, qty, unitCost);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WhReceiptItem &&
          other.id == this.id &&
          other.opId == this.opId &&
          other.variantId == this.variantId &&
          other.qty == this.qty &&
          other.unitCost == this.unitCost);
}

class WhReceiptItemsCompanion extends UpdateCompanion<WhReceiptItem> {
  final Value<int> id;
  final Value<String> opId;
  final Value<String> variantId;
  final Value<double> qty;
  final Value<int?> unitCost;
  const WhReceiptItemsCompanion({
    this.id = const Value.absent(),
    this.opId = const Value.absent(),
    this.variantId = const Value.absent(),
    this.qty = const Value.absent(),
    this.unitCost = const Value.absent(),
  });
  WhReceiptItemsCompanion.insert({
    this.id = const Value.absent(),
    required String opId,
    required String variantId,
    required double qty,
    this.unitCost = const Value.absent(),
  }) : opId = Value(opId),
       variantId = Value(variantId),
       qty = Value(qty);
  static Insertable<WhReceiptItem> custom({
    Expression<int>? id,
    Expression<String>? opId,
    Expression<String>? variantId,
    Expression<double>? qty,
    Expression<int>? unitCost,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (opId != null) 'op_id': opId,
      if (variantId != null) 'variant_id': variantId,
      if (qty != null) 'qty': qty,
      if (unitCost != null) 'unit_cost': unitCost,
    });
  }

  WhReceiptItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? opId,
    Value<String>? variantId,
    Value<double>? qty,
    Value<int?>? unitCost,
  }) {
    return WhReceiptItemsCompanion(
      id: id ?? this.id,
      opId: opId ?? this.opId,
      variantId: variantId ?? this.variantId,
      qty: qty ?? this.qty,
      unitCost: unitCost ?? this.unitCost,
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
    if (unitCost.present) {
      map['unit_cost'] = Variable<int>(unitCost.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WhReceiptItemsCompanion(')
          ..write('id: $id, ')
          ..write('opId: $opId, ')
          ..write('variantId: $variantId, ')
          ..write('qty: $qty, ')
          ..write('unitCost: $unitCost')
          ..write(')'))
        .toString();
  }
}

class $ShiftsTable extends Shifts with TableInfo<$ShiftsTable, Shift> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShiftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationIdMeta = const VerificationMeta(
    'locationId',
  );
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
    'location_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cashierIdMeta = const VerificationMeta(
    'cashierId',
  );
  @override
  late final GeneratedColumn<String> cashierId = GeneratedColumn<String>(
    'cashier_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _openingCashMeta = const VerificationMeta(
    'openingCash',
  );
  @override
  late final GeneratedColumn<int> openingCash = GeneratedColumn<int>(
    'opening_cash',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _openedAtMeta = const VerificationMeta(
    'openedAt',
  );
  @override
  late final GeneratedColumn<String> openedAt = GeneratedColumn<String>(
    'opened_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _closedAtMeta = const VerificationMeta(
    'closedAt',
  );
  @override
  late final GeneratedColumn<String> closedAt = GeneratedColumn<String>(
    'closed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expectedCashMeta = const VerificationMeta(
    'expectedCash',
  );
  @override
  late final GeneratedColumn<int> expectedCash = GeneratedColumn<int>(
    'expected_cash',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverExpectedCashMeta =
      const VerificationMeta('serverExpectedCash');
  @override
  late final GeneratedColumn<int> serverExpectedCash = GeneratedColumn<int>(
    'server_expected_cash',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countedCashMeta = const VerificationMeta(
    'countedCash',
  );
  @override
  late final GeneratedColumn<int> countedCash = GeneratedColumn<int>(
    'counted_cash',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _differenceMeta = const VerificationMeta(
    'difference',
  );
  @override
  late final GeneratedColumn<int> difference = GeneratedColumn<int>(
    'difference',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  static const VerificationMeta _closedByMeta = const VerificationMeta(
    'closedBy',
  );
  @override
  late final GeneratedColumn<String> closedBy = GeneratedColumn<String>(
    'closed_by',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    locationId,
    cashierId,
    currency,
    openingCash,
    openedAt,
    closedAt,
    expectedCash,
    serverExpectedCash,
    countedCash,
    difference,
    note,
    closedBy,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shifts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Shift> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('location_id')) {
      context.handle(
        _locationIdMeta,
        locationId.isAcceptableOrUnknown(data['location_id']!, _locationIdMeta),
      );
    }
    if (data.containsKey('cashier_id')) {
      context.handle(
        _cashierIdMeta,
        cashierId.isAcceptableOrUnknown(data['cashier_id']!, _cashierIdMeta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('opening_cash')) {
      context.handle(
        _openingCashMeta,
        openingCash.isAcceptableOrUnknown(
          data['opening_cash']!,
          _openingCashMeta,
        ),
      );
    }
    if (data.containsKey('opened_at')) {
      context.handle(
        _openedAtMeta,
        openedAt.isAcceptableOrUnknown(data['opened_at']!, _openedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_openedAtMeta);
    }
    if (data.containsKey('closed_at')) {
      context.handle(
        _closedAtMeta,
        closedAt.isAcceptableOrUnknown(data['closed_at']!, _closedAtMeta),
      );
    }
    if (data.containsKey('expected_cash')) {
      context.handle(
        _expectedCashMeta,
        expectedCash.isAcceptableOrUnknown(
          data['expected_cash']!,
          _expectedCashMeta,
        ),
      );
    }
    if (data.containsKey('server_expected_cash')) {
      context.handle(
        _serverExpectedCashMeta,
        serverExpectedCash.isAcceptableOrUnknown(
          data['server_expected_cash']!,
          _serverExpectedCashMeta,
        ),
      );
    }
    if (data.containsKey('counted_cash')) {
      context.handle(
        _countedCashMeta,
        countedCash.isAcceptableOrUnknown(
          data['counted_cash']!,
          _countedCashMeta,
        ),
      );
    }
    if (data.containsKey('difference')) {
      context.handle(
        _differenceMeta,
        difference.isAcceptableOrUnknown(data['difference']!, _differenceMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('closed_by')) {
      context.handle(
        _closedByMeta,
        closedBy.isAcceptableOrUnknown(data['closed_by']!, _closedByMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Shift map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Shift(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      locationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_id'],
      ),
      cashierId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cashier_id'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      openingCash: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opening_cash'],
      )!,
      openedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}opened_at'],
      )!,
      closedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}closed_at'],
      ),
      expectedCash: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_cash'],
      ),
      serverExpectedCash: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_expected_cash'],
      ),
      countedCash: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}counted_cash'],
      ),
      difference: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}difference'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      closedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}closed_by'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $ShiftsTable createAlias(String alias) {
    return $ShiftsTable(attachedDatabase, alias);
  }
}

class Shift extends DataClass implements Insertable<Shift> {
  final String id;
  final String? locationId;

  /// Whose shift it is (the signed-in user's id).
  final String? cashierId;
  final String currency;
  final int openingCash;
  final String openedAt;
  final String? closedAt;

  /// What the phone worked out when the shift was closed.
  final int? expectedCash;

  /// What the server computed from its own data; null until the close was applied and pulled.
  final int? serverExpectedCash;
  final int? countedCash;
  final int? difference;
  final String? note;
  final String? closedBy;
  final String? updatedAt;
  const Shift({
    required this.id,
    this.locationId,
    this.cashierId,
    required this.currency,
    required this.openingCash,
    required this.openedAt,
    this.closedAt,
    this.expectedCash,
    this.serverExpectedCash,
    this.countedCash,
    this.difference,
    this.note,
    this.closedBy,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || locationId != null) {
      map['location_id'] = Variable<String>(locationId);
    }
    if (!nullToAbsent || cashierId != null) {
      map['cashier_id'] = Variable<String>(cashierId);
    }
    map['currency'] = Variable<String>(currency);
    map['opening_cash'] = Variable<int>(openingCash);
    map['opened_at'] = Variable<String>(openedAt);
    if (!nullToAbsent || closedAt != null) {
      map['closed_at'] = Variable<String>(closedAt);
    }
    if (!nullToAbsent || expectedCash != null) {
      map['expected_cash'] = Variable<int>(expectedCash);
    }
    if (!nullToAbsent || serverExpectedCash != null) {
      map['server_expected_cash'] = Variable<int>(serverExpectedCash);
    }
    if (!nullToAbsent || countedCash != null) {
      map['counted_cash'] = Variable<int>(countedCash);
    }
    if (!nullToAbsent || difference != null) {
      map['difference'] = Variable<int>(difference);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || closedBy != null) {
      map['closed_by'] = Variable<String>(closedBy);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    return map;
  }

  ShiftsCompanion toCompanion(bool nullToAbsent) {
    return ShiftsCompanion(
      id: Value(id),
      locationId: locationId == null && nullToAbsent
          ? const Value.absent()
          : Value(locationId),
      cashierId: cashierId == null && nullToAbsent
          ? const Value.absent()
          : Value(cashierId),
      currency: Value(currency),
      openingCash: Value(openingCash),
      openedAt: Value(openedAt),
      closedAt: closedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(closedAt),
      expectedCash: expectedCash == null && nullToAbsent
          ? const Value.absent()
          : Value(expectedCash),
      serverExpectedCash: serverExpectedCash == null && nullToAbsent
          ? const Value.absent()
          : Value(serverExpectedCash),
      countedCash: countedCash == null && nullToAbsent
          ? const Value.absent()
          : Value(countedCash),
      difference: difference == null && nullToAbsent
          ? const Value.absent()
          : Value(difference),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      closedBy: closedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(closedBy),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory Shift.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Shift(
      id: serializer.fromJson<String>(json['id']),
      locationId: serializer.fromJson<String?>(json['locationId']),
      cashierId: serializer.fromJson<String?>(json['cashierId']),
      currency: serializer.fromJson<String>(json['currency']),
      openingCash: serializer.fromJson<int>(json['openingCash']),
      openedAt: serializer.fromJson<String>(json['openedAt']),
      closedAt: serializer.fromJson<String?>(json['closedAt']),
      expectedCash: serializer.fromJson<int?>(json['expectedCash']),
      serverExpectedCash: serializer.fromJson<int?>(json['serverExpectedCash']),
      countedCash: serializer.fromJson<int?>(json['countedCash']),
      difference: serializer.fromJson<int?>(json['difference']),
      note: serializer.fromJson<String?>(json['note']),
      closedBy: serializer.fromJson<String?>(json['closedBy']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'locationId': serializer.toJson<String?>(locationId),
      'cashierId': serializer.toJson<String?>(cashierId),
      'currency': serializer.toJson<String>(currency),
      'openingCash': serializer.toJson<int>(openingCash),
      'openedAt': serializer.toJson<String>(openedAt),
      'closedAt': serializer.toJson<String?>(closedAt),
      'expectedCash': serializer.toJson<int?>(expectedCash),
      'serverExpectedCash': serializer.toJson<int?>(serverExpectedCash),
      'countedCash': serializer.toJson<int?>(countedCash),
      'difference': serializer.toJson<int?>(difference),
      'note': serializer.toJson<String?>(note),
      'closedBy': serializer.toJson<String?>(closedBy),
      'updatedAt': serializer.toJson<String?>(updatedAt),
    };
  }

  Shift copyWith({
    String? id,
    Value<String?> locationId = const Value.absent(),
    Value<String?> cashierId = const Value.absent(),
    String? currency,
    int? openingCash,
    String? openedAt,
    Value<String?> closedAt = const Value.absent(),
    Value<int?> expectedCash = const Value.absent(),
    Value<int?> serverExpectedCash = const Value.absent(),
    Value<int?> countedCash = const Value.absent(),
    Value<int?> difference = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> closedBy = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
  }) => Shift(
    id: id ?? this.id,
    locationId: locationId.present ? locationId.value : this.locationId,
    cashierId: cashierId.present ? cashierId.value : this.cashierId,
    currency: currency ?? this.currency,
    openingCash: openingCash ?? this.openingCash,
    openedAt: openedAt ?? this.openedAt,
    closedAt: closedAt.present ? closedAt.value : this.closedAt,
    expectedCash: expectedCash.present ? expectedCash.value : this.expectedCash,
    serverExpectedCash: serverExpectedCash.present
        ? serverExpectedCash.value
        : this.serverExpectedCash,
    countedCash: countedCash.present ? countedCash.value : this.countedCash,
    difference: difference.present ? difference.value : this.difference,
    note: note.present ? note.value : this.note,
    closedBy: closedBy.present ? closedBy.value : this.closedBy,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  Shift copyWithCompanion(ShiftsCompanion data) {
    return Shift(
      id: data.id.present ? data.id.value : this.id,
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
      cashierId: data.cashierId.present ? data.cashierId.value : this.cashierId,
      currency: data.currency.present ? data.currency.value : this.currency,
      openingCash: data.openingCash.present
          ? data.openingCash.value
          : this.openingCash,
      openedAt: data.openedAt.present ? data.openedAt.value : this.openedAt,
      closedAt: data.closedAt.present ? data.closedAt.value : this.closedAt,
      expectedCash: data.expectedCash.present
          ? data.expectedCash.value
          : this.expectedCash,
      serverExpectedCash: data.serverExpectedCash.present
          ? data.serverExpectedCash.value
          : this.serverExpectedCash,
      countedCash: data.countedCash.present
          ? data.countedCash.value
          : this.countedCash,
      difference: data.difference.present
          ? data.difference.value
          : this.difference,
      note: data.note.present ? data.note.value : this.note,
      closedBy: data.closedBy.present ? data.closedBy.value : this.closedBy,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Shift(')
          ..write('id: $id, ')
          ..write('locationId: $locationId, ')
          ..write('cashierId: $cashierId, ')
          ..write('currency: $currency, ')
          ..write('openingCash: $openingCash, ')
          ..write('openedAt: $openedAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('expectedCash: $expectedCash, ')
          ..write('serverExpectedCash: $serverExpectedCash, ')
          ..write('countedCash: $countedCash, ')
          ..write('difference: $difference, ')
          ..write('note: $note, ')
          ..write('closedBy: $closedBy, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    locationId,
    cashierId,
    currency,
    openingCash,
    openedAt,
    closedAt,
    expectedCash,
    serverExpectedCash,
    countedCash,
    difference,
    note,
    closedBy,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Shift &&
          other.id == this.id &&
          other.locationId == this.locationId &&
          other.cashierId == this.cashierId &&
          other.currency == this.currency &&
          other.openingCash == this.openingCash &&
          other.openedAt == this.openedAt &&
          other.closedAt == this.closedAt &&
          other.expectedCash == this.expectedCash &&
          other.serverExpectedCash == this.serverExpectedCash &&
          other.countedCash == this.countedCash &&
          other.difference == this.difference &&
          other.note == this.note &&
          other.closedBy == this.closedBy &&
          other.updatedAt == this.updatedAt);
}

class ShiftsCompanion extends UpdateCompanion<Shift> {
  final Value<String> id;
  final Value<String?> locationId;
  final Value<String?> cashierId;
  final Value<String> currency;
  final Value<int> openingCash;
  final Value<String> openedAt;
  final Value<String?> closedAt;
  final Value<int?> expectedCash;
  final Value<int?> serverExpectedCash;
  final Value<int?> countedCash;
  final Value<int?> difference;
  final Value<String?> note;
  final Value<String?> closedBy;
  final Value<String?> updatedAt;
  final Value<int> rowid;
  const ShiftsCompanion({
    this.id = const Value.absent(),
    this.locationId = const Value.absent(),
    this.cashierId = const Value.absent(),
    this.currency = const Value.absent(),
    this.openingCash = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.expectedCash = const Value.absent(),
    this.serverExpectedCash = const Value.absent(),
    this.countedCash = const Value.absent(),
    this.difference = const Value.absent(),
    this.note = const Value.absent(),
    this.closedBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShiftsCompanion.insert({
    required String id,
    this.locationId = const Value.absent(),
    this.cashierId = const Value.absent(),
    required String currency,
    this.openingCash = const Value.absent(),
    required String openedAt,
    this.closedAt = const Value.absent(),
    this.expectedCash = const Value.absent(),
    this.serverExpectedCash = const Value.absent(),
    this.countedCash = const Value.absent(),
    this.difference = const Value.absent(),
    this.note = const Value.absent(),
    this.closedBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       currency = Value(currency),
       openedAt = Value(openedAt);
  static Insertable<Shift> custom({
    Expression<String>? id,
    Expression<String>? locationId,
    Expression<String>? cashierId,
    Expression<String>? currency,
    Expression<int>? openingCash,
    Expression<String>? openedAt,
    Expression<String>? closedAt,
    Expression<int>? expectedCash,
    Expression<int>? serverExpectedCash,
    Expression<int>? countedCash,
    Expression<int>? difference,
    Expression<String>? note,
    Expression<String>? closedBy,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (locationId != null) 'location_id': locationId,
      if (cashierId != null) 'cashier_id': cashierId,
      if (currency != null) 'currency': currency,
      if (openingCash != null) 'opening_cash': openingCash,
      if (openedAt != null) 'opened_at': openedAt,
      if (closedAt != null) 'closed_at': closedAt,
      if (expectedCash != null) 'expected_cash': expectedCash,
      if (serverExpectedCash != null)
        'server_expected_cash': serverExpectedCash,
      if (countedCash != null) 'counted_cash': countedCash,
      if (difference != null) 'difference': difference,
      if (note != null) 'note': note,
      if (closedBy != null) 'closed_by': closedBy,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShiftsCompanion copyWith({
    Value<String>? id,
    Value<String?>? locationId,
    Value<String?>? cashierId,
    Value<String>? currency,
    Value<int>? openingCash,
    Value<String>? openedAt,
    Value<String?>? closedAt,
    Value<int?>? expectedCash,
    Value<int?>? serverExpectedCash,
    Value<int?>? countedCash,
    Value<int?>? difference,
    Value<String?>? note,
    Value<String?>? closedBy,
    Value<String?>? updatedAt,
    Value<int>? rowid,
  }) {
    return ShiftsCompanion(
      id: id ?? this.id,
      locationId: locationId ?? this.locationId,
      cashierId: cashierId ?? this.cashierId,
      currency: currency ?? this.currency,
      openingCash: openingCash ?? this.openingCash,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      expectedCash: expectedCash ?? this.expectedCash,
      serverExpectedCash: serverExpectedCash ?? this.serverExpectedCash,
      countedCash: countedCash ?? this.countedCash,
      difference: difference ?? this.difference,
      note: note ?? this.note,
      closedBy: closedBy ?? this.closedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (cashierId.present) {
      map['cashier_id'] = Variable<String>(cashierId.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (openingCash.present) {
      map['opening_cash'] = Variable<int>(openingCash.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<String>(openedAt.value);
    }
    if (closedAt.present) {
      map['closed_at'] = Variable<String>(closedAt.value);
    }
    if (expectedCash.present) {
      map['expected_cash'] = Variable<int>(expectedCash.value);
    }
    if (serverExpectedCash.present) {
      map['server_expected_cash'] = Variable<int>(serverExpectedCash.value);
    }
    if (countedCash.present) {
      map['counted_cash'] = Variable<int>(countedCash.value);
    }
    if (difference.present) {
      map['difference'] = Variable<int>(difference.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (closedBy.present) {
      map['closed_by'] = Variable<String>(closedBy.value);
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
    return (StringBuffer('ShiftsCompanion(')
          ..write('id: $id, ')
          ..write('locationId: $locationId, ')
          ..write('cashierId: $cashierId, ')
          ..write('currency: $currency, ')
          ..write('openingCash: $openingCash, ')
          ..write('openedAt: $openedAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('expectedCash: $expectedCash, ')
          ..write('serverExpectedCash: $serverExpectedCash, ')
          ..write('countedCash: $countedCash, ')
          ..write('difference: $difference, ')
          ..write('note: $note, ')
          ..write('closedBy: $closedBy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
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
  late final $ExpensesTable expenses = $ExpensesTable(this);
  late final $DayClosesTable dayCloses = $DayClosesTable(this);
  late final $ServiceTxnsTable serviceTxns = $ServiceTxnsTable(this);
  late final $WalletFloatsTable walletFloats = $WalletFloatsTable(this);
  late final $LocalFloatEffectsTable localFloatEffects =
      $LocalFloatEffectsTable(this);
  late final $ConversionsTable conversions = $ConversionsTable(this);
  late final $StockExpiryTable stockExpiry = $StockExpiryTable(this);
  late final $WarehousesTable warehouses = $WarehousesTable(this);
  late final $WhBinsTable whBins = $WhBinsTable(this);
  late final $WhBinStockTable whBinStock = $WhBinStockTable(this);
  late final $WhStockTable whStock = $WhStockTable(this);
  late final $SuppliersTable suppliers = $SuppliersTable(this);
  late final $PurchaseOrdersTable purchaseOrders = $PurchaseOrdersTable(this);
  late final $PoItemsTable poItems = $PoItemsTable(this);
  late final $WhReceiptsTable whReceipts = $WhReceiptsTable(this);
  late final $WhReceiptItemsTable whReceiptItems = $WhReceiptItemsTable(this);
  late final $ShiftsTable shifts = $ShiftsTable(this);
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
  late final Index salesLocationSoldAt = Index(
    'sales_location_sold_at',
    'CREATE INDEX sales_location_sold_at ON sales (location_id, sold_at)',
  );
  late final Index saleItemsSale = Index(
    'sale_items_sale',
    'CREATE INDEX sale_items_sale ON sale_items (sale_id)',
  );
  late final Index salePaymentsSale = Index(
    'sale_payments_sale',
    'CREATE INDEX sale_payments_sale ON sale_payments (sale_id)',
  );
  late final Index expensesSpentAt = Index(
    'expenses_spent_at',
    'CREATE INDEX expenses_spent_at ON expenses (spent_at)',
  );
  late final Index dayClosesDay = Index(
    'day_closes_day',
    'CREATE INDEX day_closes_day ON day_closes (day)',
  );
  late final Index serviceTxnsTxnAt = Index(
    'service_txns_txn_at',
    'CREATE INDEX service_txns_txn_at ON service_txns (txn_at)',
  );
  late final Index conversionsConvertedAt = Index(
    'conversions_converted_at',
    'CREATE INDEX conversions_converted_at ON conversions (converted_at)',
  );
  late final Index whBinsWarehouse = Index(
    'wh_bins_warehouse',
    'CREATE INDEX wh_bins_warehouse ON wh_bins (warehouse_id)',
  );
  late final Index purchaseOrdersWarehouse = Index(
    'purchase_orders_warehouse',
    'CREATE INDEX purchase_orders_warehouse ON purchase_orders (warehouse_id, status)',
  );
  late final Index poItemsPo = Index(
    'po_items_po',
    'CREATE INDEX po_items_po ON po_items (po_id)',
  );
  late final Index whReceiptsWarehouse = Index(
    'wh_receipts_warehouse',
    'CREATE INDEX wh_receipts_warehouse ON wh_receipts (warehouse_id, created_at)',
  );
  late final Index whReceiptItemsOp = Index(
    'wh_receipt_items_op',
    'CREATE INDEX wh_receipt_items_op ON wh_receipt_items (op_id)',
  );
  late final Index shiftsOpened = Index(
    'shifts_opened',
    'CREATE INDEX shifts_opened ON shifts (opened_at)',
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
    expenses,
    dayCloses,
    serviceTxns,
    walletFloats,
    localFloatEffects,
    conversions,
    stockExpiry,
    warehouses,
    whBins,
    whBinStock,
    whStock,
    suppliers,
    purchaseOrders,
    poItems,
    whReceipts,
    whReceiptItems,
    shifts,
    variantsBarcode,
    variantsProduct,
    salesSoldAt,
    salesLocationSoldAt,
    saleItemsSale,
    salePaymentsSale,
    expensesSpentAt,
    dayClosesDay,
    serviceTxnsTxnAt,
    conversionsConvertedAt,
    whBinsWarehouse,
    purchaseOrdersWarehouse,
    poItemsPo,
    whReceiptsWarehouse,
    whReceiptItemsOp,
    shiftsOpened,
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
      Value<String> name,
      required String sku,
      Value<String?> barcode,
      Value<bool> isDefault,
      Value<int> cost,
      Value<double> reorderPoint,
      Value<bool> active,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<String?> breaksIntoVariantId,
      Value<int?> breaksIntoQty,
      Value<int> rowid,
    });
typedef $$VariantsTableUpdateCompanionBuilder =
    VariantsCompanion Function({
      Value<String> id,
      Value<String> productId,
      Value<String> name,
      Value<String> sku,
      Value<String?> barcode,
      Value<bool> isDefault,
      Value<int> cost,
      Value<double> reorderPoint,
      Value<bool> active,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<String?> breaksIntoVariantId,
      Value<int?> breaksIntoQty,
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
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

  ColumnFilters<String> get breaksIntoVariantId => $composableBuilder(
    column: $table.breaksIntoVariantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get breaksIntoQty => $composableBuilder(
    column: $table.breaksIntoQty,
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
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

  ColumnOrderings<String> get breaksIntoVariantId => $composableBuilder(
    column: $table.breaksIntoVariantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get breaksIntoQty => $composableBuilder(
    column: $table.breaksIntoQty,
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

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

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

  GeneratedColumn<String> get breaksIntoVariantId => $composableBuilder(
    column: $table.breaksIntoVariantId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get breaksIntoQty => $composableBuilder(
    column: $table.breaksIntoQty,
    builder: (column) => column,
  );
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
                Value<String> name = const Value.absent(),
                Value<String> sku = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> cost = const Value.absent(),
                Value<double> reorderPoint = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String?> breaksIntoVariantId = const Value.absent(),
                Value<int?> breaksIntoQty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VariantsCompanion(
                id: id,
                productId: productId,
                name: name,
                sku: sku,
                barcode: barcode,
                isDefault: isDefault,
                cost: cost,
                reorderPoint: reorderPoint,
                active: active,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                breaksIntoVariantId: breaksIntoVariantId,
                breaksIntoQty: breaksIntoQty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String productId,
                Value<String> name = const Value.absent(),
                required String sku,
                Value<String?> barcode = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> cost = const Value.absent(),
                Value<double> reorderPoint = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String?> breaksIntoVariantId = const Value.absent(),
                Value<int?> breaksIntoQty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VariantsCompanion.insert(
                id: id,
                productId: productId,
                name: name,
                sku: sku,
                barcode: barcode,
                isDefault: isDefault,
                cost: cost,
                reorderPoint: reorderPoint,
                active: active,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                breaksIntoVariantId: breaksIntoVariantId,
                breaksIntoQty: breaksIntoQty,
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
      Value<String?> dueOn,
      Value<int> rowid,
    });
typedef $$CustomersTableUpdateCompanionBuilder =
    CustomersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> phone,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<String?> dueOn,
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

  ColumnFilters<String> get dueOn => $composableBuilder(
    column: $table.dueOn,
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

  ColumnOrderings<String> get dueOn => $composableBuilder(
    column: $table.dueOn,
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

  GeneratedColumn<String> get dueOn =>
      $composableBuilder(column: $table.dueOn, builder: (column) => column);
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
                Value<String?> dueOn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomersCompanion(
                id: id,
                name: name,
                phone: phone,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dueOn: dueOn,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> phone = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String?> dueOn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomersCompanion.insert(
                id: id,
                name: name,
                phone: phone,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dueOn: dueOn,
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
      Value<String?> locationId,
      Value<String> method,
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
      Value<String?> locationId,
      Value<String> method,
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

  ColumnFilters<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
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

  ColumnOrderings<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
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

  GeneratedColumn<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);
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
                Value<String?> locationId = const Value.absent(),
                Value<String> method = const Value.absent(),
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
                locationId: locationId,
                method: method,
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
                Value<String?> locationId = const Value.absent(),
                Value<String> method = const Value.absent(),
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
                locationId: locationId,
                method: method,
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
      Value<String?> locationId,
      Value<String> method,
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
      Value<String?> locationId,
      Value<String> method,
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

  ColumnFilters<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
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

  ColumnOrderings<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
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

  GeneratedColumn<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);
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
                Value<String?> locationId = const Value.absent(),
                Value<String> method = const Value.absent(),
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
                locationId: locationId,
                method: method,
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
                Value<String?> locationId = const Value.absent(),
                Value<String> method = const Value.absent(),
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
                locationId: locationId,
                method: method,
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
      Value<int?> avgCost,
      Value<bool> counted,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$StockLevelsTableUpdateCompanionBuilder =
    StockLevelsCompanion Function({
      Value<String> locationId,
      Value<String> variantId,
      Value<double> qty,
      Value<int?> avgCost,
      Value<bool> counted,
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

  ColumnFilters<int> get avgCost => $composableBuilder(
    column: $table.avgCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get counted => $composableBuilder(
    column: $table.counted,
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

  ColumnOrderings<int> get avgCost => $composableBuilder(
    column: $table.avgCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get counted => $composableBuilder(
    column: $table.counted,
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

  GeneratedColumn<int> get avgCost =>
      $composableBuilder(column: $table.avgCost, builder: (column) => column);

  GeneratedColumn<bool> get counted =>
      $composableBuilder(column: $table.counted, builder: (column) => column);

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
                Value<int?> avgCost = const Value.absent(),
                Value<bool> counted = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StockLevelsCompanion(
                locationId: locationId,
                variantId: variantId,
                qty: qty,
                avgCost: avgCost,
                counted: counted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String locationId,
                required String variantId,
                required double qty,
                Value<int?> avgCost = const Value.absent(),
                Value<bool> counted = const Value.absent(),
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => StockLevelsCompanion.insert(
                locationId: locationId,
                variantId: variantId,
                qty: qty,
                avgCost: avgCost,
                counted: counted,
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
      Value<bool> counts,
      Value<String?> confirmedAfter,
      Value<int?> unitCost,
      Value<int?> totalCost,
      Value<String?> locationId,
    });
typedef $$LocalMovementsTableUpdateCompanionBuilder =
    LocalMovementsCompanion Function({
      Value<int> id,
      Value<String> opId,
      Value<String> variantId,
      Value<double> qty,
      Value<bool> counts,
      Value<String?> confirmedAfter,
      Value<int?> unitCost,
      Value<int?> totalCost,
      Value<String?> locationId,
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

  ColumnFilters<bool> get counts => $composableBuilder(
    column: $table.counts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confirmedAfter => $composableBuilder(
    column: $table.confirmedAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitCost => $composableBuilder(
    column: $table.unitCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalCost => $composableBuilder(
    column: $table.totalCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationId => $composableBuilder(
    column: $table.locationId,
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

  ColumnOrderings<bool> get counts => $composableBuilder(
    column: $table.counts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confirmedAfter => $composableBuilder(
    column: $table.confirmedAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitCost => $composableBuilder(
    column: $table.unitCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalCost => $composableBuilder(
    column: $table.totalCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationId => $composableBuilder(
    column: $table.locationId,
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

  GeneratedColumn<bool> get counts =>
      $composableBuilder(column: $table.counts, builder: (column) => column);

  GeneratedColumn<String> get confirmedAfter => $composableBuilder(
    column: $table.confirmedAfter,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unitCost =>
      $composableBuilder(column: $table.unitCost, builder: (column) => column);

  GeneratedColumn<int> get totalCost =>
      $composableBuilder(column: $table.totalCost, builder: (column) => column);

  GeneratedColumn<String> get locationId => $composableBuilder(
    column: $table.locationId,
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
                Value<bool> counts = const Value.absent(),
                Value<String?> confirmedAfter = const Value.absent(),
                Value<int?> unitCost = const Value.absent(),
                Value<int?> totalCost = const Value.absent(),
                Value<String?> locationId = const Value.absent(),
              }) => LocalMovementsCompanion(
                id: id,
                opId: opId,
                variantId: variantId,
                qty: qty,
                counts: counts,
                confirmedAfter: confirmedAfter,
                unitCost: unitCost,
                totalCost: totalCost,
                locationId: locationId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String opId,
                required String variantId,
                required double qty,
                Value<bool> counts = const Value.absent(),
                Value<String?> confirmedAfter = const Value.absent(),
                Value<int?> unitCost = const Value.absent(),
                Value<int?> totalCost = const Value.absent(),
                Value<String?> locationId = const Value.absent(),
              }) => LocalMovementsCompanion.insert(
                id: id,
                opId: opId,
                variantId: variantId,
                qty: qty,
                counts: counts,
                confirmedAfter: confirmedAfter,
                unitCost: unitCost,
                totalCost: totalCost,
                locationId: locationId,
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
      Value<String?> locationId,
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
      Value<String?> saleNo,
      Value<String?> deviceId,
      Value<int> rowid,
    });
typedef $$SalesTableUpdateCompanionBuilder =
    SalesCompanion Function({
      Value<String> id,
      Value<String?> locationId,
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
      Value<String?> saleNo,
      Value<String?> deviceId,
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

  ColumnFilters<String> get locationId => $composableBuilder(
    column: $table.locationId,
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

  ColumnFilters<String> get saleNo => $composableBuilder(
    column: $table.saleNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
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

  ColumnOrderings<String> get locationId => $composableBuilder(
    column: $table.locationId,
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

  ColumnOrderings<String> get saleNo => $composableBuilder(
    column: $table.saleNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
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

  GeneratedColumn<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => column,
  );

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

  GeneratedColumn<String> get saleNo =>
      $composableBuilder(column: $table.saleNo, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
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
                Value<String?> locationId = const Value.absent(),
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
                Value<String?> saleNo = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SalesCompanion(
                id: id,
                locationId: locationId,
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
                saleNo: saleNo,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> locationId = const Value.absent(),
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
                Value<String?> saleNo = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SalesCompanion.insert(
                id: id,
                locationId: locationId,
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
                saleNo: saleNo,
                deviceId: deviceId,
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
      Value<String?> wallet,
    });
typedef $$SalePaymentsTableUpdateCompanionBuilder =
    SalePaymentsCompanion Function({
      Value<int> id,
      Value<String> saleId,
      Value<String> method,
      Value<int> amount,
      Value<int?> tendered,
      Value<String?> reference,
      Value<String?> wallet,
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

  ColumnFilters<String> get wallet => $composableBuilder(
    column: $table.wallet,
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

  ColumnOrderings<String> get wallet => $composableBuilder(
    column: $table.wallet,
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

  GeneratedColumn<String> get wallet =>
      $composableBuilder(column: $table.wallet, builder: (column) => column);
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
                Value<String?> wallet = const Value.absent(),
              }) => SalePaymentsCompanion(
                id: id,
                saleId: saleId,
                method: method,
                amount: amount,
                tendered: tendered,
                reference: reference,
                wallet: wallet,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String saleId,
                required String method,
                required int amount,
                Value<int?> tendered = const Value.absent(),
                Value<String?> reference = const Value.absent(),
                Value<String?> wallet = const Value.absent(),
              }) => SalePaymentsCompanion.insert(
                id: id,
                saleId: saleId,
                method: method,
                amount: amount,
                tendered: tendered,
                reference: reference,
                wallet: wallet,
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
typedef $$ExpensesTableCreateCompanionBuilder =
    ExpensesCompanion Function({
      required String id,
      Value<String?> locationId,
      required int amount,
      required String currency,
      required String category,
      Value<String> paidFrom,
      Value<String?> wallet,
      Value<String?> note,
      required String spentAt,
      Value<String?> createdBy,
      Value<String?> approvedBy,
      Value<String?> voidedAt,
      Value<String?> voidReason,
      Value<String?> voidApprovedBy,
      Value<String?> updatedAt,
      Value<int> rowid,
    });
typedef $$ExpensesTableUpdateCompanionBuilder =
    ExpensesCompanion Function({
      Value<String> id,
      Value<String?> locationId,
      Value<int> amount,
      Value<String> currency,
      Value<String> category,
      Value<String> paidFrom,
      Value<String?> wallet,
      Value<String?> note,
      Value<String> spentAt,
      Value<String?> createdBy,
      Value<String?> approvedBy,
      Value<String?> voidedAt,
      Value<String?> voidReason,
      Value<String?> voidApprovedBy,
      Value<String?> updatedAt,
      Value<int> rowid,
    });

class $$ExpensesTableFilterComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableFilterComposer({
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

  ColumnFilters<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paidFrom => $composableBuilder(
    column: $table.paidFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wallet => $composableBuilder(
    column: $table.wallet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spentAt => $composableBuilder(
    column: $table.spentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get approvedBy => $composableBuilder(
    column: $table.approvedBy,
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

  ColumnFilters<String> get voidApprovedBy => $composableBuilder(
    column: $table.voidApprovedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExpensesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableOrderingComposer({
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

  ColumnOrderings<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paidFrom => $composableBuilder(
    column: $table.paidFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wallet => $composableBuilder(
    column: $table.wallet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spentAt => $composableBuilder(
    column: $table.spentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get approvedBy => $composableBuilder(
    column: $table.approvedBy,
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

  ColumnOrderings<String> get voidApprovedBy => $composableBuilder(
    column: $table.voidApprovedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExpensesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get paidFrom =>
      $composableBuilder(column: $table.paidFrom, builder: (column) => column);

  GeneratedColumn<String> get wallet =>
      $composableBuilder(column: $table.wallet, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get spentAt =>
      $composableBuilder(column: $table.spentAt, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get approvedBy => $composableBuilder(
    column: $table.approvedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get voidedAt =>
      $composableBuilder(column: $table.voidedAt, builder: (column) => column);

  GeneratedColumn<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => column,
  );

  GeneratedColumn<String> get voidApprovedBy => $composableBuilder(
    column: $table.voidApprovedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ExpensesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExpensesTable,
          Expense,
          $$ExpensesTableFilterComposer,
          $$ExpensesTableOrderingComposer,
          $$ExpensesTableAnnotationComposer,
          $$ExpensesTableCreateCompanionBuilder,
          $$ExpensesTableUpdateCompanionBuilder,
          (Expense, BaseReferences<_$AppDatabase, $ExpensesTable, Expense>),
          Expense,
          PrefetchHooks Function()
        > {
  $$ExpensesTableTableManager(_$AppDatabase db, $ExpensesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> locationId = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> paidFrom = const Value.absent(),
                Value<String?> wallet = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> spentAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> approvedBy = const Value.absent(),
                Value<String?> voidedAt = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<String?> voidApprovedBy = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpensesCompanion(
                id: id,
                locationId: locationId,
                amount: amount,
                currency: currency,
                category: category,
                paidFrom: paidFrom,
                wallet: wallet,
                note: note,
                spentAt: spentAt,
                createdBy: createdBy,
                approvedBy: approvedBy,
                voidedAt: voidedAt,
                voidReason: voidReason,
                voidApprovedBy: voidApprovedBy,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> locationId = const Value.absent(),
                required int amount,
                required String currency,
                required String category,
                Value<String> paidFrom = const Value.absent(),
                Value<String?> wallet = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required String spentAt,
                Value<String?> createdBy = const Value.absent(),
                Value<String?> approvedBy = const Value.absent(),
                Value<String?> voidedAt = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<String?> voidApprovedBy = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpensesCompanion.insert(
                id: id,
                locationId: locationId,
                amount: amount,
                currency: currency,
                category: category,
                paidFrom: paidFrom,
                wallet: wallet,
                note: note,
                spentAt: spentAt,
                createdBy: createdBy,
                approvedBy: approvedBy,
                voidedAt: voidedAt,
                voidReason: voidReason,
                voidApprovedBy: voidApprovedBy,
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

typedef $$ExpensesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExpensesTable,
      Expense,
      $$ExpensesTableFilterComposer,
      $$ExpensesTableOrderingComposer,
      $$ExpensesTableAnnotationComposer,
      $$ExpensesTableCreateCompanionBuilder,
      $$ExpensesTableUpdateCompanionBuilder,
      (Expense, BaseReferences<_$AppDatabase, $ExpensesTable, Expense>),
      Expense,
      PrefetchHooks Function()
    >;
typedef $$DayClosesTableCreateCompanionBuilder =
    DayClosesCompanion Function({
      required String id,
      Value<String?> locationId,
      required String day,
      required String currency,
      required int expectedCash,
      required int countedCash,
      required int difference,
      Value<int?> serverExpectedCash,
      Value<String?> note,
      Value<String?> closedBy,
      Value<String?> approvedBy,
      required String closedAt,
      Value<String?> updatedAt,
      Value<int> openingCash,
      Value<int> rowid,
    });
typedef $$DayClosesTableUpdateCompanionBuilder =
    DayClosesCompanion Function({
      Value<String> id,
      Value<String?> locationId,
      Value<String> day,
      Value<String> currency,
      Value<int> expectedCash,
      Value<int> countedCash,
      Value<int> difference,
      Value<int?> serverExpectedCash,
      Value<String?> note,
      Value<String?> closedBy,
      Value<String?> approvedBy,
      Value<String> closedAt,
      Value<String?> updatedAt,
      Value<int> openingCash,
      Value<int> rowid,
    });

class $$DayClosesTableFilterComposer
    extends Composer<_$AppDatabase, $DayClosesTable> {
  $$DayClosesTableFilterComposer({
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

  ColumnFilters<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedCash => $composableBuilder(
    column: $table.expectedCash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get countedCash => $composableBuilder(
    column: $table.countedCash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get difference => $composableBuilder(
    column: $table.difference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverExpectedCash => $composableBuilder(
    column: $table.serverExpectedCash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get closedBy => $composableBuilder(
    column: $table.closedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get approvedBy => $composableBuilder(
    column: $table.approvedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get openingCash => $composableBuilder(
    column: $table.openingCash,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DayClosesTableOrderingComposer
    extends Composer<_$AppDatabase, $DayClosesTable> {
  $$DayClosesTableOrderingComposer({
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

  ColumnOrderings<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedCash => $composableBuilder(
    column: $table.expectedCash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get countedCash => $composableBuilder(
    column: $table.countedCash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get difference => $composableBuilder(
    column: $table.difference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverExpectedCash => $composableBuilder(
    column: $table.serverExpectedCash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get closedBy => $composableBuilder(
    column: $table.closedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get approvedBy => $composableBuilder(
    column: $table.approvedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openingCash => $composableBuilder(
    column: $table.openingCash,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DayClosesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DayClosesTable> {
  $$DayClosesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get expectedCash => $composableBuilder(
    column: $table.expectedCash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get countedCash => $composableBuilder(
    column: $table.countedCash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get difference => $composableBuilder(
    column: $table.difference,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverExpectedCash => $composableBuilder(
    column: $table.serverExpectedCash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get closedBy =>
      $composableBuilder(column: $table.closedBy, builder: (column) => column);

  GeneratedColumn<String> get approvedBy => $composableBuilder(
    column: $table.approvedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get closedAt =>
      $composableBuilder(column: $table.closedAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get openingCash => $composableBuilder(
    column: $table.openingCash,
    builder: (column) => column,
  );
}

class $$DayClosesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DayClosesTable,
          DayClose,
          $$DayClosesTableFilterComposer,
          $$DayClosesTableOrderingComposer,
          $$DayClosesTableAnnotationComposer,
          $$DayClosesTableCreateCompanionBuilder,
          $$DayClosesTableUpdateCompanionBuilder,
          (DayClose, BaseReferences<_$AppDatabase, $DayClosesTable, DayClose>),
          DayClose,
          PrefetchHooks Function()
        > {
  $$DayClosesTableTableManager(_$AppDatabase db, $DayClosesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DayClosesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DayClosesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DayClosesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> locationId = const Value.absent(),
                Value<String> day = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int> expectedCash = const Value.absent(),
                Value<int> countedCash = const Value.absent(),
                Value<int> difference = const Value.absent(),
                Value<int?> serverExpectedCash = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> closedBy = const Value.absent(),
                Value<String?> approvedBy = const Value.absent(),
                Value<String> closedAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> openingCash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayClosesCompanion(
                id: id,
                locationId: locationId,
                day: day,
                currency: currency,
                expectedCash: expectedCash,
                countedCash: countedCash,
                difference: difference,
                serverExpectedCash: serverExpectedCash,
                note: note,
                closedBy: closedBy,
                approvedBy: approvedBy,
                closedAt: closedAt,
                updatedAt: updatedAt,
                openingCash: openingCash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> locationId = const Value.absent(),
                required String day,
                required String currency,
                required int expectedCash,
                required int countedCash,
                required int difference,
                Value<int?> serverExpectedCash = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> closedBy = const Value.absent(),
                Value<String?> approvedBy = const Value.absent(),
                required String closedAt,
                Value<String?> updatedAt = const Value.absent(),
                Value<int> openingCash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayClosesCompanion.insert(
                id: id,
                locationId: locationId,
                day: day,
                currency: currency,
                expectedCash: expectedCash,
                countedCash: countedCash,
                difference: difference,
                serverExpectedCash: serverExpectedCash,
                note: note,
                closedBy: closedBy,
                approvedBy: approvedBy,
                closedAt: closedAt,
                updatedAt: updatedAt,
                openingCash: openingCash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DayClosesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DayClosesTable,
      DayClose,
      $$DayClosesTableFilterComposer,
      $$DayClosesTableOrderingComposer,
      $$DayClosesTableAnnotationComposer,
      $$DayClosesTableCreateCompanionBuilder,
      $$DayClosesTableUpdateCompanionBuilder,
      (DayClose, BaseReferences<_$AppDatabase, $DayClosesTable, DayClose>),
      DayClose,
      PrefetchHooks Function()
    >;
typedef $$ServiceTxnsTableCreateCompanionBuilder =
    ServiceTxnsCompanion Function({
      required String id,
      Value<String?> locationId,
      required String kind,
      required String wallet,
      required int amount,
      Value<int> fee,
      Value<int?> price,
      required String currency,
      Value<String?> ref,
      Value<String?> note,
      required String txnAt,
      Value<String?> createdBy,
      Value<String?> approvedBy,
      Value<String?> voidedAt,
      Value<String?> voidReason,
      Value<String?> voidApprovedBy,
      Value<String?> updatedAt,
      Value<int> rowid,
    });
typedef $$ServiceTxnsTableUpdateCompanionBuilder =
    ServiceTxnsCompanion Function({
      Value<String> id,
      Value<String?> locationId,
      Value<String> kind,
      Value<String> wallet,
      Value<int> amount,
      Value<int> fee,
      Value<int?> price,
      Value<String> currency,
      Value<String?> ref,
      Value<String?> note,
      Value<String> txnAt,
      Value<String?> createdBy,
      Value<String?> approvedBy,
      Value<String?> voidedAt,
      Value<String?> voidReason,
      Value<String?> voidApprovedBy,
      Value<String?> updatedAt,
      Value<int> rowid,
    });

class $$ServiceTxnsTableFilterComposer
    extends Composer<_$AppDatabase, $ServiceTxnsTable> {
  $$ServiceTxnsTableFilterComposer({
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

  ColumnFilters<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wallet => $composableBuilder(
    column: $table.wallet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fee => $composableBuilder(
    column: $table.fee,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ref => $composableBuilder(
    column: $table.ref,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get txnAt => $composableBuilder(
    column: $table.txnAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get approvedBy => $composableBuilder(
    column: $table.approvedBy,
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

  ColumnFilters<String> get voidApprovedBy => $composableBuilder(
    column: $table.voidApprovedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ServiceTxnsTableOrderingComposer
    extends Composer<_$AppDatabase, $ServiceTxnsTable> {
  $$ServiceTxnsTableOrderingComposer({
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

  ColumnOrderings<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wallet => $composableBuilder(
    column: $table.wallet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fee => $composableBuilder(
    column: $table.fee,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ref => $composableBuilder(
    column: $table.ref,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get txnAt => $composableBuilder(
    column: $table.txnAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get approvedBy => $composableBuilder(
    column: $table.approvedBy,
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

  ColumnOrderings<String> get voidApprovedBy => $composableBuilder(
    column: $table.voidApprovedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ServiceTxnsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServiceTxnsTable> {
  $$ServiceTxnsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get wallet =>
      $composableBuilder(column: $table.wallet, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<int> get fee =>
      $composableBuilder(column: $table.fee, builder: (column) => column);

  GeneratedColumn<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get ref =>
      $composableBuilder(column: $table.ref, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get txnAt =>
      $composableBuilder(column: $table.txnAt, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get approvedBy => $composableBuilder(
    column: $table.approvedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get voidedAt =>
      $composableBuilder(column: $table.voidedAt, builder: (column) => column);

  GeneratedColumn<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => column,
  );

  GeneratedColumn<String> get voidApprovedBy => $composableBuilder(
    column: $table.voidApprovedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ServiceTxnsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ServiceTxnsTable,
          ServiceTxn,
          $$ServiceTxnsTableFilterComposer,
          $$ServiceTxnsTableOrderingComposer,
          $$ServiceTxnsTableAnnotationComposer,
          $$ServiceTxnsTableCreateCompanionBuilder,
          $$ServiceTxnsTableUpdateCompanionBuilder,
          (
            ServiceTxn,
            BaseReferences<_$AppDatabase, $ServiceTxnsTable, ServiceTxn>,
          ),
          ServiceTxn,
          PrefetchHooks Function()
        > {
  $$ServiceTxnsTableTableManager(_$AppDatabase db, $ServiceTxnsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServiceTxnsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServiceTxnsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServiceTxnsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> locationId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> wallet = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<int> fee = const Value.absent(),
                Value<int?> price = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> ref = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> txnAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> approvedBy = const Value.absent(),
                Value<String?> voidedAt = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<String?> voidApprovedBy = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServiceTxnsCompanion(
                id: id,
                locationId: locationId,
                kind: kind,
                wallet: wallet,
                amount: amount,
                fee: fee,
                price: price,
                currency: currency,
                ref: ref,
                note: note,
                txnAt: txnAt,
                createdBy: createdBy,
                approvedBy: approvedBy,
                voidedAt: voidedAt,
                voidReason: voidReason,
                voidApprovedBy: voidApprovedBy,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> locationId = const Value.absent(),
                required String kind,
                required String wallet,
                required int amount,
                Value<int> fee = const Value.absent(),
                Value<int?> price = const Value.absent(),
                required String currency,
                Value<String?> ref = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required String txnAt,
                Value<String?> createdBy = const Value.absent(),
                Value<String?> approvedBy = const Value.absent(),
                Value<String?> voidedAt = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<String?> voidApprovedBy = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServiceTxnsCompanion.insert(
                id: id,
                locationId: locationId,
                kind: kind,
                wallet: wallet,
                amount: amount,
                fee: fee,
                price: price,
                currency: currency,
                ref: ref,
                note: note,
                txnAt: txnAt,
                createdBy: createdBy,
                approvedBy: approvedBy,
                voidedAt: voidedAt,
                voidReason: voidReason,
                voidApprovedBy: voidApprovedBy,
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

typedef $$ServiceTxnsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ServiceTxnsTable,
      ServiceTxn,
      $$ServiceTxnsTableFilterComposer,
      $$ServiceTxnsTableOrderingComposer,
      $$ServiceTxnsTableAnnotationComposer,
      $$ServiceTxnsTableCreateCompanionBuilder,
      $$ServiceTxnsTableUpdateCompanionBuilder,
      (
        ServiceTxn,
        BaseReferences<_$AppDatabase, $ServiceTxnsTable, ServiceTxn>,
      ),
      ServiceTxn,
      PrefetchHooks Function()
    >;
typedef $$WalletFloatsTableCreateCompanionBuilder =
    WalletFloatsCompanion Function({
      required String locationId,
      required String wallet,
      required int balance,
      Value<int> txnCount,
      Value<String?> updatedAt,
      Value<int> rowid,
    });
typedef $$WalletFloatsTableUpdateCompanionBuilder =
    WalletFloatsCompanion Function({
      Value<String> locationId,
      Value<String> wallet,
      Value<int> balance,
      Value<int> txnCount,
      Value<String?> updatedAt,
      Value<int> rowid,
    });

class $$WalletFloatsTableFilterComposer
    extends Composer<_$AppDatabase, $WalletFloatsTable> {
  $$WalletFloatsTableFilterComposer({
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

  ColumnFilters<String> get wallet => $composableBuilder(
    column: $table.wallet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get balance => $composableBuilder(
    column: $table.balance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get txnCount => $composableBuilder(
    column: $table.txnCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WalletFloatsTableOrderingComposer
    extends Composer<_$AppDatabase, $WalletFloatsTable> {
  $$WalletFloatsTableOrderingComposer({
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

  ColumnOrderings<String> get wallet => $composableBuilder(
    column: $table.wallet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get balance => $composableBuilder(
    column: $table.balance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get txnCount => $composableBuilder(
    column: $table.txnCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WalletFloatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WalletFloatsTable> {
  $$WalletFloatsTableAnnotationComposer({
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

  GeneratedColumn<String> get wallet =>
      $composableBuilder(column: $table.wallet, builder: (column) => column);

  GeneratedColumn<int> get balance =>
      $composableBuilder(column: $table.balance, builder: (column) => column);

  GeneratedColumn<int> get txnCount =>
      $composableBuilder(column: $table.txnCount, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$WalletFloatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WalletFloatsTable,
          WalletFloat,
          $$WalletFloatsTableFilterComposer,
          $$WalletFloatsTableOrderingComposer,
          $$WalletFloatsTableAnnotationComposer,
          $$WalletFloatsTableCreateCompanionBuilder,
          $$WalletFloatsTableUpdateCompanionBuilder,
          (
            WalletFloat,
            BaseReferences<_$AppDatabase, $WalletFloatsTable, WalletFloat>,
          ),
          WalletFloat,
          PrefetchHooks Function()
        > {
  $$WalletFloatsTableTableManager(_$AppDatabase db, $WalletFloatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletFloatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletFloatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalletFloatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> locationId = const Value.absent(),
                Value<String> wallet = const Value.absent(),
                Value<int> balance = const Value.absent(),
                Value<int> txnCount = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletFloatsCompanion(
                locationId: locationId,
                wallet: wallet,
                balance: balance,
                txnCount: txnCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String locationId,
                required String wallet,
                required int balance,
                Value<int> txnCount = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletFloatsCompanion.insert(
                locationId: locationId,
                wallet: wallet,
                balance: balance,
                txnCount: txnCount,
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

typedef $$WalletFloatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WalletFloatsTable,
      WalletFloat,
      $$WalletFloatsTableFilterComposer,
      $$WalletFloatsTableOrderingComposer,
      $$WalletFloatsTableAnnotationComposer,
      $$WalletFloatsTableCreateCompanionBuilder,
      $$WalletFloatsTableUpdateCompanionBuilder,
      (
        WalletFloat,
        BaseReferences<_$AppDatabase, $WalletFloatsTable, WalletFloat>,
      ),
      WalletFloat,
      PrefetchHooks Function()
    >;
typedef $$LocalFloatEffectsTableCreateCompanionBuilder =
    LocalFloatEffectsCompanion Function({
      Value<int> id,
      required String opId,
      required String txnId,
      required String wallet,
      required int amount,
      Value<String?> confirmedAfter,
      Value<String?> locationId,
    });
typedef $$LocalFloatEffectsTableUpdateCompanionBuilder =
    LocalFloatEffectsCompanion Function({
      Value<int> id,
      Value<String> opId,
      Value<String> txnId,
      Value<String> wallet,
      Value<int> amount,
      Value<String?> confirmedAfter,
      Value<String?> locationId,
    });

class $$LocalFloatEffectsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalFloatEffectsTable> {
  $$LocalFloatEffectsTableFilterComposer({
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

  ColumnFilters<String> get txnId => $composableBuilder(
    column: $table.txnId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wallet => $composableBuilder(
    column: $table.wallet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confirmedAfter => $composableBuilder(
    column: $table.confirmedAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalFloatEffectsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalFloatEffectsTable> {
  $$LocalFloatEffectsTableOrderingComposer({
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

  ColumnOrderings<String> get txnId => $composableBuilder(
    column: $table.txnId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wallet => $composableBuilder(
    column: $table.wallet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confirmedAfter => $composableBuilder(
    column: $table.confirmedAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalFloatEffectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalFloatEffectsTable> {
  $$LocalFloatEffectsTableAnnotationComposer({
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

  GeneratedColumn<String> get txnId =>
      $composableBuilder(column: $table.txnId, builder: (column) => column);

  GeneratedColumn<String> get wallet =>
      $composableBuilder(column: $table.wallet, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get confirmedAfter => $composableBuilder(
    column: $table.confirmedAfter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => column,
  );
}

class $$LocalFloatEffectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalFloatEffectsTable,
          LocalFloatEffect,
          $$LocalFloatEffectsTableFilterComposer,
          $$LocalFloatEffectsTableOrderingComposer,
          $$LocalFloatEffectsTableAnnotationComposer,
          $$LocalFloatEffectsTableCreateCompanionBuilder,
          $$LocalFloatEffectsTableUpdateCompanionBuilder,
          (
            LocalFloatEffect,
            BaseReferences<
              _$AppDatabase,
              $LocalFloatEffectsTable,
              LocalFloatEffect
            >,
          ),
          LocalFloatEffect,
          PrefetchHooks Function()
        > {
  $$LocalFloatEffectsTableTableManager(
    _$AppDatabase db,
    $LocalFloatEffectsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalFloatEffectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalFloatEffectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalFloatEffectsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> opId = const Value.absent(),
                Value<String> txnId = const Value.absent(),
                Value<String> wallet = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String?> confirmedAfter = const Value.absent(),
                Value<String?> locationId = const Value.absent(),
              }) => LocalFloatEffectsCompanion(
                id: id,
                opId: opId,
                txnId: txnId,
                wallet: wallet,
                amount: amount,
                confirmedAfter: confirmedAfter,
                locationId: locationId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String opId,
                required String txnId,
                required String wallet,
                required int amount,
                Value<String?> confirmedAfter = const Value.absent(),
                Value<String?> locationId = const Value.absent(),
              }) => LocalFloatEffectsCompanion.insert(
                id: id,
                opId: opId,
                txnId: txnId,
                wallet: wallet,
                amount: amount,
                confirmedAfter: confirmedAfter,
                locationId: locationId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalFloatEffectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalFloatEffectsTable,
      LocalFloatEffect,
      $$LocalFloatEffectsTableFilterComposer,
      $$LocalFloatEffectsTableOrderingComposer,
      $$LocalFloatEffectsTableAnnotationComposer,
      $$LocalFloatEffectsTableCreateCompanionBuilder,
      $$LocalFloatEffectsTableUpdateCompanionBuilder,
      (
        LocalFloatEffect,
        BaseReferences<
          _$AppDatabase,
          $LocalFloatEffectsTable,
          LocalFloatEffect
        >,
      ),
      LocalFloatEffect,
      PrefetchHooks Function()
    >;
typedef $$ConversionsTableCreateCompanionBuilder =
    ConversionsCompanion Function({
      required String id,
      Value<String?> locationId,
      required String packVariantId,
      required String pieceVariantId,
      required int packs,
      required int ratio,
      required int pieces,
      Value<int?> packCost,
      Value<int?> totalCost,
      Value<int?> pieceCost,
      Value<String?> note,
      required String convertedAt,
      Value<String?> createdBy,
      Value<String?> voidedAt,
      Value<String?> voidReason,
      Value<String?> updatedAt,
      Value<int> rowid,
    });
typedef $$ConversionsTableUpdateCompanionBuilder =
    ConversionsCompanion Function({
      Value<String> id,
      Value<String?> locationId,
      Value<String> packVariantId,
      Value<String> pieceVariantId,
      Value<int> packs,
      Value<int> ratio,
      Value<int> pieces,
      Value<int?> packCost,
      Value<int?> totalCost,
      Value<int?> pieceCost,
      Value<String?> note,
      Value<String> convertedAt,
      Value<String?> createdBy,
      Value<String?> voidedAt,
      Value<String?> voidReason,
      Value<String?> updatedAt,
      Value<int> rowid,
    });

class $$ConversionsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversionsTable> {
  $$ConversionsTableFilterComposer({
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

  ColumnFilters<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packVariantId => $composableBuilder(
    column: $table.packVariantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pieceVariantId => $composableBuilder(
    column: $table.pieceVariantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get packs => $composableBuilder(
    column: $table.packs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ratio => $composableBuilder(
    column: $table.ratio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pieces => $composableBuilder(
    column: $table.pieces,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get packCost => $composableBuilder(
    column: $table.packCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalCost => $composableBuilder(
    column: $table.totalCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pieceCost => $composableBuilder(
    column: $table.pieceCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get convertedAt => $composableBuilder(
    column: $table.convertedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
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

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversionsTable> {
  $$ConversionsTableOrderingComposer({
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

  ColumnOrderings<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packVariantId => $composableBuilder(
    column: $table.packVariantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pieceVariantId => $composableBuilder(
    column: $table.pieceVariantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get packs => $composableBuilder(
    column: $table.packs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ratio => $composableBuilder(
    column: $table.ratio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pieces => $composableBuilder(
    column: $table.pieces,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get packCost => $composableBuilder(
    column: $table.packCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalCost => $composableBuilder(
    column: $table.totalCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pieceCost => $composableBuilder(
    column: $table.pieceCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get convertedAt => $composableBuilder(
    column: $table.convertedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
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

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversionsTable> {
  $$ConversionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get packVariantId => $composableBuilder(
    column: $table.packVariantId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pieceVariantId => $composableBuilder(
    column: $table.pieceVariantId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get packs =>
      $composableBuilder(column: $table.packs, builder: (column) => column);

  GeneratedColumn<int> get ratio =>
      $composableBuilder(column: $table.ratio, builder: (column) => column);

  GeneratedColumn<int> get pieces =>
      $composableBuilder(column: $table.pieces, builder: (column) => column);

  GeneratedColumn<int> get packCost =>
      $composableBuilder(column: $table.packCost, builder: (column) => column);

  GeneratedColumn<int> get totalCost =>
      $composableBuilder(column: $table.totalCost, builder: (column) => column);

  GeneratedColumn<int> get pieceCost =>
      $composableBuilder(column: $table.pieceCost, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get convertedAt => $composableBuilder(
    column: $table.convertedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get voidedAt =>
      $composableBuilder(column: $table.voidedAt, builder: (column) => column);

  GeneratedColumn<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ConversionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversionsTable,
          Conversion,
          $$ConversionsTableFilterComposer,
          $$ConversionsTableOrderingComposer,
          $$ConversionsTableAnnotationComposer,
          $$ConversionsTableCreateCompanionBuilder,
          $$ConversionsTableUpdateCompanionBuilder,
          (
            Conversion,
            BaseReferences<_$AppDatabase, $ConversionsTable, Conversion>,
          ),
          Conversion,
          PrefetchHooks Function()
        > {
  $$ConversionsTableTableManager(_$AppDatabase db, $ConversionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> locationId = const Value.absent(),
                Value<String> packVariantId = const Value.absent(),
                Value<String> pieceVariantId = const Value.absent(),
                Value<int> packs = const Value.absent(),
                Value<int> ratio = const Value.absent(),
                Value<int> pieces = const Value.absent(),
                Value<int?> packCost = const Value.absent(),
                Value<int?> totalCost = const Value.absent(),
                Value<int?> pieceCost = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> convertedAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> voidedAt = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversionsCompanion(
                id: id,
                locationId: locationId,
                packVariantId: packVariantId,
                pieceVariantId: pieceVariantId,
                packs: packs,
                ratio: ratio,
                pieces: pieces,
                packCost: packCost,
                totalCost: totalCost,
                pieceCost: pieceCost,
                note: note,
                convertedAt: convertedAt,
                createdBy: createdBy,
                voidedAt: voidedAt,
                voidReason: voidReason,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> locationId = const Value.absent(),
                required String packVariantId,
                required String pieceVariantId,
                required int packs,
                required int ratio,
                required int pieces,
                Value<int?> packCost = const Value.absent(),
                Value<int?> totalCost = const Value.absent(),
                Value<int?> pieceCost = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required String convertedAt,
                Value<String?> createdBy = const Value.absent(),
                Value<String?> voidedAt = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversionsCompanion.insert(
                id: id,
                locationId: locationId,
                packVariantId: packVariantId,
                pieceVariantId: pieceVariantId,
                packs: packs,
                ratio: ratio,
                pieces: pieces,
                packCost: packCost,
                totalCost: totalCost,
                pieceCost: pieceCost,
                note: note,
                convertedAt: convertedAt,
                createdBy: createdBy,
                voidedAt: voidedAt,
                voidReason: voidReason,
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

typedef $$ConversionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversionsTable,
      Conversion,
      $$ConversionsTableFilterComposer,
      $$ConversionsTableOrderingComposer,
      $$ConversionsTableAnnotationComposer,
      $$ConversionsTableCreateCompanionBuilder,
      $$ConversionsTableUpdateCompanionBuilder,
      (
        Conversion,
        BaseReferences<_$AppDatabase, $ConversionsTable, Conversion>,
      ),
      Conversion,
      PrefetchHooks Function()
    >;
typedef $$StockExpiryTableCreateCompanionBuilder =
    StockExpiryCompanion Function({
      required String variantId,
      Value<String> locationId,
      Value<String?> expiresOn,
      Value<String?> updatedAt,
      Value<int> rowid,
    });
typedef $$StockExpiryTableUpdateCompanionBuilder =
    StockExpiryCompanion Function({
      Value<String> variantId,
      Value<String> locationId,
      Value<String?> expiresOn,
      Value<String?> updatedAt,
      Value<int> rowid,
    });

class $$StockExpiryTableFilterComposer
    extends Composer<_$AppDatabase, $StockExpiryTable> {
  $$StockExpiryTableFilterComposer({
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

  ColumnFilters<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expiresOn => $composableBuilder(
    column: $table.expiresOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StockExpiryTableOrderingComposer
    extends Composer<_$AppDatabase, $StockExpiryTable> {
  $$StockExpiryTableOrderingComposer({
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

  ColumnOrderings<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expiresOn => $composableBuilder(
    column: $table.expiresOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StockExpiryTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockExpiryTable> {
  $$StockExpiryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get variantId =>
      $composableBuilder(column: $table.variantId, builder: (column) => column);

  GeneratedColumn<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get expiresOn =>
      $composableBuilder(column: $table.expiresOn, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StockExpiryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StockExpiryTable,
          StockExpiryData,
          $$StockExpiryTableFilterComposer,
          $$StockExpiryTableOrderingComposer,
          $$StockExpiryTableAnnotationComposer,
          $$StockExpiryTableCreateCompanionBuilder,
          $$StockExpiryTableUpdateCompanionBuilder,
          (
            StockExpiryData,
            BaseReferences<_$AppDatabase, $StockExpiryTable, StockExpiryData>,
          ),
          StockExpiryData,
          PrefetchHooks Function()
        > {
  $$StockExpiryTableTableManager(_$AppDatabase db, $StockExpiryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockExpiryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockExpiryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockExpiryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> variantId = const Value.absent(),
                Value<String> locationId = const Value.absent(),
                Value<String?> expiresOn = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StockExpiryCompanion(
                variantId: variantId,
                locationId: locationId,
                expiresOn: expiresOn,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String variantId,
                Value<String> locationId = const Value.absent(),
                Value<String?> expiresOn = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StockExpiryCompanion.insert(
                variantId: variantId,
                locationId: locationId,
                expiresOn: expiresOn,
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

typedef $$StockExpiryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StockExpiryTable,
      StockExpiryData,
      $$StockExpiryTableFilterComposer,
      $$StockExpiryTableOrderingComposer,
      $$StockExpiryTableAnnotationComposer,
      $$StockExpiryTableCreateCompanionBuilder,
      $$StockExpiryTableUpdateCompanionBuilder,
      (
        StockExpiryData,
        BaseReferences<_$AppDatabase, $StockExpiryTable, StockExpiryData>,
      ),
      StockExpiryData,
      PrefetchHooks Function()
    >;
typedef $$WarehousesTableCreateCompanionBuilder =
    WarehousesCompanion Function({
      required String id,
      required String code,
      required String name,
      Value<bool> binsEnabled,
      Value<bool> active,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$WarehousesTableUpdateCompanionBuilder =
    WarehousesCompanion Function({
      Value<String> id,
      Value<String> code,
      Value<String> name,
      Value<bool> binsEnabled,
      Value<bool> active,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$WarehousesTableFilterComposer
    extends Composer<_$AppDatabase, $WarehousesTable> {
  $$WarehousesTableFilterComposer({
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

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get binsEnabled => $composableBuilder(
    column: $table.binsEnabled,
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

class $$WarehousesTableOrderingComposer
    extends Composer<_$AppDatabase, $WarehousesTable> {
  $$WarehousesTableOrderingComposer({
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

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get binsEnabled => $composableBuilder(
    column: $table.binsEnabled,
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

class $$WarehousesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WarehousesTable> {
  $$WarehousesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get binsEnabled => $composableBuilder(
    column: $table.binsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$WarehousesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WarehousesTable,
          Warehouse,
          $$WarehousesTableFilterComposer,
          $$WarehousesTableOrderingComposer,
          $$WarehousesTableAnnotationComposer,
          $$WarehousesTableCreateCompanionBuilder,
          $$WarehousesTableUpdateCompanionBuilder,
          (
            Warehouse,
            BaseReferences<_$AppDatabase, $WarehousesTable, Warehouse>,
          ),
          Warehouse,
          PrefetchHooks Function()
        > {
  $$WarehousesTableTableManager(_$AppDatabase db, $WarehousesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WarehousesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WarehousesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WarehousesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> binsEnabled = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WarehousesCompanion(
                id: id,
                code: code,
                name: name,
                binsEnabled: binsEnabled,
                active: active,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String code,
                required String name,
                Value<bool> binsEnabled = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WarehousesCompanion.insert(
                id: id,
                code: code,
                name: name,
                binsEnabled: binsEnabled,
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

typedef $$WarehousesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WarehousesTable,
      Warehouse,
      $$WarehousesTableFilterComposer,
      $$WarehousesTableOrderingComposer,
      $$WarehousesTableAnnotationComposer,
      $$WarehousesTableCreateCompanionBuilder,
      $$WarehousesTableUpdateCompanionBuilder,
      (Warehouse, BaseReferences<_$AppDatabase, $WarehousesTable, Warehouse>),
      Warehouse,
      PrefetchHooks Function()
    >;
typedef $$WhBinsTableCreateCompanionBuilder =
    WhBinsCompanion Function({
      required String id,
      required String warehouseId,
      Value<String?> zoneId,
      required String code,
      Value<String?> aisle,
      Value<String?> rack,
      Value<String?> shelf,
      Value<String?> position,
      Value<String> type,
      Value<double?> maxQty,
      Value<bool> active,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$WhBinsTableUpdateCompanionBuilder =
    WhBinsCompanion Function({
      Value<String> id,
      Value<String> warehouseId,
      Value<String?> zoneId,
      Value<String> code,
      Value<String?> aisle,
      Value<String?> rack,
      Value<String?> shelf,
      Value<String?> position,
      Value<String> type,
      Value<double?> maxQty,
      Value<bool> active,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$WhBinsTableFilterComposer
    extends Composer<_$AppDatabase, $WhBinsTable> {
  $$WhBinsTableFilterComposer({
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

  ColumnFilters<String> get warehouseId => $composableBuilder(
    column: $table.warehouseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get zoneId => $composableBuilder(
    column: $table.zoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aisle => $composableBuilder(
    column: $table.aisle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rack => $composableBuilder(
    column: $table.rack,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shelf => $composableBuilder(
    column: $table.shelf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxQty => $composableBuilder(
    column: $table.maxQty,
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

class $$WhBinsTableOrderingComposer
    extends Composer<_$AppDatabase, $WhBinsTable> {
  $$WhBinsTableOrderingComposer({
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

  ColumnOrderings<String> get warehouseId => $composableBuilder(
    column: $table.warehouseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get zoneId => $composableBuilder(
    column: $table.zoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aisle => $composableBuilder(
    column: $table.aisle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rack => $composableBuilder(
    column: $table.rack,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shelf => $composableBuilder(
    column: $table.shelf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxQty => $composableBuilder(
    column: $table.maxQty,
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

class $$WhBinsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WhBinsTable> {
  $$WhBinsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get warehouseId => $composableBuilder(
    column: $table.warehouseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get zoneId =>
      $composableBuilder(column: $table.zoneId, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get aisle =>
      $composableBuilder(column: $table.aisle, builder: (column) => column);

  GeneratedColumn<String> get rack =>
      $composableBuilder(column: $table.rack, builder: (column) => column);

  GeneratedColumn<String> get shelf =>
      $composableBuilder(column: $table.shelf, builder: (column) => column);

  GeneratedColumn<String> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get maxQty =>
      $composableBuilder(column: $table.maxQty, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$WhBinsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WhBinsTable,
          WhBin,
          $$WhBinsTableFilterComposer,
          $$WhBinsTableOrderingComposer,
          $$WhBinsTableAnnotationComposer,
          $$WhBinsTableCreateCompanionBuilder,
          $$WhBinsTableUpdateCompanionBuilder,
          (WhBin, BaseReferences<_$AppDatabase, $WhBinsTable, WhBin>),
          WhBin,
          PrefetchHooks Function()
        > {
  $$WhBinsTableTableManager(_$AppDatabase db, $WhBinsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WhBinsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WhBinsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WhBinsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> warehouseId = const Value.absent(),
                Value<String?> zoneId = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String?> aisle = const Value.absent(),
                Value<String?> rack = const Value.absent(),
                Value<String?> shelf = const Value.absent(),
                Value<String?> position = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<double?> maxQty = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WhBinsCompanion(
                id: id,
                warehouseId: warehouseId,
                zoneId: zoneId,
                code: code,
                aisle: aisle,
                rack: rack,
                shelf: shelf,
                position: position,
                type: type,
                maxQty: maxQty,
                active: active,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String warehouseId,
                Value<String?> zoneId = const Value.absent(),
                required String code,
                Value<String?> aisle = const Value.absent(),
                Value<String?> rack = const Value.absent(),
                Value<String?> shelf = const Value.absent(),
                Value<String?> position = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<double?> maxQty = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WhBinsCompanion.insert(
                id: id,
                warehouseId: warehouseId,
                zoneId: zoneId,
                code: code,
                aisle: aisle,
                rack: rack,
                shelf: shelf,
                position: position,
                type: type,
                maxQty: maxQty,
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

typedef $$WhBinsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WhBinsTable,
      WhBin,
      $$WhBinsTableFilterComposer,
      $$WhBinsTableOrderingComposer,
      $$WhBinsTableAnnotationComposer,
      $$WhBinsTableCreateCompanionBuilder,
      $$WhBinsTableUpdateCompanionBuilder,
      (WhBin, BaseReferences<_$AppDatabase, $WhBinsTable, WhBin>),
      WhBin,
      PrefetchHooks Function()
    >;
typedef $$WhBinStockTableCreateCompanionBuilder =
    WhBinStockCompanion Function({
      required String binId,
      required String variantId,
      required double qty,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$WhBinStockTableUpdateCompanionBuilder =
    WhBinStockCompanion Function({
      Value<String> binId,
      Value<String> variantId,
      Value<double> qty,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$WhBinStockTableFilterComposer
    extends Composer<_$AppDatabase, $WhBinStockTable> {
  $$WhBinStockTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get binId => $composableBuilder(
    column: $table.binId,
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

class $$WhBinStockTableOrderingComposer
    extends Composer<_$AppDatabase, $WhBinStockTable> {
  $$WhBinStockTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get binId => $composableBuilder(
    column: $table.binId,
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

class $$WhBinStockTableAnnotationComposer
    extends Composer<_$AppDatabase, $WhBinStockTable> {
  $$WhBinStockTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get binId =>
      $composableBuilder(column: $table.binId, builder: (column) => column);

  GeneratedColumn<String> get variantId =>
      $composableBuilder(column: $table.variantId, builder: (column) => column);

  GeneratedColumn<double> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$WhBinStockTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WhBinStockTable,
          WhBinStockData,
          $$WhBinStockTableFilterComposer,
          $$WhBinStockTableOrderingComposer,
          $$WhBinStockTableAnnotationComposer,
          $$WhBinStockTableCreateCompanionBuilder,
          $$WhBinStockTableUpdateCompanionBuilder,
          (
            WhBinStockData,
            BaseReferences<_$AppDatabase, $WhBinStockTable, WhBinStockData>,
          ),
          WhBinStockData,
          PrefetchHooks Function()
        > {
  $$WhBinStockTableTableManager(_$AppDatabase db, $WhBinStockTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WhBinStockTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WhBinStockTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WhBinStockTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> binId = const Value.absent(),
                Value<String> variantId = const Value.absent(),
                Value<double> qty = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WhBinStockCompanion(
                binId: binId,
                variantId: variantId,
                qty: qty,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String binId,
                required String variantId,
                required double qty,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WhBinStockCompanion.insert(
                binId: binId,
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

typedef $$WhBinStockTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WhBinStockTable,
      WhBinStockData,
      $$WhBinStockTableFilterComposer,
      $$WhBinStockTableOrderingComposer,
      $$WhBinStockTableAnnotationComposer,
      $$WhBinStockTableCreateCompanionBuilder,
      $$WhBinStockTableUpdateCompanionBuilder,
      (
        WhBinStockData,
        BaseReferences<_$AppDatabase, $WhBinStockTable, WhBinStockData>,
      ),
      WhBinStockData,
      PrefetchHooks Function()
    >;
typedef $$WhStockTableCreateCompanionBuilder =
    WhStockCompanion Function({
      required String locationId,
      required String variantId,
      required double qty,
      Value<int?> avgCost,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$WhStockTableUpdateCompanionBuilder =
    WhStockCompanion Function({
      Value<String> locationId,
      Value<String> variantId,
      Value<double> qty,
      Value<int?> avgCost,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$WhStockTableFilterComposer
    extends Composer<_$AppDatabase, $WhStockTable> {
  $$WhStockTableFilterComposer({
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

  ColumnFilters<int> get avgCost => $composableBuilder(
    column: $table.avgCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WhStockTableOrderingComposer
    extends Composer<_$AppDatabase, $WhStockTable> {
  $$WhStockTableOrderingComposer({
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

  ColumnOrderings<int> get avgCost => $composableBuilder(
    column: $table.avgCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WhStockTableAnnotationComposer
    extends Composer<_$AppDatabase, $WhStockTable> {
  $$WhStockTableAnnotationComposer({
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

  GeneratedColumn<int> get avgCost =>
      $composableBuilder(column: $table.avgCost, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$WhStockTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WhStockTable,
          WhStockData,
          $$WhStockTableFilterComposer,
          $$WhStockTableOrderingComposer,
          $$WhStockTableAnnotationComposer,
          $$WhStockTableCreateCompanionBuilder,
          $$WhStockTableUpdateCompanionBuilder,
          (
            WhStockData,
            BaseReferences<_$AppDatabase, $WhStockTable, WhStockData>,
          ),
          WhStockData,
          PrefetchHooks Function()
        > {
  $$WhStockTableTableManager(_$AppDatabase db, $WhStockTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WhStockTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WhStockTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WhStockTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> locationId = const Value.absent(),
                Value<String> variantId = const Value.absent(),
                Value<double> qty = const Value.absent(),
                Value<int?> avgCost = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WhStockCompanion(
                locationId: locationId,
                variantId: variantId,
                qty: qty,
                avgCost: avgCost,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String locationId,
                required String variantId,
                required double qty,
                Value<int?> avgCost = const Value.absent(),
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WhStockCompanion.insert(
                locationId: locationId,
                variantId: variantId,
                qty: qty,
                avgCost: avgCost,
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

typedef $$WhStockTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WhStockTable,
      WhStockData,
      $$WhStockTableFilterComposer,
      $$WhStockTableOrderingComposer,
      $$WhStockTableAnnotationComposer,
      $$WhStockTableCreateCompanionBuilder,
      $$WhStockTableUpdateCompanionBuilder,
      (WhStockData, BaseReferences<_$AppDatabase, $WhStockTable, WhStockData>),
      WhStockData,
      PrefetchHooks Function()
    >;
typedef $$SuppliersTableCreateCompanionBuilder =
    SuppliersCompanion Function({
      required String id,
      required String name,
      Value<String?> contactName,
      Value<String?> phone,
      Value<String?> email,
      Value<String?> notes,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$SuppliersTableUpdateCompanionBuilder =
    SuppliersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> contactName,
      Value<String?> phone,
      Value<String?> email,
      Value<String?> notes,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$SuppliersTableFilterComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableFilterComposer({
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

  ColumnFilters<String> get contactName => $composableBuilder(
    column: $table.contactName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
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

class $$SuppliersTableOrderingComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableOrderingComposer({
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

  ColumnOrderings<String> get contactName => $composableBuilder(
    column: $table.contactName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
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

class $$SuppliersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableAnnotationComposer({
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

  GeneratedColumn<String> get contactName => $composableBuilder(
    column: $table.contactName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$SuppliersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SuppliersTable,
          Supplier,
          $$SuppliersTableFilterComposer,
          $$SuppliersTableOrderingComposer,
          $$SuppliersTableAnnotationComposer,
          $$SuppliersTableCreateCompanionBuilder,
          $$SuppliersTableUpdateCompanionBuilder,
          (Supplier, BaseReferences<_$AppDatabase, $SuppliersTable, Supplier>),
          Supplier,
          PrefetchHooks Function()
        > {
  $$SuppliersTableTableManager(_$AppDatabase db, $SuppliersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SuppliersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SuppliersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SuppliersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> contactName = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SuppliersCompanion(
                id: id,
                name: name,
                contactName: contactName,
                phone: phone,
                email: email,
                notes: notes,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> contactName = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SuppliersCompanion.insert(
                id: id,
                name: name,
                contactName: contactName,
                phone: phone,
                email: email,
                notes: notes,
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

typedef $$SuppliersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SuppliersTable,
      Supplier,
      $$SuppliersTableFilterComposer,
      $$SuppliersTableOrderingComposer,
      $$SuppliersTableAnnotationComposer,
      $$SuppliersTableCreateCompanionBuilder,
      $$SuppliersTableUpdateCompanionBuilder,
      (Supplier, BaseReferences<_$AppDatabase, $SuppliersTable, Supplier>),
      Supplier,
      PrefetchHooks Function()
    >;
typedef $$PurchaseOrdersTableCreateCompanionBuilder =
    PurchaseOrdersCompanion Function({
      required String id,
      required String poNo,
      required String warehouseId,
      required String supplierId,
      required String status,
      Value<String?> expectedAt,
      Value<String?> notes,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$PurchaseOrdersTableUpdateCompanionBuilder =
    PurchaseOrdersCompanion Function({
      Value<String> id,
      Value<String> poNo,
      Value<String> warehouseId,
      Value<String> supplierId,
      Value<String> status,
      Value<String?> expectedAt,
      Value<String?> notes,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$PurchaseOrdersTableFilterComposer
    extends Composer<_$AppDatabase, $PurchaseOrdersTable> {
  $$PurchaseOrdersTableFilterComposer({
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

  ColumnFilters<String> get poNo => $composableBuilder(
    column: $table.poNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get warehouseId => $composableBuilder(
    column: $table.warehouseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supplierId => $composableBuilder(
    column: $table.supplierId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expectedAt => $composableBuilder(
    column: $table.expectedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PurchaseOrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $PurchaseOrdersTable> {
  $$PurchaseOrdersTableOrderingComposer({
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

  ColumnOrderings<String> get poNo => $composableBuilder(
    column: $table.poNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get warehouseId => $composableBuilder(
    column: $table.warehouseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supplierId => $composableBuilder(
    column: $table.supplierId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expectedAt => $composableBuilder(
    column: $table.expectedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PurchaseOrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PurchaseOrdersTable> {
  $$PurchaseOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get poNo =>
      $composableBuilder(column: $table.poNo, builder: (column) => column);

  GeneratedColumn<String> get warehouseId => $composableBuilder(
    column: $table.warehouseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get supplierId => $composableBuilder(
    column: $table.supplierId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get expectedAt => $composableBuilder(
    column: $table.expectedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PurchaseOrdersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PurchaseOrdersTable,
          PurchaseOrder,
          $$PurchaseOrdersTableFilterComposer,
          $$PurchaseOrdersTableOrderingComposer,
          $$PurchaseOrdersTableAnnotationComposer,
          $$PurchaseOrdersTableCreateCompanionBuilder,
          $$PurchaseOrdersTableUpdateCompanionBuilder,
          (
            PurchaseOrder,
            BaseReferences<_$AppDatabase, $PurchaseOrdersTable, PurchaseOrder>,
          ),
          PurchaseOrder,
          PrefetchHooks Function()
        > {
  $$PurchaseOrdersTableTableManager(
    _$AppDatabase db,
    $PurchaseOrdersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PurchaseOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PurchaseOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PurchaseOrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> poNo = const Value.absent(),
                Value<String> warehouseId = const Value.absent(),
                Value<String> supplierId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> expectedAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PurchaseOrdersCompanion(
                id: id,
                poNo: poNo,
                warehouseId: warehouseId,
                supplierId: supplierId,
                status: status,
                expectedAt: expectedAt,
                notes: notes,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String poNo,
                required String warehouseId,
                required String supplierId,
                required String status,
                Value<String?> expectedAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PurchaseOrdersCompanion.insert(
                id: id,
                poNo: poNo,
                warehouseId: warehouseId,
                supplierId: supplierId,
                status: status,
                expectedAt: expectedAt,
                notes: notes,
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

typedef $$PurchaseOrdersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PurchaseOrdersTable,
      PurchaseOrder,
      $$PurchaseOrdersTableFilterComposer,
      $$PurchaseOrdersTableOrderingComposer,
      $$PurchaseOrdersTableAnnotationComposer,
      $$PurchaseOrdersTableCreateCompanionBuilder,
      $$PurchaseOrdersTableUpdateCompanionBuilder,
      (
        PurchaseOrder,
        BaseReferences<_$AppDatabase, $PurchaseOrdersTable, PurchaseOrder>,
      ),
      PurchaseOrder,
      PrefetchHooks Function()
    >;
typedef $$PoItemsTableCreateCompanionBuilder =
    PoItemsCompanion Function({
      required String id,
      required String poId,
      required String variantId,
      required double qtyOrdered,
      required double qtyReceived,
      Value<int?> unitCost,
      Value<int> rowid,
    });
typedef $$PoItemsTableUpdateCompanionBuilder =
    PoItemsCompanion Function({
      Value<String> id,
      Value<String> poId,
      Value<String> variantId,
      Value<double> qtyOrdered,
      Value<double> qtyReceived,
      Value<int?> unitCost,
      Value<int> rowid,
    });

class $$PoItemsTableFilterComposer
    extends Composer<_$AppDatabase, $PoItemsTable> {
  $$PoItemsTableFilterComposer({
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

  ColumnFilters<String> get poId => $composableBuilder(
    column: $table.poId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variantId => $composableBuilder(
    column: $table.variantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get qtyOrdered => $composableBuilder(
    column: $table.qtyOrdered,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get qtyReceived => $composableBuilder(
    column: $table.qtyReceived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitCost => $composableBuilder(
    column: $table.unitCost,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PoItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $PoItemsTable> {
  $$PoItemsTableOrderingComposer({
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

  ColumnOrderings<String> get poId => $composableBuilder(
    column: $table.poId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variantId => $composableBuilder(
    column: $table.variantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get qtyOrdered => $composableBuilder(
    column: $table.qtyOrdered,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get qtyReceived => $composableBuilder(
    column: $table.qtyReceived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitCost => $composableBuilder(
    column: $table.unitCost,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PoItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PoItemsTable> {
  $$PoItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get poId =>
      $composableBuilder(column: $table.poId, builder: (column) => column);

  GeneratedColumn<String> get variantId =>
      $composableBuilder(column: $table.variantId, builder: (column) => column);

  GeneratedColumn<double> get qtyOrdered => $composableBuilder(
    column: $table.qtyOrdered,
    builder: (column) => column,
  );

  GeneratedColumn<double> get qtyReceived => $composableBuilder(
    column: $table.qtyReceived,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unitCost =>
      $composableBuilder(column: $table.unitCost, builder: (column) => column);
}

class $$PoItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PoItemsTable,
          PoItem,
          $$PoItemsTableFilterComposer,
          $$PoItemsTableOrderingComposer,
          $$PoItemsTableAnnotationComposer,
          $$PoItemsTableCreateCompanionBuilder,
          $$PoItemsTableUpdateCompanionBuilder,
          (PoItem, BaseReferences<_$AppDatabase, $PoItemsTable, PoItem>),
          PoItem,
          PrefetchHooks Function()
        > {
  $$PoItemsTableTableManager(_$AppDatabase db, $PoItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PoItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PoItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PoItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> poId = const Value.absent(),
                Value<String> variantId = const Value.absent(),
                Value<double> qtyOrdered = const Value.absent(),
                Value<double> qtyReceived = const Value.absent(),
                Value<int?> unitCost = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoItemsCompanion(
                id: id,
                poId: poId,
                variantId: variantId,
                qtyOrdered: qtyOrdered,
                qtyReceived: qtyReceived,
                unitCost: unitCost,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String poId,
                required String variantId,
                required double qtyOrdered,
                required double qtyReceived,
                Value<int?> unitCost = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoItemsCompanion.insert(
                id: id,
                poId: poId,
                variantId: variantId,
                qtyOrdered: qtyOrdered,
                qtyReceived: qtyReceived,
                unitCost: unitCost,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PoItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PoItemsTable,
      PoItem,
      $$PoItemsTableFilterComposer,
      $$PoItemsTableOrderingComposer,
      $$PoItemsTableAnnotationComposer,
      $$PoItemsTableCreateCompanionBuilder,
      $$PoItemsTableUpdateCompanionBuilder,
      (PoItem, BaseReferences<_$AppDatabase, $PoItemsTable, PoItem>),
      PoItem,
      PrefetchHooks Function()
    >;
typedef $$WhReceiptsTableCreateCompanionBuilder =
    WhReceiptsCompanion Function({
      required String opId,
      required String kind,
      required String warehouseId,
      Value<String?> poId,
      Value<String?> poNo,
      Value<String?> supplierId,
      Value<String?> deliveryRef,
      Value<String?> notes,
      required String createdAt,
      Value<String?> grnNo,
      Value<String?> confirmedAfter,
      Value<bool> settled,
      Value<int> rowid,
    });
typedef $$WhReceiptsTableUpdateCompanionBuilder =
    WhReceiptsCompanion Function({
      Value<String> opId,
      Value<String> kind,
      Value<String> warehouseId,
      Value<String?> poId,
      Value<String?> poNo,
      Value<String?> supplierId,
      Value<String?> deliveryRef,
      Value<String?> notes,
      Value<String> createdAt,
      Value<String?> grnNo,
      Value<String?> confirmedAfter,
      Value<bool> settled,
      Value<int> rowid,
    });

class $$WhReceiptsTableFilterComposer
    extends Composer<_$AppDatabase, $WhReceiptsTable> {
  $$WhReceiptsTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get warehouseId => $composableBuilder(
    column: $table.warehouseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get poId => $composableBuilder(
    column: $table.poId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get poNo => $composableBuilder(
    column: $table.poNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supplierId => $composableBuilder(
    column: $table.supplierId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deliveryRef => $composableBuilder(
    column: $table.deliveryRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get grnNo => $composableBuilder(
    column: $table.grnNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confirmedAfter => $composableBuilder(
    column: $table.confirmedAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get settled => $composableBuilder(
    column: $table.settled,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WhReceiptsTableOrderingComposer
    extends Composer<_$AppDatabase, $WhReceiptsTable> {
  $$WhReceiptsTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get warehouseId => $composableBuilder(
    column: $table.warehouseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get poId => $composableBuilder(
    column: $table.poId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get poNo => $composableBuilder(
    column: $table.poNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supplierId => $composableBuilder(
    column: $table.supplierId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deliveryRef => $composableBuilder(
    column: $table.deliveryRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get grnNo => $composableBuilder(
    column: $table.grnNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confirmedAfter => $composableBuilder(
    column: $table.confirmedAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get settled => $composableBuilder(
    column: $table.settled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WhReceiptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WhReceiptsTable> {
  $$WhReceiptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get opId =>
      $composableBuilder(column: $table.opId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get warehouseId => $composableBuilder(
    column: $table.warehouseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get poId =>
      $composableBuilder(column: $table.poId, builder: (column) => column);

  GeneratedColumn<String> get poNo =>
      $composableBuilder(column: $table.poNo, builder: (column) => column);

  GeneratedColumn<String> get supplierId => $composableBuilder(
    column: $table.supplierId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deliveryRef => $composableBuilder(
    column: $table.deliveryRef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get grnNo =>
      $composableBuilder(column: $table.grnNo, builder: (column) => column);

  GeneratedColumn<String> get confirmedAfter => $composableBuilder(
    column: $table.confirmedAfter,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get settled =>
      $composableBuilder(column: $table.settled, builder: (column) => column);
}

class $$WhReceiptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WhReceiptsTable,
          WhReceipt,
          $$WhReceiptsTableFilterComposer,
          $$WhReceiptsTableOrderingComposer,
          $$WhReceiptsTableAnnotationComposer,
          $$WhReceiptsTableCreateCompanionBuilder,
          $$WhReceiptsTableUpdateCompanionBuilder,
          (
            WhReceipt,
            BaseReferences<_$AppDatabase, $WhReceiptsTable, WhReceipt>,
          ),
          WhReceipt,
          PrefetchHooks Function()
        > {
  $$WhReceiptsTableTableManager(_$AppDatabase db, $WhReceiptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WhReceiptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WhReceiptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WhReceiptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> opId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> warehouseId = const Value.absent(),
                Value<String?> poId = const Value.absent(),
                Value<String?> poNo = const Value.absent(),
                Value<String?> supplierId = const Value.absent(),
                Value<String?> deliveryRef = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String?> grnNo = const Value.absent(),
                Value<String?> confirmedAfter = const Value.absent(),
                Value<bool> settled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WhReceiptsCompanion(
                opId: opId,
                kind: kind,
                warehouseId: warehouseId,
                poId: poId,
                poNo: poNo,
                supplierId: supplierId,
                deliveryRef: deliveryRef,
                notes: notes,
                createdAt: createdAt,
                grnNo: grnNo,
                confirmedAfter: confirmedAfter,
                settled: settled,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String opId,
                required String kind,
                required String warehouseId,
                Value<String?> poId = const Value.absent(),
                Value<String?> poNo = const Value.absent(),
                Value<String?> supplierId = const Value.absent(),
                Value<String?> deliveryRef = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required String createdAt,
                Value<String?> grnNo = const Value.absent(),
                Value<String?> confirmedAfter = const Value.absent(),
                Value<bool> settled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WhReceiptsCompanion.insert(
                opId: opId,
                kind: kind,
                warehouseId: warehouseId,
                poId: poId,
                poNo: poNo,
                supplierId: supplierId,
                deliveryRef: deliveryRef,
                notes: notes,
                createdAt: createdAt,
                grnNo: grnNo,
                confirmedAfter: confirmedAfter,
                settled: settled,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WhReceiptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WhReceiptsTable,
      WhReceipt,
      $$WhReceiptsTableFilterComposer,
      $$WhReceiptsTableOrderingComposer,
      $$WhReceiptsTableAnnotationComposer,
      $$WhReceiptsTableCreateCompanionBuilder,
      $$WhReceiptsTableUpdateCompanionBuilder,
      (WhReceipt, BaseReferences<_$AppDatabase, $WhReceiptsTable, WhReceipt>),
      WhReceipt,
      PrefetchHooks Function()
    >;
typedef $$WhReceiptItemsTableCreateCompanionBuilder =
    WhReceiptItemsCompanion Function({
      Value<int> id,
      required String opId,
      required String variantId,
      required double qty,
      Value<int?> unitCost,
    });
typedef $$WhReceiptItemsTableUpdateCompanionBuilder =
    WhReceiptItemsCompanion Function({
      Value<int> id,
      Value<String> opId,
      Value<String> variantId,
      Value<double> qty,
      Value<int?> unitCost,
    });

class $$WhReceiptItemsTableFilterComposer
    extends Composer<_$AppDatabase, $WhReceiptItemsTable> {
  $$WhReceiptItemsTableFilterComposer({
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

  ColumnFilters<int> get unitCost => $composableBuilder(
    column: $table.unitCost,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WhReceiptItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $WhReceiptItemsTable> {
  $$WhReceiptItemsTableOrderingComposer({
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

  ColumnOrderings<int> get unitCost => $composableBuilder(
    column: $table.unitCost,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WhReceiptItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WhReceiptItemsTable> {
  $$WhReceiptItemsTableAnnotationComposer({
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

  GeneratedColumn<int> get unitCost =>
      $composableBuilder(column: $table.unitCost, builder: (column) => column);
}

class $$WhReceiptItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WhReceiptItemsTable,
          WhReceiptItem,
          $$WhReceiptItemsTableFilterComposer,
          $$WhReceiptItemsTableOrderingComposer,
          $$WhReceiptItemsTableAnnotationComposer,
          $$WhReceiptItemsTableCreateCompanionBuilder,
          $$WhReceiptItemsTableUpdateCompanionBuilder,
          (
            WhReceiptItem,
            BaseReferences<_$AppDatabase, $WhReceiptItemsTable, WhReceiptItem>,
          ),
          WhReceiptItem,
          PrefetchHooks Function()
        > {
  $$WhReceiptItemsTableTableManager(
    _$AppDatabase db,
    $WhReceiptItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WhReceiptItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WhReceiptItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WhReceiptItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> opId = const Value.absent(),
                Value<String> variantId = const Value.absent(),
                Value<double> qty = const Value.absent(),
                Value<int?> unitCost = const Value.absent(),
              }) => WhReceiptItemsCompanion(
                id: id,
                opId: opId,
                variantId: variantId,
                qty: qty,
                unitCost: unitCost,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String opId,
                required String variantId,
                required double qty,
                Value<int?> unitCost = const Value.absent(),
              }) => WhReceiptItemsCompanion.insert(
                id: id,
                opId: opId,
                variantId: variantId,
                qty: qty,
                unitCost: unitCost,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WhReceiptItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WhReceiptItemsTable,
      WhReceiptItem,
      $$WhReceiptItemsTableFilterComposer,
      $$WhReceiptItemsTableOrderingComposer,
      $$WhReceiptItemsTableAnnotationComposer,
      $$WhReceiptItemsTableCreateCompanionBuilder,
      $$WhReceiptItemsTableUpdateCompanionBuilder,
      (
        WhReceiptItem,
        BaseReferences<_$AppDatabase, $WhReceiptItemsTable, WhReceiptItem>,
      ),
      WhReceiptItem,
      PrefetchHooks Function()
    >;
typedef $$ShiftsTableCreateCompanionBuilder =
    ShiftsCompanion Function({
      required String id,
      Value<String?> locationId,
      Value<String?> cashierId,
      required String currency,
      Value<int> openingCash,
      required String openedAt,
      Value<String?> closedAt,
      Value<int?> expectedCash,
      Value<int?> serverExpectedCash,
      Value<int?> countedCash,
      Value<int?> difference,
      Value<String?> note,
      Value<String?> closedBy,
      Value<String?> updatedAt,
      Value<int> rowid,
    });
typedef $$ShiftsTableUpdateCompanionBuilder =
    ShiftsCompanion Function({
      Value<String> id,
      Value<String?> locationId,
      Value<String?> cashierId,
      Value<String> currency,
      Value<int> openingCash,
      Value<String> openedAt,
      Value<String?> closedAt,
      Value<int?> expectedCash,
      Value<int?> serverExpectedCash,
      Value<int?> countedCash,
      Value<int?> difference,
      Value<String?> note,
      Value<String?> closedBy,
      Value<String?> updatedAt,
      Value<int> rowid,
    });

class $$ShiftsTableFilterComposer
    extends Composer<_$AppDatabase, $ShiftsTable> {
  $$ShiftsTableFilterComposer({
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

  ColumnFilters<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cashierId => $composableBuilder(
    column: $table.cashierId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get openingCash => $composableBuilder(
    column: $table.openingCash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedCash => $composableBuilder(
    column: $table.expectedCash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverExpectedCash => $composableBuilder(
    column: $table.serverExpectedCash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get countedCash => $composableBuilder(
    column: $table.countedCash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get difference => $composableBuilder(
    column: $table.difference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get closedBy => $composableBuilder(
    column: $table.closedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ShiftsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShiftsTable> {
  $$ShiftsTableOrderingComposer({
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

  ColumnOrderings<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cashierId => $composableBuilder(
    column: $table.cashierId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openingCash => $composableBuilder(
    column: $table.openingCash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedCash => $composableBuilder(
    column: $table.expectedCash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverExpectedCash => $composableBuilder(
    column: $table.serverExpectedCash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get countedCash => $composableBuilder(
    column: $table.countedCash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get difference => $composableBuilder(
    column: $table.difference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get closedBy => $composableBuilder(
    column: $table.closedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShiftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShiftsTable> {
  $$ShiftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cashierId =>
      $composableBuilder(column: $table.cashierId, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get openingCash => $composableBuilder(
    column: $table.openingCash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => column);

  GeneratedColumn<String> get closedAt =>
      $composableBuilder(column: $table.closedAt, builder: (column) => column);

  GeneratedColumn<int> get expectedCash => $composableBuilder(
    column: $table.expectedCash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverExpectedCash => $composableBuilder(
    column: $table.serverExpectedCash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get countedCash => $composableBuilder(
    column: $table.countedCash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get difference => $composableBuilder(
    column: $table.difference,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get closedBy =>
      $composableBuilder(column: $table.closedBy, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ShiftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShiftsTable,
          Shift,
          $$ShiftsTableFilterComposer,
          $$ShiftsTableOrderingComposer,
          $$ShiftsTableAnnotationComposer,
          $$ShiftsTableCreateCompanionBuilder,
          $$ShiftsTableUpdateCompanionBuilder,
          (Shift, BaseReferences<_$AppDatabase, $ShiftsTable, Shift>),
          Shift,
          PrefetchHooks Function()
        > {
  $$ShiftsTableTableManager(_$AppDatabase db, $ShiftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShiftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShiftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShiftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> locationId = const Value.absent(),
                Value<String?> cashierId = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int> openingCash = const Value.absent(),
                Value<String> openedAt = const Value.absent(),
                Value<String?> closedAt = const Value.absent(),
                Value<int?> expectedCash = const Value.absent(),
                Value<int?> serverExpectedCash = const Value.absent(),
                Value<int?> countedCash = const Value.absent(),
                Value<int?> difference = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> closedBy = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShiftsCompanion(
                id: id,
                locationId: locationId,
                cashierId: cashierId,
                currency: currency,
                openingCash: openingCash,
                openedAt: openedAt,
                closedAt: closedAt,
                expectedCash: expectedCash,
                serverExpectedCash: serverExpectedCash,
                countedCash: countedCash,
                difference: difference,
                note: note,
                closedBy: closedBy,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> locationId = const Value.absent(),
                Value<String?> cashierId = const Value.absent(),
                required String currency,
                Value<int> openingCash = const Value.absent(),
                required String openedAt,
                Value<String?> closedAt = const Value.absent(),
                Value<int?> expectedCash = const Value.absent(),
                Value<int?> serverExpectedCash = const Value.absent(),
                Value<int?> countedCash = const Value.absent(),
                Value<int?> difference = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> closedBy = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShiftsCompanion.insert(
                id: id,
                locationId: locationId,
                cashierId: cashierId,
                currency: currency,
                openingCash: openingCash,
                openedAt: openedAt,
                closedAt: closedAt,
                expectedCash: expectedCash,
                serverExpectedCash: serverExpectedCash,
                countedCash: countedCash,
                difference: difference,
                note: note,
                closedBy: closedBy,
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

typedef $$ShiftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShiftsTable,
      Shift,
      $$ShiftsTableFilterComposer,
      $$ShiftsTableOrderingComposer,
      $$ShiftsTableAnnotationComposer,
      $$ShiftsTableCreateCompanionBuilder,
      $$ShiftsTableUpdateCompanionBuilder,
      (Shift, BaseReferences<_$AppDatabase, $ShiftsTable, Shift>),
      Shift,
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
  $$ExpensesTableTableManager get expenses =>
      $$ExpensesTableTableManager(_db, _db.expenses);
  $$DayClosesTableTableManager get dayCloses =>
      $$DayClosesTableTableManager(_db, _db.dayCloses);
  $$ServiceTxnsTableTableManager get serviceTxns =>
      $$ServiceTxnsTableTableManager(_db, _db.serviceTxns);
  $$WalletFloatsTableTableManager get walletFloats =>
      $$WalletFloatsTableTableManager(_db, _db.walletFloats);
  $$LocalFloatEffectsTableTableManager get localFloatEffects =>
      $$LocalFloatEffectsTableTableManager(_db, _db.localFloatEffects);
  $$ConversionsTableTableManager get conversions =>
      $$ConversionsTableTableManager(_db, _db.conversions);
  $$StockExpiryTableTableManager get stockExpiry =>
      $$StockExpiryTableTableManager(_db, _db.stockExpiry);
  $$WarehousesTableTableManager get warehouses =>
      $$WarehousesTableTableManager(_db, _db.warehouses);
  $$WhBinsTableTableManager get whBins =>
      $$WhBinsTableTableManager(_db, _db.whBins);
  $$WhBinStockTableTableManager get whBinStock =>
      $$WhBinStockTableTableManager(_db, _db.whBinStock);
  $$WhStockTableTableManager get whStock =>
      $$WhStockTableTableManager(_db, _db.whStock);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db, _db.suppliers);
  $$PurchaseOrdersTableTableManager get purchaseOrders =>
      $$PurchaseOrdersTableTableManager(_db, _db.purchaseOrders);
  $$PoItemsTableTableManager get poItems =>
      $$PoItemsTableTableManager(_db, _db.poItems);
  $$WhReceiptsTableTableManager get whReceipts =>
      $$WhReceiptsTableTableManager(_db, _db.whReceipts);
  $$WhReceiptItemsTableTableManager get whReceiptItems =>
      $$WhReceiptItemsTableTableManager(_db, _db.whReceiptItems);
  $$ShiftsTableTableManager get shifts =>
      $$ShiftsTableTableManager(_db, _db.shifts);
}

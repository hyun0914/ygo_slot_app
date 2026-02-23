class DrawFilter {
  final String? type;
  final String? attribute;
  final String? levelExpr;
  final String? atkExpr;
  final int count;

  const DrawFilter({
    this.type,
    this.attribute,
    this.levelExpr,
    this.atkExpr,
    this.count = 5,
  });

  Map<String, String> toApiParams() {
    final params = <String, String>{};

    if (type != null && type!.isNotEmpty) {
      params['type'] = type!;
    }
    if (attribute != null && attribute!.isNotEmpty) {
      params['attribute'] = attribute!;
    }
    if (levelExpr != null && levelExpr!.isNotEmpty) {
      params['level'] = levelExpr!;
    }
    if (atkExpr != null && atkExpr!.isNotEmpty) {
      params['atk'] = atkExpr!;
    }

    return params;
  }
}
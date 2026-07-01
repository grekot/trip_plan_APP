enum ItemType {
  drive,
  sightseeing,
  hike,
  meal,
  lodging,
  swim,
  info;

  static ItemType fromString(String? s) {
    if (s == null) return ItemType.info;
    return ItemType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => ItemType.info,
    );
  }

  /// Polska etykieta typu do wyświetlenia w UI.
  String get label {
    switch (this) {
      case ItemType.drive:
        return 'Dojazd';
      case ItemType.sightseeing:
        return 'Zwiedzanie';
      case ItemType.hike:
        return 'Trek / wycieczka piesza';
      case ItemType.meal:
        return 'Posiłek';
      case ItemType.lodging:
        return 'Nocleg';
      case ItemType.swim:
        return 'Kąpiel / baseny';
      case ItemType.info:
        return 'Informacja';
    }
  }
}

enum ContactType {
  phone,
  embassy;

  static ContactType fromString(String? s) {
    if (s == null) return ContactType.phone;
    return ContactType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => ContactType.phone,
    );
  }

  /// Polska etykieta typu kontaktu do wyświetlenia w UI.
  String get label {
    switch (this) {
      case ContactType.phone:
        return 'Telefon';
      case ContactType.embassy:
        return 'Ambasada';
    }
  }
}

enum ExtraCategory {
  short,
  halfday,
  evening,
  fullday;

  static ExtraCategory fromString(String? s) {
    if (s == null) return ExtraCategory.halfday;
    return ExtraCategory.values.firstWhere(
      (e) => e.name == s,
      orElse: () => ExtraCategory.halfday,
    );
  }

  String get label {
    switch (this) {
      case ExtraCategory.short:
        return 'Krótka przerwa (1-2h)';
      case ExtraCategory.halfday:
        return 'Pół dnia (3-5h)';
      case ExtraCategory.evening:
        return 'Popołudnie/wieczór';
      case ExtraCategory.fullday:
        return 'Cały dzień';
    }
  }
}

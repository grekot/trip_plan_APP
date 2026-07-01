import 'enums.dart';

class Trip {
  final int version;
  final String title;
  final String? subtitle;
  final String? summary;
  final List<Day> days;
  final List<ExtraAttraction> extras;
  final List<PackingItem> packing;
  final List<EmergencyContact> emergency;
  final List<Contingency> contingency;
  final Map<String, dynamic> practical;

  Trip({
    required this.version,
    required this.title,
    this.subtitle,
    this.summary,
    required this.days,
    required this.extras,
    required this.packing,
    required this.emergency,
    required this.contingency,
    required this.practical,
  });

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        version: j['version'] as int? ?? 1,
        title: j['title'] as String? ?? 'Wyjazd',
        subtitle: j['subtitle'] as String?,
        summary: j['summary'] as String?,
        days: (j['days'] as List? ?? [])
            .map((e) => Day.fromJson(e as Map<String, dynamic>))
            .toList(),
        extras: (j['extras'] as List? ?? [])
            .map((e) => ExtraAttraction.fromJson(e as Map<String, dynamic>))
            .toList(),
        packing: (j['packing'] as List? ?? [])
            .map((e) => PackingItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        emergency: (j['emergency'] as List? ?? [])
            .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
            .toList(),
        contingency: (j['contingency'] as List? ?? [])
            .map((e) => Contingency.fromJson(e as Map<String, dynamic>))
            .toList(),
        practical: (j['practical'] as Map?)?.cast<String, dynamic>() ?? {},
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (summary != null) 'summary': summary,
        'days': days.map((d) => d.toJson()).toList(),
        'extras': extras.map((e) => e.toJson()).toList(),
        'packing': packing.map((p) => p.toJson()).toList(),
        'emergency': emergency.map((e) => e.toJson()).toList(),
        'contingency': contingency.map((c) => c.toJson()).toList(),
        'practical': practical,
      };

  Iterable<Item> get allItems sync* {
    for (final d in days) {
      for (final s in d.sections) {
        yield* s.items;
      }
      yield* d.alternatives;
    }
  }

  int totalItemCount({bool includeHidden = false}) =>
      allItems.where((i) => includeHidden || !i.hidden).length;
}

class Day {
  final String id;
  final int number;
  final String title;
  final String summary;
  final List<Section> sections;
  final List<Item> alternatives;

  Day({
    required this.id,
    required this.number,
    required this.title,
    required this.summary,
    required this.sections,
    required this.alternatives,
  });

  factory Day.fromJson(Map<String, dynamic> j) => Day(
        id: j['id'] as String,
        number: j['number'] as int,
        title: j['title'] as String,
        summary: j['summary'] as String? ?? '',
        sections: (j['sections'] as List? ?? [])
            .map((e) => Section.fromJson(e as Map<String, dynamic>))
            .toList(),
        alternatives: (j['alternatives'] as List? ?? [])
            .map((e) => Item.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'title': title,
        'summary': summary,
        'sections': sections.map((s) => s.toJson()).toList(),
        if (alternatives.isNotEmpty)
          'alternatives': alternatives.map((a) => a.toJson()).toList(),
      };

  Iterable<Item> get allItems sync* {
    for (final s in sections) {
      yield* s.items;
    }
  }
}

class Section {
  final String id;
  final String title;
  final String? timeWindow;
  final List<Item> items;

  Section({
    required this.id,
    required this.title,
    this.timeWindow,
    required this.items,
  });

  factory Section.fromJson(Map<String, dynamic> j) => Section(
        id: j['id'] as String,
        title: j['title'] as String,
        timeWindow: j['timeWindow'] as String?,
        items: (j['items'] as List? ?? [])
            .map((e) => Item.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (timeWindow != null) 'timeWindow': timeWindow,
        'items': items.map((i) => i.toJson()).toList(),
      };
}

class Item {
  final String id;
  final String title;
  final String? description;
  final ItemType type;
  final Location? location;
  final List<Location> locations;
  final int? costEur;
  final String? duration;
  final List<String> tips;
  final bool hidden;
  final bool userAdded;

  Item({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    this.location,
    this.locations = const [],
    this.costEur,
    this.duration,
    this.tips = const [],
    this.hidden = false,
    this.userAdded = false,
  });

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        type: ItemType.fromString(j['type'] as String?),
        location: j['location'] != null
            ? Location.fromJson((j['location'] as Map).cast<String, dynamic>())
            : null,
        locations: (j['locations'] as List? ?? [])
            .map((e) => Location.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        costEur: (j['costEur'] as num?)?.toInt(),
        duration: j['duration'] as String?,
        tips: (j['tips'] as List? ?? []).map((e) => e.toString()).toList(),
        hidden: j['hidden'] as bool? ?? false,
        userAdded: j['userAdded'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (description != null) 'description': description,
        'type': type.name,
        if (location != null) 'location': location!.toJson(),
        if (locations.isNotEmpty)
          'locations': locations.map((l) => l.toJson()).toList(),
        if (costEur != null) 'costEur': costEur,
        if (duration != null) 'duration': duration,
        if (tips.isNotEmpty) 'tips': tips,
        if (hidden) 'hidden': true,
        if (userAdded) 'userAdded': true,
      };

  Item copyWith({
    String? title,
    String? description,
    ItemType? type,
    Location? location,
    List<String>? tips,
    bool? hidden,
  }) =>
      Item(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        type: type ?? this.type,
        location: location ?? this.location,
        locations: locations,
        costEur: costEur,
        duration: duration,
        tips: tips ?? this.tips,
        hidden: hidden ?? this.hidden,
        userAdded: userAdded,
      );
}

class Location {
  final String name;
  final double lat;
  final double lng;
  final String? address;

  Location({
    required this.name,
    required this.lat,
    required this.lng,
    this.address,
  });

  factory Location.fromJson(Map<String, dynamic> j) => Location(
        name: j['name'] as String? ?? '',
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        address: j['address'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'lat': lat,
        'lng': lng,
        if (address != null) 'address': address,
      };
}

class ExtraAttraction {
  final String id;
  final String title;
  final ExtraCategory category;
  final String? drivingTime;
  final int totalCostEur;
  final String description;
  final List<String> bestFor;
  final String? duration;
  final Location? location;
  final List<Location> locations;

  ExtraAttraction({
    required this.id,
    required this.title,
    required this.category,
    this.drivingTime,
    required this.totalCostEur,
    required this.description,
    this.bestFor = const [],
    this.duration,
    this.location,
    this.locations = const [],
  });

  factory ExtraAttraction.fromJson(Map<String, dynamic> j) => ExtraAttraction(
        id: j['id'] as String,
        title: j['title'] as String,
        category: ExtraCategory.fromString(j['category'] as String?),
        drivingTime: j['drivingTime'] as String?,
        totalCostEur: (j['totalCostEur'] as num?)?.toInt() ?? 0,
        description: j['description'] as String? ?? '',
        bestFor: (j['bestFor'] as List? ?? []).map((e) => e.toString()).toList(),
        duration: j['duration'] as String?,
        location: j['location'] != null
            ? Location.fromJson((j['location'] as Map).cast<String, dynamic>())
            : null,
        locations: (j['locations'] as List? ?? [])
            .map((e) => Location.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category.name,
        if (drivingTime != null) 'drivingTime': drivingTime,
        'totalCostEur': totalCostEur,
        'description': description,
        if (bestFor.isNotEmpty) 'bestFor': bestFor,
        if (duration != null) 'duration': duration,
        if (location != null) 'location': location!.toJson(),
        if (locations.isNotEmpty)
          'locations': locations.map((l) => l.toJson()).toList(),
      };
}

class PackingItem {
  final String id;
  final String category;
  final String text;
  final bool userAdded;

  PackingItem({
    required this.id,
    required this.category,
    required this.text,
    this.userAdded = false,
  });

  factory PackingItem.fromJson(Map<String, dynamic> j) => PackingItem(
        id: j['id'] as String,
        category: j['category'] as String? ?? 'Ogólnie',
        text: j['text'] as String,
        userAdded: j['userAdded'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'text': text,
        if (userAdded) 'userAdded': true,
      };
}

class EmergencyContact {
  final String id;
  final String label;
  final String value;
  final ContactType type;

  EmergencyContact({
    required this.id,
    required this.label,
    required this.value,
    required this.type,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> j) => EmergencyContact(
        id: j['id'] as String,
        label: j['label'] as String,
        value: j['value'] as String,
        type: ContactType.fromString(j['type'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'value': value,
        'type': type.name,
      };
}

class Contingency {
  final String id;
  final String trigger;
  final List<String> options;

  Contingency({
    required this.id,
    required this.trigger,
    required this.options,
  });

  factory Contingency.fromJson(Map<String, dynamic> j) => Contingency(
        id: j['id'] as String,
        trigger: j['trigger'] as String,
        options: (j['options'] as List? ?? []).map((e) => e.toString()).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'trigger': trigger,
        'options': options,
      };
}

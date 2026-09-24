class TimeIntervalEntity {
  const TimeIntervalEntity({
    required this.open,
    required this.close,
  });

  final String open;
  final String close;

  Map<String, dynamic> toJson() => {
        'open': open,
        'close': close,
      };

  factory TimeIntervalEntity.fromJson(Map<String, dynamic> json) =>
      TimeIntervalEntity(
        open: json['open'] as String? ?? '09:00',
        close: json['close'] as String? ?? '21:00',
      );
}

class DayScheduleEntity {
  const DayScheduleEntity({
    required this.isClosed,
    this.intervals = const [],
  });

  final bool isClosed;
  final List<TimeIntervalEntity> intervals;

  Map<String, dynamic> toJson() => {
        'isClosed': isClosed,
        'intervals': intervals.map((i) => i.toJson()).toList(),
      };

  factory DayScheduleEntity.fromJson(Map<String, dynamic> json) =>
      DayScheduleEntity(
        isClosed: json['isClosed'] as bool? ?? false,
        intervals: (json['intervals'] as List<dynamic>?)
                ?.map((i) =>
                    TimeIntervalEntity.fromJson(i as Map<String, dynamic>),)
                .toList() ??
            const [],
      );
}

class OperatingHoursEntity {
  const OperatingHoursEntity({
    this.monday,
    this.tuesday,
    this.wednesday,
    this.thursday,
    this.friday,
    this.saturday,
    this.sunday,
  });

  final DayScheduleEntity? monday;
  final DayScheduleEntity? tuesday;
  final DayScheduleEntity? wednesday;
  final DayScheduleEntity? thursday;
  final DayScheduleEntity? friday;
  final DayScheduleEntity? saturday;
  final DayScheduleEntity? sunday;

  Map<String, dynamic> toJson() => {
        if (monday != null) 'monday': monday!.toJson(),
        if (tuesday != null) 'tuesday': tuesday!.toJson(),
        if (wednesday != null) 'wednesday': wednesday!.toJson(),
        if (thursday != null) 'thursday': thursday!.toJson(),
        if (friday != null) 'friday': friday!.toJson(),
        if (saturday != null) 'saturday': saturday!.toJson(),
        if (sunday != null) 'sunday': sunday!.toJson(),
      };

  factory OperatingHoursEntity.fromJson(Map<String, dynamic> json) =>
      OperatingHoursEntity(
        monday: json['monday'] != null
            ? DayScheduleEntity.fromJson(json['monday'] as Map<String, dynamic>)
            : null,
        tuesday: json['tuesday'] != null
            ? DayScheduleEntity.fromJson(
                json['tuesday'] as Map<String, dynamic>,)
            : null,
        wednesday: json['wednesday'] != null
            ? DayScheduleEntity.fromJson(
                json['wednesday'] as Map<String, dynamic>,)
            : null,
        thursday: json['thursday'] != null
            ? DayScheduleEntity.fromJson(
                json['thursday'] as Map<String, dynamic>,)
            : null,
        friday: json['friday'] != null
            ? DayScheduleEntity.fromJson(json['friday'] as Map<String, dynamic>)
            : null,
        saturday: json['saturday'] != null
            ? DayScheduleEntity.fromJson(
                json['saturday'] as Map<String, dynamic>,)
            : null,
        sunday: json['sunday'] != null
            ? DayScheduleEntity.fromJson(json['sunday'] as Map<String, dynamic>)
            : null,
      );
}

class OperatingStatusEntity {
  const OperatingStatusEntity({
    required this.isOpen,
    required this.status,
    required this.statusText,
  });

  final bool isOpen;
  final String status;
  final String statusText;

  factory OperatingStatusEntity.fromJson(Map<String, dynamic> json) =>
      OperatingStatusEntity(
        isOpen: json['isOpen'] as bool? ?? false,
        status: json['status'] as String? ?? 'closed',
        statusText: json['statusText'] as String? ?? 'Hours not available',
      );
}

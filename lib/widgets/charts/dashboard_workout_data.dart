import 'dart:core';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

List<Observation> aggregateWorkoutDailySum(
  List<JournalEntity?> entities, {
  required DashboardWorkoutItem chartConfig,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  Map<String, num> sumsByDay = {};

  Duration range = rangeEnd.difference(rangeStart);
  List<String> dayStrings = List<String>.generate(range.inDays, (days) {
    DateTime day = rangeStart.add(Duration(days: days));
    return ymd(day);
  });

  for (final dayString in dayStrings) {
    sumsByDay[dayString] = 0;
  }

  for (JournalEntity? entity in entities) {
    entity?.maybeMap(
      workout: (WorkoutEntry workoutEntry) {
        WorkoutData data = workoutEntry.data;
        if (data.workoutType == chartConfig.workoutType) {
          String dayString = ymd(entity.meta.dateFrom);
          num n = sumsByDay[dayString] ?? 0;

          if (chartConfig.valueType == WorkoutValueType.distance &&
              data.distance != null) {
            sumsByDay[dayString] = n + data.distance!;
          }

          if (chartConfig.valueType == WorkoutValueType.energy &&
              data.energy != null) {
            sumsByDay[dayString] = n + data.energy!;
          }

          if (chartConfig.valueType == WorkoutValueType.duration) {
            num minutes = workoutEntry.meta.dateTo
                    .difference(workoutEntry.meta.dateFrom)
                    .inSeconds /
                60;
            sumsByDay[dayString] = n + minutes;
          }
        }
      },
      orElse: () {},
    );
  }

  for (final entity in entities) {
    String dayString = ymd(entity!.meta.dateFrom);
    num n = sumsByDay[dayString] ?? 0;
    if (entity is QuantitativeEntry) {
      sumsByDay[dayString] = n + entity.data.value;
    }
  }

  List<Observation> aggregated = [];
  for (final dayString in sumsByDay.keys) {
    DateTime day = DateTime.parse(dayString);
    aggregated.add(Observation(day, sumsByDay[dayString] ?? 0));
  }

  return aggregated;
}

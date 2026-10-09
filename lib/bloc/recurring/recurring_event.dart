part of 'recurring_bloc.dart';

sealed class RecurringEvent extends Equatable {
  const RecurringEvent();

  @override
  List<Object?> get props => [];
}

class LoadRecurring extends RecurringEvent {
  const LoadRecurring({this.catchUp = false});

  /// Also issue every invoice that is due. Used once, at app start.
  final bool catchUp;

  @override
  List<Object?> get props => [catchUp];
}

class PauseRecurring extends RecurringEvent {
  const PauseRecurring(this.scheduleId, {required this.paused});

  final String scheduleId;
  final bool paused;

  @override
  List<Object?> get props => [scheduleId, paused];
}

class DeleteRecurring extends RecurringEvent {
  const DeleteRecurring(this.scheduleId);

  final String scheduleId;

  @override
  List<Object?> get props => [scheduleId];
}

part of 'journal_bloc.dart';

class JournalState extends Equatable {
  const JournalState({
    this.status = LoadStatus.initial,
    this.journals = const [],
    this.error,
  });

  final LoadStatus status;

  /// Newest first.
  final List<JournalEntry> journals;
  final String? error;

  JournalEntry? byId(String? id) {
    for (final j in journals) {
      if (j.id == id) return j;
    }
    return null;
  }

  JournalState copyWith({LoadStatus? status, List<JournalEntry>? journals, String? error}) =>
      JournalState(
        status: status ?? this.status,
        journals: journals ?? this.journals,
        error: error,
      );

  @override
  List<Object?> get props => [status, journals, error];
}

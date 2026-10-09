part of 'journal_bloc.dart';

sealed class JournalEvent extends Equatable {
  const JournalEvent();

  @override
  List<Object?> get props => [];
}

class LoadJournals extends JournalEvent {
  const LoadJournals();
}

class DeleteJournal extends JournalEvent {
  const DeleteJournal(this.journalId);

  final String journalId;

  @override
  List<Object?> get props => [journalId];
}

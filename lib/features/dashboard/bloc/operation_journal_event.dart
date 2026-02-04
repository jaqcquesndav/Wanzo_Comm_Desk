part of 'operation_journal_bloc.dart';

@immutable
abstract class OperationJournalEvent {
  const OperationJournalEvent();
}

class LoadOperations extends OperationJournalEvent {
  final DateTime startDate;
  final DateTime endDate;

  const LoadOperations({required this.startDate, required this.endDate});
}

class LoadOperationsWithFilter extends OperationJournalEvent {
  final JournalFilter filter;

  const LoadOperationsWithFilter({required this.filter});
}

class FilterPeriodChanged extends OperationJournalEvent {
  final DateTime? newStartDate;
  final DateTime? newEndDate;
  // Ou pourrait être un enum pour Jour, Mois, Année
  // final PeriodFilterType filterType;

  const FilterPeriodChanged({this.newStartDate, this.newEndDate});
}

/// Event to signal that the journal needs to be refreshed
class RefreshJournal extends OperationJournalEvent {
  const RefreshJournal();
}

class AddOperationJournalEntry extends OperationJournalEvent {
  final OperationJournalEntry entry;

  const AddOperationJournalEntry(this.entry);

  List<Object> get props => [entry];
}

class AddMultipleOperationJournalEntries extends OperationJournalEvent {
  final List<OperationJournalEntry> entries;

  const AddMultipleOperationJournalEntries(this.entries);

  List<Object> get props => [entries];
}

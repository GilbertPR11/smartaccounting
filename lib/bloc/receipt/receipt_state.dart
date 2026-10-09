part of 'receipt_bloc.dart';

/// Outcome of the last save / record / delete, for the receipt page to react to.
enum ReceiptAction { idle, working, saved, recorded, deleted, failed }

class ReceiptState extends Equatable {
  const ReceiptState({
    this.status = LoadStatus.initial,
    this.receipts = const [],
    this.action = ReceiptAction.idle,
    this.actionCount = 0,
    this.error,
  });

  final LoadStatus status;

  /// To review first, then newest.
  final List<Receipt> receipts;
  final ReceiptAction action;

  /// Increments on every finished action so listeners fire even when the
  /// same action repeats (two saves in a row).
  final int actionCount;
  final String? error;

  List<Receipt> get toReview => receipts.where((r) => !r.isDone).toList();

  Receipt? byId(String? id) {
    for (final r in receipts) {
      if (r.id == id) return r;
    }
    return null;
  }

  ReceiptState copyWith({
    LoadStatus? status,
    List<Receipt>? receipts,
    ReceiptAction? action,
    int? actionCount,
    String? error,
  }) =>
      ReceiptState(
        status: status ?? this.status,
        receipts: receipts ?? this.receipts,
        action: action ?? this.action,
        actionCount: actionCount ?? this.actionCount,
        error: error,
      );

  @override
  List<Object?> get props => [status, receipts, action, actionCount, error];
}

part of 'estimate_form_bloc.dart';

class EstimateFormState extends Equatable {
  const EstimateFormState({
    this.status = FormSaveStatus.editing,
    this.saved,
    this.error,
  });

  final FormSaveStatus status;

  /// Set when [status] is success.
  final Estimate? saved;
  final String? error;

  @override
  List<Object?> get props => [status, saved, error];
}

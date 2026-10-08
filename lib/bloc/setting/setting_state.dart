part of 'setting_bloc.dart';

enum SaveStatus { idle, saving, saved, failed }

class SettingState extends Equatable {
  const SettingState({
    this.status = LoadStatus.initial,
    this.profile = BusinessProfile.empty,
    this.template = const InvoiceTemplate(),
    this.saveStatus = SaveStatus.idle,
    this.error,
  });

  final LoadStatus status;
  final BusinessProfile profile;
  final InvoiceTemplate template;
  final SaveStatus saveStatus;
  final String? error;

  SettingState copyWith({
    LoadStatus? status,
    BusinessProfile? profile,
    InvoiceTemplate? template,
    SaveStatus? saveStatus,
    String? error,
  }) =>
      SettingState(
        status: status ?? this.status,
        profile: profile ?? this.profile,
        template: template ?? this.template,
        saveStatus: saveStatus ?? this.saveStatus,
        error: error,
      );

  @override
  List<Object?> get props => [status, profile, template, saveStatus, error];
}

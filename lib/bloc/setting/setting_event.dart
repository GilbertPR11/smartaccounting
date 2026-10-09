part of 'setting_bloc.dart';

sealed class SettingEvent extends Equatable {
  const SettingEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettings extends SettingEvent {
  const LoadSettings();
}

class SaveInvoiceSettings extends SettingEvent {
  const SaveInvoiceSettings({required this.profile, required this.template});

  final BusinessProfile profile;
  final InvoiceTemplate template;

  @override
  List<Object?> get props => [profile, template];
}

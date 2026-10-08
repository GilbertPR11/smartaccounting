import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../exception/app_exception.dart';
import '../../models/business_profile_model.dart';
import '../../models/invoice_template_model.dart';
import '../../repository/setting_repository.dart';
import '../load_status.dart';

part 'setting_event.dart';
part 'setting_state.dart';

/// Business profile + invoice design (smartpos: `Bloc/setting`).
class SettingBloc extends Bloc<SettingEvent, SettingState> {
  SettingBloc({required SettingRepository repository})
      : _repository = repository,
        super(const SettingState()) {
    on<LoadSettings>(_onLoad);
    on<SaveInvoiceSettings>(_onSave);
    _changes = _repository.changes.listen((_) => add(const LoadSettings()));
  }

  final SettingRepository _repository;
  late final StreamSubscription<void> _changes;

  Future<void> _onLoad(LoadSettings event, Emitter<SettingState> emit) async {
    try {
      final profile = await _repository.fetchProfile();
      final template = await _repository.fetchInvoiceTemplate();
      emit(state.copyWith(
          status: LoadStatus.success, profile: profile, template: template));
    } on AppException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }

  Future<void> _onSave(SaveInvoiceSettings event, Emitter<SettingState> emit) async {
    emit(state.copyWith(saveStatus: SaveStatus.saving));
    try {
      await _repository.saveInvoiceSettings(
          profile: event.profile, template: event.template);
      emit(state.copyWith(
        saveStatus: SaveStatus.saved,
        profile: event.profile,
        template: event.template,
      ));
    } on AppException catch (e) {
      emit(state.copyWith(saveStatus: SaveStatus.failed, error: e.message));
    }
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}

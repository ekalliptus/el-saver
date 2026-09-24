import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/permission_service.dart';
import '../../data/whatsapp_status_repository.dart';

class WhatsappStatusBloc
    extends Bloc<WhatsappStatusEvent, WhatsappStatusState> {
  final WhatsappStatusRepository repository;
  final PermissionService permissionService;

  WhatsappStatusBloc({required this.repository})
      : permissionService = PermissionService(),
        super(const WhatsappStatusInitial()) {
    on<WhatsappStatusLoad>(_onLoad);
    on<WhatsappStatusSaveRequested>(_onSave);
    on<WhatsappStatusRequestPermission>(_onRequestPermission);
  }

  Future<void> _onLoad(
    WhatsappStatusLoad event,
    Emitter<WhatsappStatusState> emit,
  ) async {
    emit(WhatsappStatusLoading(
      previous: state is WhatsappStatusLoaded
          ? (state as WhatsappStatusLoaded).statuses
          : const [],
    ));
    // WhatsApp keeps statuses in a hidden folder that needs All-files
    // access on Android 11+; without it the scan silently returns nothing.
    if (!await permissionService.hasAllFilesAccess()) {
      emit(const WhatsappStatusPermissionNeeded());
      return;
    }
    try {
      final statuses = await repository.scan();
      emit(WhatsappStatusLoaded(statuses));
    } catch (_) {
      emit(const WhatsappStatusError(
        'Tidak bisa membaca status WhatsApp. Pastikan izin penyimpanan '
        'diberikan dan kamu sudah melihat status di WhatsApp.',
      ));
    }
  }

  Future<void> _onRequestPermission(
    WhatsappStatusRequestPermission event,
    Emitter<WhatsappStatusState> emit,
  ) async {
    final granted = await permissionService.ensureAllFilesAccess();
    if (granted) {
      add(const WhatsappStatusLoad());
    } else {
      emit(const WhatsappStatusError(
        'Izin akses file belum diberikan. Aktifkan "All files access" '
        'untuk EL-Saver di pengaturan.',
      ));
    }
  }

  Future<void> _onSave(
    WhatsappStatusSaveRequested event,
    Emitter<WhatsappStatusState> emit,
  ) async {
    final loaded = state;
    final statuses =
        loaded is WhatsappStatusLoaded ? loaded.statuses : const <StatusFile>[];
    emit(WhatsappStatusSaving(statuses, event.path));
    try {
      await repository.save(event.path);
      emit(WhatsappStatusSaved(statuses, event.path));
    } catch (e) {
      emit(WhatsappStatusError(
        'Gagal menyimpan status. Cek izin galeri di pengaturan.',
      ));
    }
  }
}

abstract class WhatsappStatusEvent {
  const WhatsappStatusEvent();
}

class WhatsappStatusLoad extends WhatsappStatusEvent {
  const WhatsappStatusLoad();
}

class WhatsappStatusSaveRequested extends WhatsappStatusEvent {
  final String path;
  const WhatsappStatusSaveRequested(this.path);
}

class WhatsappStatusRequestPermission extends WhatsappStatusEvent {
  const WhatsappStatusRequestPermission();
}

abstract class WhatsappStatusState extends Equatable {
  const WhatsappStatusState();

  @override
  List<Object?> get props => [];
}

class WhatsappStatusInitial extends WhatsappStatusState {
  const WhatsappStatusInitial();
}

class WhatsappStatusPermissionNeeded extends WhatsappStatusState {
  const WhatsappStatusPermissionNeeded();
}

class WhatsappStatusLoading extends WhatsappStatusState {
  final List<StatusFile> previous;
  const WhatsappStatusLoading({this.previous = const []});

  @override
  List<Object?> get props => [previous];
}

class WhatsappStatusLoaded extends WhatsappStatusState {
  final List<StatusFile> statuses;
  const WhatsappStatusLoaded(this.statuses);

  @override
  List<Object?> get props => [statuses];
}

class WhatsappStatusSaving extends WhatsappStatusState {
  final List<StatusFile> statuses;
  final String path;
  const WhatsappStatusSaving(this.statuses, this.path);

  @override
  List<Object?> get props => [statuses, path];
}

class WhatsappStatusSaved extends WhatsappStatusState {
  final List<StatusFile> statuses;
  final String path;
  const WhatsappStatusSaved(this.statuses, this.path);

  @override
  List<Object?> get props => [statuses, path];
}

class WhatsappStatusError extends WhatsappStatusState {
  final String message;
  const WhatsappStatusError(this.message);

  @override
  List<Object?> get props => [message];
}

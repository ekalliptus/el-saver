import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:el_saver/src/core/common_widgets/toast.dart';
import 'package:el_saver/src/core/utils/app_colors.dart';
import 'package:el_saver/src/core/utils/app_enums.dart';

import '../../data/whatsapp_status_repository.dart';
import '../bloc/whatsapp_status_bloc.dart';
import 'status_preview_screen.dart';

/// Grid of the currently visible WhatsApp statuses. Users must first *view*
/// the statuses in WhatsApp so the files land in WA's status cache folder.
class WhatsappStatusScreen extends StatelessWidget {
  const WhatsappStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WhatsappStatusBloc(repository: WhatsappStatusRepository())
        ..add(const WhatsappStatusLoad()),
      child: const _WhatsappStatusView(),
    );
  }
}

class _WhatsappStatusView extends StatelessWidget {
  const _WhatsappStatusView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Status WhatsApp')),
      body: BlocConsumer<WhatsappStatusBloc, WhatsappStatusState>(
        listener: (context, state) {
          if (state is WhatsappStatusSaved) {
            buildToast(msg: 'Status tersimpan ke galeri ✔', type: ToastType.success);
          } else if (state is WhatsappStatusError) {
            buildToast(msg: state.message, type: ToastType.error);
          }
        },
        builder: (context, state) {
          if (state is WhatsappStatusLoading && state.previous.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
              ),
            );
          }
          if (state is WhatsappStatusPermissionNeeded) {
            return _StatusMessage(
              icon: Icons.folder_off_outlined,
              title: 'Butuh izin akses file',
              message:
                  'Status WhatsApp tersimpan di folder tersembunyi WhatsApp. '
                  'Aktifkan izin "All files access" untuk EL-Saver agar '
                  'aplikasi bisa membacanya.',
              action: 'Berikan Izin',
              onAction: () => context
                  .read<WhatsappStatusBloc>()
                  .add(const WhatsappStatusRequestPermission()),
            );
          }
          if (state is WhatsappStatusError) {
            return _StatusMessage(
              icon: Icons.error_outline,
              title: 'Gagal memuat',
              message: state.message,
              action: 'Coba Lagi',
              onAction: () =>
                  context.read<WhatsappStatusBloc>().add(const WhatsappStatusLoad()),
            );
          }
          final statuses = switch (state) {
            WhatsappStatusLoaded(:final statuses) => statuses,
            WhatsappStatusLoading(:final previous) => previous,
            WhatsappStatusSaving(:final statuses) => statuses,
            WhatsappStatusSaved(:final statuses) => statuses,
            _ => const <StatusFile>[],
          };
          if (statuses.isEmpty) {
            return const _EmptyStatusGuide();
          }
          return RefreshIndicator(
            onRefresh: () async {
              context
                  .read<WhatsappStatusBloc>()
                  .add(const WhatsappStatusLoad());
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.72,
              ),
              itemCount: statuses.length,
              itemBuilder: (context, index) {
                final status = statuses[index];
                return _StatusTile(
                  status: status,
                  saving:
                      state is WhatsappStatusSaving && state.path == status.path,
                  onTap: () => _openPreview(context, status),
                  onSave: () => context
                      .read<WhatsappStatusBloc>()
                      .add(WhatsappStatusSaveRequested(status.path)),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _openPreview(BuildContext context, StatusFile status) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => StatusPreviewScreen(
        path: status.path,
        isVideo: status.isVideo,
      ),
    ));
  }
}

class _StatusTile extends StatelessWidget {
  final StatusFile status;
  final bool saving;
  final VoidCallback onTap;
  final VoidCallback onSave;

  const _StatusTile({
    required this.status,
    required this.saving,
    required this.onTap,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Image.file(
              File(status.path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Colors.black12,
                child: Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          if (status.isVideo)
            const Positioned(
              top: 6,
              left: 6,
              child: Icon(Icons.play_circle_fill, color: Colors.white, size: 22),
            ),
          Positioned(
            bottom: 6,
            right: 6,
            child: Material(
              color: AppColors.primaryColor,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: saving ? null : onSave,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded,
                          color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStatusGuide extends StatelessWidget {
  const _EmptyStatusGuide();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wysiwyg_rounded,
                size: 64, color: AppColors.primaryColor.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('Belum ada status',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              '1. Buka WhatsApp, lihat status temanmu\n'
              '2. Kembali ke sini dan tarik ke bawah untuk refresh\n\n'
              'Status hanya tersedia selama 24 jam di WhatsApp.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String action;
  final VoidCallback onAction;

  const _StatusMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.primaryColor.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

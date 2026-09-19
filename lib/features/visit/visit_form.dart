import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../api/api_exception.dart';
import '../../models/models.dart';
import '../../state/kiosk_controller.dart';
import '../../widgets/feedback.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/kiosk_toast.dart';
import 'member_quick_visit.dart';

/// Layanan Buku Tamu: mencatat kunjungan perpustakaan.
class VisitForm extends StatefulWidget {
  const VisitForm({
    super.key,
    required this.visitorTypeOptions,
    required this.purposeOptions,
  });

  final List<SelectOption> visitorTypeOptions;
  final List<SelectOption> purposeOptions;

  @override
  State<VisitForm> createState() => _VisitFormState();
}

class _VisitFormState extends State<VisitForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _identityController = TextEditingController();
  final _institutionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  String? _visitorType;
  String? _purpose;
  bool _submitting = false;
  String? _error;

  bool get _isPublicVisitor => _visitorType == 'umum';
  bool get _requiresIdentity => _visitorType != null && _visitorType != 'umum';

  @override
  void dispose() {
    _nameController.dispose();
    _identityController.dispose();
    _institutionController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _reset() {
    _nameController.clear();
    _identityController.clear();
    _institutionController.clear();
    _phoneController.clear();
    _notesController.clear();
    setState(() {
      _visitorType = null;
      _purpose = null;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_visitorType == null || _purpose == null) {
      setState(
        () => _error = 'Lengkapi jenis pengunjung dan tujuan kunjungan.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final controller = context.read<KioskController>();

    try {
      final result = await controller.recordVisit(
        name: _nameController.text.trim(),
        visitorType: _visitorType!,
        purpose: _purpose!,
        identityNumber: _requiresIdentity
            ? _identityController.text.trim()
            : null,
        institution: _isPublicVisitor
            ? _institutionController.text.trim()
            : null,
        phone: _phoneController.text.trim(),
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;
      _reset();
      KioskToast.show(
        context,
        title: 'Kunjungan Tercatat',
        message: 'Terima kasih, ${result.name}. Kehadiran Anda telah dicatat.',
        detail: 'Waktu: ${_formatTime(result.visitedAt)}',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.bestMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '-';
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Server tak terjangkau: menekan tombol hanya akan gagal.
    final offline = context.watchOffline();

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Jalur cepat untuk anggota: satu scan, tanpa isi form.
            MemberQuickVisitCard(purposeOptions: widget.purposeOptions),
            const SizedBox(height: 22),
            const _ManualVisitHeader(),
            const SizedBox(height: 16),
            if (_error != null) ...[
              StatusBanner(message: _error!),
              const SizedBox(height: 16),
            ],
            ResponsiveRow(
              children: [
                KioskField(
                  label: 'Nama Lengkap',
                  required: true,
                  child: TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Nama lengkap',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Nama wajib diisi.'
                        : null,
                  ),
                ),
                KioskField(
                  label: 'Jenis Pengunjung',
                  required: true,
                  child: DropdownButtonFormField<String>(
                    initialValue: _visitorType,
                    isExpanded: true,
                    decoration: const InputDecoration(hintText: 'Pilih jenis'),
                    items: widget.visitorTypeOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option.value,
                            child: Text(option.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      setState(() {
                        _visitorType = value;
                        _identityController.clear();
                        _institutionController.clear();
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Pilih jenis pengunjung.' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ResponsiveRow(
              children: [
                if (_requiresIdentity)
                  KioskField(
                    label: 'NIM / NIP',
                    child: TextFormField(
                      controller: _identityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        hintText: 'Nomor identitas (6–30 digit)',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) return null;
                        if (!RegExp(r'^\d{6,30}$').hasMatch(text)) {
                          return 'Nomor identitas 6–30 digit angka.';
                        }
                        return null;
                      },
                    ),
                  ),
                if (_isPublicVisitor)
                  KioskField(
                    label: 'Instansi',
                    child: TextFormField(
                      controller: _institutionController,
                      decoration: const InputDecoration(
                        hintText: 'Asal instansi',
                        prefixIcon: Icon(Icons.apartment_outlined),
                      ),
                    ),
                  ),
                KioskField(
                  label: 'No. Telepon',
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '08xxxxxxxxxx',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            KioskField(
              label: 'Tujuan Kunjungan',
              required: true,
              child: DropdownButtonFormField<String>(
                initialValue: _purpose,
                isExpanded: true,
                decoration: const InputDecoration(hintText: 'Pilih tujuan'),
                items: widget.purposeOptions
                    .map(
                      (option) => DropdownMenuItem(
                        value: option.value,
                        child: Text(option.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() => _purpose = value),
                validator: (value) =>
                    value == null ? 'Pilih tujuan kunjungan.' : null,
              ),
            ),
            const SizedBox(height: 16),
            KioskField(
              label: 'Catatan (opsional)',
              child: TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Keterangan tambahan (min. 10 karakter bila diisi)',
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  if (text.length < 10) {
                    return 'Catatan minimal 10 karakter.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: (_submitting || offline) ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_submitting ? 'Menyimpan...' : 'Simpan Kunjungan'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pemisah antara jalur cepat dan form manual, yang tetap tersedia untuk
/// pengunjung umum atau yang belum punya akun anggota.
class _ManualVisitHeader extends StatelessWidget {
  const _ManualVisitHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Atau isi form manual',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2),
              Text(
                'Untuk pengunjung umum atau yang belum punya akun anggota.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

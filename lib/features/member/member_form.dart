import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_exception.dart';
import '../../state/kiosk_controller.dart';
import '../../widgets/feedback.dart';
import '../../widgets/form_fields.dart';
import 'member_claim_dialog.dart';
import 'member_email.dart';

/// Layanan Daftar Anggota: pendaftaran anggota baru lewat penautan akun
/// Google.
class MemberForm extends StatefulWidget {
  const MemberForm({super.key});

  @override
  State<MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends State<MemberForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _localPartController = TextEditingController();
  final _domainController = TextEditingController(text: defaultEmailDomain);
  final _whatsappController = TextEditingController();
  final _addressController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _localPartController.dispose();
    _domainController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _reset() {
    _nameController.clear();
    _localPartController.clear();
    _domainController.text = defaultEmailDomain;
    _whatsappController.clear();
    _addressController.clear();
    setState(() => _error = null);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final controller = context.read<KioskController>();
    final email = composeMemberEmail(
      _localPartController.text,
      _domainController.text,
    );

    try {
      final claim = await controller.registerMember(
        name: _nameController.text.trim(),
        email: email,
        whatsapp: _whatsappController.text.trim(),
        address: _addressController.text.trim(),
      );

      if (!mounted) return;
      _reset();

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => MemberClaimDialog(
          initialClaim: claim,
          onLinked: () {},
          onCancel: () {},
          onRestart: () => _restartRegistration(email),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.bestMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Membuat QR baru dengan data yang sama, setelah yang lama kedaluwarsa.
  Future<void> _restartRegistration(String email) async {
    final controller = context.read<KioskController>();
    try {
      final claim = await controller.registerMember(
        name: _nameController.text.trim(),
        email: email,
        whatsapp: _whatsappController.text.trim(),
        address: _addressController.text.trim(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => MemberClaimDialog(
          initialClaim: claim,
          onLinked: () {},
          onCancel: () {},
          onRestart: () => _restartRegistration(email),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.bestMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              StatusBanner(message: _error!),
              const SizedBox(height: 16),
            ],
            const StatusBanner(
              tone: StatusTone.info,
              message:
                  'Isi data berikut, lalu pindai QR yang muncul dengan ponsel '
                  'untuk menautkan akun Google Anda.',
            ),
            const SizedBox(height: 18),
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
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Nama wajib diisi.' : null,
              ),
            ),
            const SizedBox(height: 16),
            KioskField(
              label: 'Email Kampus',
              required: true,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _localPartController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'nama',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (_) => validateMemberEmail(
                        _localPartController.text,
                        _domainController.text,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('@', style: TextStyle(fontSize: 18)),
                  ),
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: _domainController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: defaultEmailDomain,
                      ),
                      validator: (_) => validateMemberEmail(
                        _localPartController.text,
                        _domainController.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ResponsiveRow(
              children: [
                KioskField(
                  label: 'No. WhatsApp',
                  required: true,
                  child: TextFormField(
                    controller: _whatsappController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '08123456789',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return 'Nomor WhatsApp wajib diisi.';
                      final digits = text.replaceAll(RegExp(r'\D+'), '');
                      if (!RegExp(r'^(?:62|0)?8[1-9][0-9]{7,11}$')
                          .hasMatch(digits)) {
                        return 'Nomor WhatsApp tidak valid.';
                      }
                      return null;
                    },
                  ),
                ),
                KioskField(
                  label: 'Alamat',
                  required: true,
                  child: TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      hintText: 'Alamat lengkap',
                      prefixIcon: Icon(Icons.home_outlined),
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return 'Alamat wajib diisi.';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.qr_code_2),
              label: Text(_submitting ? 'Menyiapkan QR...' : 'Tampilkan QR'),
            ),
          ],
        ),
      ),
    );
  }
}

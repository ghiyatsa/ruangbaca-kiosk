import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../state/kiosk_controller.dart';
import '../../widgets/idle_watcher.dart';
import '../../widgets/kiosk_toast.dart';
import '../borrow/borrow_form.dart';
import '../member/member_form.dart';
import '../return/return_form.dart';
import '../visit/visit_form.dart';
import 'attract_screen.dart';
import 'kiosk_menu.dart';
import 'kiosk_shortcut.dart';

/// Cangkang utama kiosk: menu di kiri, konten layanan di kanan.
class KioskShell extends StatefulWidget {
  const KioskShell({super.key});

  @override
  State<KioskShell> createState() => _KioskShellState();
}

class _KioskShellState extends State<KioskShell> {
  KioskMenu? _active;
  final FocusNode _keyboardFocus = FocusNode();

  void _select(KioskMenu? menu) {
    if (_active == menu) return;
    // Toast hasil aksi tidak boleh tertinggal saat berpindah layanan.
    KioskToast.dismiss();
    setState(() => _active = menu);
    _keyboardFocus.requestFocus();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_active != null) {
        _select(null);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Pintasan menu memakai Alt+1…Alt+4, sehingga angka yang diketik pada
    // kolom isian tidak berpindah menu.
    final menu = KioskShortcut.resolve(
      keyLabel: event.logicalKey.keyLabel,
      altPressed: HardwareKeyboard.instance.isAltPressed,
      ctrlPressed: HardwareKeyboard.instance.isControlPressed,
      metaPressed: HardwareKeyboard.instance.isMetaPressed,
      shiftPressed: HardwareKeyboard.instance.isShiftPressed,
    );
    if (menu != null) {
      _select(menu);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _keyboardFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<KioskController>();

    return IdleWatcher(
      timeout: Duration(seconds: controller.config.idleTimeoutSeconds),
      enabled: _active != null,
      onIdle: () => _select(null),
      child: Focus(
        focusNode: _keyboardFocus,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 340,
              child: _MenuPanel(active: _active, onSelect: _select),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ContentPanel(
                active: _active,
                onClose: () => _select(null),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({required this.active, required this.onSelect});

  final KioskMenu? active;
  final ValueChanged<KioskMenu?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KioskTheme.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final menu in KioskMenu.values) ...[
            _MenuButton(
              menu: menu,
              isActive: active == menu,
              onTap: () => onSelect(menu),
            ),
            const SizedBox(height: 12),
          ],
          const Spacer(),
          const _ShortcutHelp(),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.menu,
    required this.isActive,
    required this.onTap,
  });

  final KioskMenu menu;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive
          ? KioskTheme.primary.withValues(alpha: 0.08)
          : const Color(0xFFF8F9FC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? KioskTheme.primary.withValues(alpha: 0.35)
                  : KioskTheme.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KioskTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(menu.icon, size: 20, color: KioskTheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      menu.label,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E2233),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      menu.description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isActive ? KioskTheme.primary : const Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutHelp extends StatelessWidget {
  const _ShortcutHelp();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KioskTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pintasan',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${KioskMenu.visit.shortcutLabel} Buku Tamu · '
            '${KioskMenu.member.shortcutLabel} Daftar · '
            '${KioskMenu.borrow.shortcutLabel} Pinjam · '
            '${KioskMenu.returnBook.shortcutLabel} Kembali\n'
            'Esc kembali ke layar utama',
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentPanel extends StatelessWidget {
  const _ContentPanel({required this.active, required this.onClose});

  final KioskMenu? active;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<KioskController>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KioskTheme.border),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (active != null) ...[
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: KioskTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    active!.icon,
                    color: KioskTheme.primary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active!.label,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E2233),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        active!.helper,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF6B7280),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Tutup'),
                ),
              ],
            ),
            const Divider(height: 28),
          ],
          Expanded(child: _body(controller)),
        ],
      ),
    );
  }

  Widget _body(KioskController controller) {
    switch (active) {
      case KioskMenu.visit:
        return VisitForm(
          visitorTypeOptions: controller.visitorTypeOptions,
          purposeOptions: controller.purposeOptions,
        );
      case KioskMenu.member:
        return const MemberForm();
      case KioskMenu.borrow:
        return BorrowForm(loanMaxBooks: controller.loanMaxBooks);
      case KioskMenu.returnBook:
        return const ReturnForm();
      case null:
        return AttractScreen(
          session: controller.session,
          stats: controller.stats,
        );
    }
  }
}

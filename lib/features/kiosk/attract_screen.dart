import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/brand.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/ruangbaca_logo.dart';

/// Layar tarik (attract) yang tampil saat tidak ada menu terpilih.
class AttractScreen extends StatefulWidget {
  const AttractScreen({super.key, required this.session, required this.stats});

  final KioskSession session;
  final KioskStats stats;

  @override
  State<AttractScreen> createState() => _AttractScreenState();
}

class _AttractScreenState extends State<AttractScreen> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _greeting {
    final hour = _now.hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_now);
    final timeLabel = DateFormat('HH:mm:ss').format(_now);
    final session = widget.session;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: _OpenBadge(session: session),
          ),
          const Spacer(),
          const RuangBacaLogo(size: 76),
          const SizedBox(height: 20),
          Text(
            '$_greeting, Silakan Mulai',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E2233),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pilih salah satu layanan mandiri di sebelah kiri untuk memulai.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 4),
          const Text(
            Brand.affiliation,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: KioskTheme.border),
            ),
            child: Column(
              children: [
                Text(
                  timeLabel,
                  style: const TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: KioskTheme.primary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Text(
            'STATISTIK HARI INI',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatCard(
                label: 'Kunjungan',
                value: widget.stats.todayVisits,
                icon: Icons.groups_outlined,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Peminjaman',
                value: widget.stats.todayBorrowed,
                icon: Icons.book_outlined,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Pengembalian',
                value: widget.stats.todayReturned,
                icon: Icons.assignment_return_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  const _OpenBadge({required this.session});

  final KioskSession session;

  @override
  Widget build(BuildContext context) {
    final open = session.withinOperatingHours;
    final color = open ? KioskTheme.success : KioskTheme.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            open ? Icons.lock_open : Icons.lock_clock,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            '${open ? 'Buka' : 'Di Luar Jam'} '
            '${session.operatingOpenTime}–${session.operatingCloseTime}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KioskTheme.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: KioskTheme.primary),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E2233),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

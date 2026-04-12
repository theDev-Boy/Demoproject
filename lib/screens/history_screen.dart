import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/app_colors.dart';
import '../config/app_dimensions.dart';
import '../config/app_typography.dart';
import '../models/match_model.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _db = DatabaseService();
  List<MatchModel>? _history;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid != null) {
      final history = await _db.getCallHistory(uid);
      if (mounted) {
        setState(() {
          _history = history;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Call History'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
      ),
      body: _history == null
          ? const Center(child: CircularProgressIndicator())
          : _history!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_toggle_off, size: 80, color: AppColors.textLight),
                      const SizedBox(height: 16),
                      Text('No calls yet', style: AppTypography.headlineSmall.copyWith(color: AppColors.textLight)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history!.length,
                  itemBuilder: (context, index) {
                    final match = _history![index];
                    final partnerName = match.getPartnerName(context.read<AuthProvider>().firebaseUser!.uid) ?? 'Anonymous';
                    final date = DateFormat.yMMMd().add_jm().format(DateTime.fromMillisecondsSinceEpoch(match.startedAt));
                    
                    String duration = 'Short session';
                    if (match.endedAt != null) {
                      final diff = match.endedAt! - match.startedAt;
                      final min = diff ~/ 60000;
                      final sec = (diff % 60000) ~/ 1000;
                      duration = '${min}m ${sec}s';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusM)),
                      elevation: 0,
                      color: AppColors.backgroundSecondary,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(partnerName, style: AppTypography.button),
                        subtitle: Text('$date\n$duration', style: AppTypography.caption),
                        isThreeLine: true,
                        trailing: const Icon(Icons.video_call, color: AppColors.primary),
                      ),
                    );
                  },
                ),
    );
  }
}

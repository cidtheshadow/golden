import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/change_caregiver_provider.dart';

class ChangeCaregiverScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const ChangeCaregiverScreen({
    super.key,
    required this.bookingId,
  });

  @override
  ConsumerState<ChangeCaregiverScreen> createState() =>
      _ChangeCaregiverScreenState();
}

class _ChangeCaregiverScreenState extends ConsumerState<ChangeCaregiverScreen> {
  bool _isLoading = true;
  String? _loadError;
  String? _selectedCaregiverId;
  List<Map<String, dynamic>> _caregivers = const [];

  @override
  void initState() {
    super.initState();
    _loadCaregivers();
  }

  Future<void> _loadCaregivers() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final today = DateTime.now().toUtc();
      final date =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final result = await FirebaseFunctions.instance
          .httpsCallable('getAvailableCaregivers')
          .call({
        'date': date,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final rawList = (data['caregivers'] as List? ?? const []);
      final caregivers = rawList
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _caregivers = caregivers;
        _isLoading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message ?? 'Failed to load caregivers';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changeCaregiverProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Caregiver'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _loadError!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadCaregivers,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _caregivers.isEmpty
                    ? const Center(
                        child: Text(
                          'No caregivers are currently available for this date.\nPlease try a different slot.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              itemCount: _caregivers.length,
                              itemBuilder: (context, index) {
                                final caregiver = _caregivers[index];
                                final caregiverId =
                                    (caregiver['id'] ?? '').toString();
                                final caregiverName =
                                    (caregiver['name'] ?? 'Unknown').toString();
                                final rating =
                                    (caregiver['rating'] as num?)?.toDouble() ??
                                        0.0;
                                final isSelected =
                                    caregiverId == _selectedCaregiverId;

                                return ListTile(
                                  selected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedCaregiverId = caregiverId;
                                    });
                                  },
                                  leading: CircleAvatar(
                                    child: Text(
                                      caregiverName.isNotEmpty
                                          ? caregiverName
                                              .substring(0, 1)
                                              .toUpperCase()
                                          : '?',
                                    ),
                                  ),
                                  title: Text(caregiverName),
                                  subtitle: Text(
                                      'Rating: ${rating.toStringAsFixed(1)}'),
                                  trailing: isSelected
                                      ? Icon(
                                          Icons.check_circle,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        )
                                      : null,
                                );
                              },
                            ),
                          ),
                          if (state.error != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Text(
                                state.error!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: state.isLoading ||
                                        _selectedCaregiverId == null
                                    ? null
                                    : () async {
                                        final rootContext = context;
                                        final ok = await ref
                                            .read(changeCaregiverProvider
                                                .notifier)
                                            .changeCaregiver(
                                              bookingId: widget.bookingId,
                                              newCaregiverId:
                                                  _selectedCaregiverId!,
                                            );
                                        if (!rootContext.mounted) return;
                                        if (ok) {
                                          ScaffoldMessenger.of(rootContext)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Caregiver changed successfully'),
                                            ),
                                          );
                                          rootContext.pop();
                                        }
                                      },
                                child: state.isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Text('Confirm Change'),
                              ),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

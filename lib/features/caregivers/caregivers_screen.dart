/// Caregivers screen — replicates web screen at route /caregivers
/// Public page: search + filter caregiver list
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/colors.dart';
import '../../core/spacing.dart';
import '../../core/typography.dart';

import '../../models/service_personnel_model.dart';
import 'caregivers_controller.dart';
import 'components/caregiver_card_detailed.dart';

class CaregiversScreen extends ConsumerStatefulWidget {
  const CaregiversScreen({super.key});

  @override
  ConsumerState<CaregiversScreen> createState() => _CaregiversScreenState();
}

class _CaregiversScreenState extends ConsumerState<CaregiversScreen> {
  static const int _pageSize = 12;

  final _searchController = TextEditingController();
  String? _expandedCaregiverId;
  String? _selectedSpecialty;
  int _visibleCount = _pageSize;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetVisibleCount() {
    if (_visibleCount == _pageSize) return;
    setState(() => _visibleCount = _pageSize);
  }

  void _loadMoreVisibleItems(int totalCount) {
    if (_visibleCount >= totalCount) return;
    setState(() {
      _visibleCount = min(totalCount, _visibleCount + _pageSize);
    });
  }

  bool _onScrollNotification(
    ScrollNotification notification,
    int totalCount,
  ) {
    if (notification.metrics.pixels >=
        notification.metrics.maxScrollExtent * 0.85) {
      _loadMoreVisibleItems(totalCount);
    }
    return false;
  }

  List<ServicePersonnelModel> _getFilteredData(
      List<ServicePersonnelModel> data) {
    var filtered = data;

    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered =
          filtered.where((p) => p.name.toLowerCase().contains(query)).toList();
    }

    if (_selectedSpecialty != null && _selectedSpecialty != 'All') {
      filtered = filtered
          .where((p) => p.specialties.contains(_selectedSpecialty))
          .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final horizontalPadding =
        isDesktop ? GCSpacing.pagePaddingDesktop : GCSpacing.pagePaddingMobile;

    final caregiversAsync = ref.watch(caregiversProvider);

    return Scaffold(
      backgroundColor: GCColors.background,
      appBar: AppBar(
        title: const Text('Find Caregivers'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: GCSpacing.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // Heading
                  Text('Find Caregivers', style: GCTypography.displayMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Browse our verified caregivers and find the right match for your loved ones.',
                    style: GCTypography.bodyLarge,
                  ),
                  const SizedBox(height: 24),

                  // Search and filters
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) {
                            setState(() {});
                            _resetVisibleCount();
                          },
                          decoration: InputDecoration(
                            hintText: 'Search by name...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(GCSpacing.radiusMd),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: caregiversAsync.when(
                          data: (data) {
                            final specialties = {
                              'All',
                              ...data.expand((p) => p.specialties)
                            }.toList();
                            return Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(GCSpacing.radiusMd),
                                border: Border.all(color: GCColors.border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedSpecialty ?? 'All',
                                  isExpanded: true,
                                  icon: const Icon(Icons.filter_list, size: 20),
                                  items: specialties
                                      .map((s) => DropdownMenuItem(
                                            value: s,
                                            child: Text(s,
                                                style: const TextStyle(
                                                    fontSize: 14)),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    setState(() => _selectedSpecialty = val);
                                    _resetVisibleCount();
                                  },
                                ),
                              ),
                            );
                          },
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Caregiver cards
                  caregiversAsync.when(
                    data: (data) {
                      final filteredData = _getFilteredData(data);
                      final visibleCount =
                          min(filteredData.length, _visibleCount);
                      final visibleData =
                          filteredData.take(visibleCount).toList();
                      final hasMore = visibleCount < filteredData.length;

                      if (filteredData.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No caregivers found.')),
                        );
                      }

                      return NotificationListener<ScrollNotification>(
                        onNotification: (notification) => _onScrollNotification(
                            notification, filteredData.length),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isDesktop)
                              Wrap(
                                spacing: GCSpacing.lg,
                                runSpacing: GCSpacing.lg,
                                children: visibleData
                                    .map((caregiver) => SizedBox(
                                          width: (GCSpacing.maxContentWidth -
                                                  GCSpacing.lg * 2) /
                                              3,
                                          child: _caregiverCard(caregiver),
                                        ))
                                    .toList(),
                              )
                            else
                              Column(
                                children: visibleData
                                    .map((caregiver) =>
                                        _caregiverCard(caregiver))
                                    .toList(),
                              ),
                            if (hasMore)
                              Center(
                                child: TextButton.icon(
                                  onPressed: () => _loadMoreVisibleItems(
                                      filteredData.length),
                                  icon: const Icon(Icons.expand_more),
                                  label: const Text('Load more caregivers'),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                    loading: () => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator())),
                    error: (error, _) =>
                        Center(child: Text('Error loading caregivers: $error')),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _caregiverCard(ServicePersonnelModel caregiver) {
    return CaregiverCard(
      personnel: caregiver,
      isSelected: false, // No selection in this screen, just browsing
      isExpanded: _expandedCaregiverId == caregiver.id,
      onTap: () {
        setState(() {
          _expandedCaregiverId =
              _expandedCaregiverId == caregiver.id ? null : caregiver.id;
        });
      },
    );
  }
}

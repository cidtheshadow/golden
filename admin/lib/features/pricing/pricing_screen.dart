import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/services/admin_service.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_shell.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  List<Map<String, dynamic>> _services = [];
  bool _loading = true;
  String? _error;
  final _platformFeeController = TextEditingController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  num? _toNullableNum(dynamic value) {
    if (value is num) {
      return value;
    }
    if (value is String) {
      final parsed = num.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  num _durationToHours(dynamic value, {num fallback = 0}) {
    final numeric = _toNullableNum(value);
    if (numeric != null) {
      return numeric;
    }
    final text = (value ?? '').toString().trim().toLowerCase();
    if (text.isEmpty) {
      return fallback;
    }
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
    if (match == null) {
      return fallback;
    }
    return num.tryParse(match.group(1) ?? '') ?? fallback;
  }

  Map<String, dynamic>? _primaryOption(Map<String, dynamic> service) {
    final options = service['options'];
    if (options is List) {
      for (final option in options) {
        if (option is Map) {
          return Map<String, dynamic>.from(option);
        }
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _serviceOptions(Map<String, dynamic> service) {
    final options = service['options'];
    if (options is! List) {
      return const [];
    }

    final parsed = <Map<String, dynamic>>[];
    for (final option in options) {
      if (option is Map) {
        parsed.add(Map<String, dynamic>.from(option));
      }
    }
    return parsed;
  }

  String _serviceName(Map<String, dynamic> service) {
    for (final key in ['name', 'title', 'serviceName']) {
      final value = (service[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return 'Service';
  }

  num _servicePrice(Map<String, dynamic> service) {
    final options = _serviceOptions(service);
    if (options.isNotEmpty) {
      final prices = options
          .map((option) => _toNullableNum(option['price']))
          .whereType<num>()
          .toList();
      if (prices.isNotEmpty) {
        prices.sort((a, b) => a.compareTo(b));
        return prices.first;
      }
    }

    final direct = _toNullableNum(service['price'] ?? service['amount']);
    if (direct != null) {
      return direct;
    }
    final option = _primaryOption(service);
    return _toNullableNum(option?['price']) ?? 0;
  }

  num _serviceDurationHours(Map<String, dynamic> service) {
    final options = _serviceOptions(service);
    if (options.isNotEmpty) {
      final durations = options
          .map((option) =>
              _durationToHours(option['durationHours'] ?? option['duration']))
          .where((value) => value > 0)
          .toList();
      if (durations.isNotEmpty) {
        durations.sort((a, b) => a.compareTo(b));
        return durations.first;
      }
    }

    final direct =
        _durationToHours(service['durationHours'] ?? service['duration']);
    if (direct > 0) {
      return direct;
    }
    final option = _primaryOption(service);
    return _durationToHours(option?['durationHours'] ?? option?['duration']);
  }

  String _serviceCategory(Map<String, dynamic> service) {
    final value =
        (service['category'] ?? service['type'] ?? '-').toString().trim();
    return value.isEmpty ? '-' : value;
  }

  bool _serviceIsActive(Map<String, dynamic> service) {
    final isActive = service['isActive'];
    if (isActive is bool) {
      return isActive;
    }
    final isPopular = service['isPopular'];
    if (isPopular is bool) {
      return isPopular;
    }
    return true;
  }

  num _serviceOrder(Map<String, dynamic> service) {
    final explicitOrder = _toNullableNum(service['order']);
    if (explicitOrder != null) {
      return explicitOrder;
    }
    final idOrder = _toNullableNum(service['id']);
    if (idOrder != null && idOrder >= 0) {
      return idOrder;
    }
    return 999;
  }

  String _servicePriceText(Map<String, dynamic> service) {
    final options = _serviceOptions(service);
    if (options.isNotEmpty) {
      final prices = options
          .map((option) => _toNullableNum(option['price']))
          .whereType<num>()
          .toList();
      if (prices.isNotEmpty) {
        prices.sort((a, b) => a.compareTo(b));
        if (prices.first == prices.last) {
          return 'Rs ${prices.first}';
        }
        return 'Rs ${prices.first} - Rs ${prices.last}';
      }
    }
    return 'Rs ${_servicePrice(service)}';
  }

  String _serviceDurationText(Map<String, dynamic> service) {
    final options = _serviceOptions(service);
    if (options.isNotEmpty) {
      final durations = options
          .map((option) =>
              _durationToHours(option['durationHours'] ?? option['duration']))
          .where((value) => value > 0)
          .map((value) => value % 1 == 0 ? '${value.toInt()} h' : '$value h')
          .toSet()
          .toList();
      if (durations.isNotEmpty) {
        return durations.join(', ');
      }
    }
    return '${_serviceDurationHours(service)} h';
  }

  String _serviceVariantsText(Map<String, dynamic> service) {
    final options = _serviceOptions(service);
    if (options.isEmpty) {
      return '-';
    }

    final variants = options.map((option) {
      final duration =
          (option['duration'] ?? option['durationHours'] ?? '-').toString();
      final price = _toNullableNum(option['price']);
      final priceText = price == null ? 'Rs -' : 'Rs $price';
      return '${duration.trim()} -> $priceText';
    }).toList();

    if (variants.length <= 2) {
      return variants.join(' | ');
    }
    return '${variants.take(2).join(' | ')} +${variants.length - 2} more';
  }

  List<String> _serviceIncludedItems(Map<String, dynamic> service) {
    final raw = service['includedItems'];
    if (raw is! List) {
      return const [];
    }

    return raw
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _serviceIncludedItemsText(Map<String, dynamic> service) {
    final items = _serviceIncludedItems(service);
    if (items.isEmpty) {
      return '-';
    }
    if (items.length <= 2) {
      return items.join(' | ');
    }
    return '${items.take(2).join(' | ')} +${items.length - 2} more';
  }

  Future<void> _uploadServiceImage(String serviceId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Unable to read image')));
      return;
    }

    final extension = (file.extension ?? '').toLowerCase();
    String contentType = 'image/jpeg';
    if (extension == 'png') {
      contentType = 'image/png';
    } else if (extension == 'webp') {
      contentType = 'image/webp';
    } else if (extension == 'gif') {
      contentType = 'image/gif';
    }

    try {
      await AdminService.instance.uploadEntityImage(
        entityType: 'service',
        entityId: serviceId,
        bytes: bytes,
        contentType: contentType,
        fileName: file.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service image uploaded')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _platformFeeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await AdminService.instance.getServices();
      final services =
          List<Map<String, dynamic>>.from(result['services'] as List? ?? []);
      if (!mounted) {
        return;
      }

      setState(() {
        _services = services;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: 'Pricing',
      currentPath: '/pricing',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddServiceDialog,
        backgroundColor: AdminTheme.gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Service'),
      ),
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AdminTheme.gold))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: AdminTheme.error)))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Row(
                        children: [
                          const Text('Platform Fee %',
                              style:
                                  TextStyle(color: AdminTheme.textSecondary)),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: _platformFeeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]')),
                              ],
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: 'e.g. 12.5',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _updatePlatformFee,
                            icon: const Icon(Icons.percent_rounded, size: 16),
                            label: const Text('Update Fee'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _verticalScrollController,
                        padding: const EdgeInsets.all(12),
                        child: LayoutBuilder(
                          builder: (context, constraints) =>
                              ScrollConfiguration(
                            behavior: const MaterialScrollBehavior().copyWith(
                              dragDevices: {
                                PointerDeviceKind.touch,
                                PointerDeviceKind.mouse,
                                PointerDeviceKind.trackpad,
                                PointerDeviceKind.stylus,
                              },
                            ),
                            child: Scrollbar(
                              controller: _horizontalScrollController,
                              thumbVisibility: true,
                              interactive: true,
                              child: SingleChildScrollView(
                                controller: _horizontalScrollController,
                                scrollDirection: Axis.horizontal,
                                primary: false,
                                physics: const ClampingScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                      minWidth: constraints.maxWidth),
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                        AdminTheme.surfaceHigh
                                            .withValues(alpha: 0.35)),
                                    dataRowColor: WidgetStateProperty.all(
                                        AdminTheme.surface),
                                    columns: const [
                                      DataColumn(label: Text('Image')),
                                      DataColumn(label: Text('Name')),
                                      DataColumn(label: Text('Category')),
                                      DataColumn(label: Text('Price')),
                                      DataColumn(label: Text('Duration')),
                                      DataColumn(label: Text('Variants')),
                                      DataColumn(label: Text('Included Items')),
                                      DataColumn(label: Text('Order')),
                                      DataColumn(label: Text('Max Qty')),
                                      DataColumn(label: Text('Active')),
                                      DataColumn(label: Text('Description')),
                                      DataColumn(label: Text('Actions')),
                                    ],
                                    rows: _services.map((service) {
                                      final id = service['id'] as String? ?? '';
                                      final imageUrl =
                                          (service['imageUrl'] as String? ?? '')
                                              .trim();
                                      final name = _serviceName(service);
                                      final category =
                                          _serviceCategory(service);
                                      final priceText =
                                          _servicePriceText(service);
                                      final durationText =
                                          _serviceDurationText(service);
                                      final variantsText =
                                          _serviceVariantsText(service);
                                      final includedItemsText =
                                          _serviceIncludedItemsText(service);
                                      final order = _serviceOrder(service);
                                      final maxQuantity = _toNullableNum(
                                          service['maxQuantity']);
                                      final isActive =
                                          _serviceIsActive(service);
                                      final description =
                                          service['description'] as String? ??
                                              '';

                                      return DataRow(cells: [
                                        DataCell(Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor:
                                                  AdminTheme.surfaceHigh,
                                              backgroundImage: imageUrl.isEmpty
                                                  ? null
                                                  : NetworkImage(imageUrl),
                                              child: imageUrl.isEmpty
                                                  ? const Icon(
                                                      Icons.image_outlined,
                                                      size: 16,
                                                      color: AdminTheme
                                                          .textSecondary,
                                                    )
                                                  : null,
                                            ),
                                            IconButton(
                                              tooltip: 'Upload image',
                                              onPressed: () =>
                                                  _uploadServiceImage(id),
                                              icon: const Icon(
                                                  Icons.upload_rounded,
                                                  color: Colors.teal),
                                            ),
                                          ],
                                        )),
                                        DataCell(Text(name)),
                                        DataCell(Text(category)),
                                        DataCell(Text(priceText)),
                                        DataCell(SizedBox(
                                          width: 120,
                                          child: Text(
                                            durationText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        )),
                                        DataCell(SizedBox(
                                          width: 220,
                                          child: Text(
                                            variantsText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        )),
                                        DataCell(SizedBox(
                                          width: 260,
                                          child: Text(
                                            includedItemsText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        )),
                                        DataCell(Text('$order')),
                                        DataCell(Text('${maxQuantity ?? '-'}')),
                                        DataCell(Text(isActive ? 'Yes' : 'No')),
                                        DataCell(SizedBox(
                                            width: 220,
                                            child: Text(description,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis))),
                                        DataCell(Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'Edit service',
                                              onPressed: () =>
                                                  _editService(service),
                                              icon: const Icon(
                                                  Icons.edit_rounded,
                                                  color: Colors.blue),
                                            ),
                                            IconButton(
                                              tooltip: isActive
                                                  ? 'Disable service'
                                                  : 'Enable service',
                                              onPressed: () =>
                                                  _toggleServiceActive(
                                                      id, isActive),
                                              icon: Icon(
                                                isActive
                                                    ? Icons.toggle_on_rounded
                                                    : Icons.toggle_off_rounded,
                                                color: isActive
                                                    ? Colors.green
                                                    : Colors.orange,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Delete service',
                                              onPressed: () =>
                                                  _deleteService(id),
                                              icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  color: AdminTheme.error),
                                            ),
                                          ],
                                        )),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _toggleServiceActive(String serviceId, bool isActive) async {
    try {
      await AdminService.instance
          .updatePricing(serviceId, {'isActive': !isActive});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(!isActive ? 'Service enabled' : 'Service disabled')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _updatePlatformFee() async {
    final fee = double.tryParse(_platformFeeController.text.trim());
    if (fee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid fee percent')));
      return;
    }

    try {
      await AdminService.instance.updatePlatformFee(fee);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Platform fee updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _editService(Map<String, dynamic> service) async {
    final rootContext = context;
    final serviceId = service['id'] as String? ?? '';
    final nameController = TextEditingController(text: _serviceName(service));
    final categoryController =
        TextEditingController(text: _serviceCategory(service));
    final descriptionController =
        TextEditingController(text: service['description'] as String? ?? '');
    final orderController =
        TextEditingController(text: '${_serviceOrder(service).toInt()}');
    final maxQtyController = TextEditingController(
        text: '${_toNullableNum(service['maxQuantity']) ?? ''}');
    final includedItemControllers = _serviceIncludedItems(service)
        .map((item) => TextEditingController(text: item))
        .toList();
    if (includedItemControllers.isEmpty) {
      includedItemControllers.add(TextEditingController());
    }
    bool isActive = _serviceIsActive(service);

    final existingOptions = _serviceOptions(service);
    final variantDrafts = <_VariantDraft>[];
    if (existingOptions.isNotEmpty) {
      for (final option in existingOptions) {
        final durationText =
            (option['duration'] ?? option['durationHours'] ?? '').toString();
        final priceText = '${_toNullableNum(option['price']) ?? ''}';
        variantDrafts.add(
          _VariantDraft(
            durationController: TextEditingController(text: durationText),
            priceController: TextEditingController(text: priceText),
            seed: option,
          ),
        );
      }
    }
    if (variantDrafts.isEmpty) {
      variantDrafts.add(
        _VariantDraft(
          durationController: TextEditingController(
              text: '${_serviceDurationHours(service).toInt()} hours'),
          priceController:
              TextEditingController(text: '${_servicePrice(service)}'),
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          backgroundColor: AdminTheme.surface,
          title: Text('Edit Service ($serviceId)'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: categoryController,
                          decoration:
                              const InputDecoration(labelText: 'Category'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: orderController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: false),
                          decoration: const InputDecoration(labelText: 'Order'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: maxQtyController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: false),
                    decoration:
                        const InputDecoration(labelText: 'Max Quantity'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Included Items',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AdminTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (int i = 0; i < includedItemControllers.length; i++) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: includedItemControllers[i],
                            decoration: InputDecoration(
                              labelText: 'Included item ${i + 1}',
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove item',
                          onPressed: includedItemControllers.length <= 1
                              ? null
                              : () => setLocalState(() {
                                    final removed =
                                        includedItemControllers.removeAt(i);
                                    removed.dispose();
                                  }),
                          icon: const Icon(Icons.remove_circle_outline_rounded,
                              color: AdminTheme.error),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => setLocalState(() {
                        includedItemControllers.add(TextEditingController());
                      }),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Included Item'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Duration & Price Variants',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AdminTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (int i = 0; i < variantDrafts.length; i++) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: variantDrafts[i].durationController,
                            decoration: const InputDecoration(
                              labelText: 'Duration (e.g. 2 hours)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: variantDrafts[i].priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                                const InputDecoration(labelText: 'Price (Rs)'),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Move up',
                          onPressed: i == 0
                              ? null
                              : () => setLocalState(() {
                                    final current = variantDrafts[i];
                                    variantDrafts[i] = variantDrafts[i - 1];
                                    variantDrafts[i - 1] = current;
                                  }),
                          icon:
                              const Icon(Icons.arrow_upward_rounded, size: 18),
                        ),
                        IconButton(
                          tooltip: 'Move down',
                          onPressed: i == variantDrafts.length - 1
                              ? null
                              : () => setLocalState(() {
                                    final current = variantDrafts[i];
                                    variantDrafts[i] = variantDrafts[i + 1];
                                    variantDrafts[i + 1] = current;
                                  }),
                          icon: const Icon(Icons.arrow_downward_rounded,
                              size: 18),
                        ),
                        IconButton(
                          tooltip: 'Remove variant',
                          onPressed: variantDrafts.length <= 1
                              ? null
                              : () => setLocalState(() {
                                    final removed = variantDrafts.removeAt(i);
                                    removed.dispose();
                                  }),
                          icon: const Icon(Icons.remove_circle_outline_rounded,
                              color: AdminTheme.error),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => setLocalState(() {
                        variantDrafts.add(
                          _VariantDraft(
                            durationController: TextEditingController(),
                            priceController: TextEditingController(),
                          ),
                        );
                      }),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Variant'),
                    ),
                  ),
                  SwitchListTile(
                    dense: true,
                    value: isActive,
                    onChanged: (value) => setLocalState(() => isActive = value),
                    title: const Text('Service Active'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final name = nameController.text.trim();
                  final options = <Map<String, dynamic>>[];
                  final prices = <num>[];
                  final durations = <num>[];
                  for (final draft in variantDrafts) {
                    final durationText = draft.durationController.text.trim();
                    final price =
                        num.tryParse(draft.priceController.text.trim());
                    final durationHours = _durationToHours(durationText);

                    if (durationText.isEmpty && price == null) {
                      continue;
                    }

                    if (durationText.isEmpty || price == null || price <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Each variant needs duration text and a positive price'),
                        ),
                      );
                      return;
                    }

                    prices.add(price);
                    if (durationHours > 0) {
                      durations.add(durationHours);
                    }

                    options.add({
                      ...draft.seed,
                      'duration': durationText,
                      'durationHours': durationHours > 0 ? durationHours : null,
                      'price': price,
                    });
                  }

                  if (name.isEmpty || options.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Name and at least one variant required')),
                    );
                    return;
                  }

                  prices.sort((a, b) => a.compareTo(b));
                  durations.sort((a, b) => a.compareTo(b));
                  final minPrice = prices.first;
                  final minDuration = durations.isEmpty ? 1 : durations.first;
                  final seen = <String>{};
                  final includedItems = includedItemControllers
                      .map((controller) => controller.text.trim())
                      .where((item) => item.isNotEmpty)
                      .where((item) {
                    final normalized = item.toLowerCase();
                    if (seen.contains(normalized)) {
                      return false;
                    }
                    seen.add(normalized);
                    return true;
                  }).toList();

                  final updates = <String, dynamic>{
                    'name': name,
                    'title': name,
                    'category': categoryController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'price': minPrice,
                    'durationHours': minDuration,
                    'order': int.tryParse(orderController.text.trim()) ?? 999,
                    'isActive': isActive,
                    'isPopular': isActive,
                    'options': options,
                    'includedItems': includedItems,
                  };

                  final parsedMaxQuantity =
                      int.tryParse(maxQtyController.text.trim());
                  if (parsedMaxQuantity != null) {
                    updates['maxQuantity'] = parsedMaxQuantity;
                  }

                  await AdminService.instance.updatePricing(
                    serviceId,
                    updates,
                  );
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  if (!rootContext.mounted) return;
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                      const SnackBar(content: Text('Service updated')));
                  _load();
                } catch (e) {
                  if (!rootContext.mounted) return;
                  ScaffoldMessenger.of(rootContext)
                      .showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    categoryController.dispose();
    descriptionController.dispose();
    orderController.dispose();
    maxQtyController.dispose();
    for (final controller in includedItemControllers) {
      controller.dispose();
    }
    for (final draft in variantDrafts) {
      draft.dispose();
    }
  }

  Future<void> _showAddServiceDialog() async {
    final rootContext = context;
    final nameController = TextEditingController();
    final variantDrafts = <_VariantDraft>[
      _VariantDraft(
        durationController: TextEditingController(text: '1 hour'),
        priceController: TextEditingController(),
      ),
    ];

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
                backgroundColor: AdminTheme.surface,
                title: const Text('Create Service',
                    style: TextStyle(color: AdminTheme.textPrimary)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration:
                          const InputDecoration(labelText: 'Service name'),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Duration & Price Variants',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AdminTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (int i = 0; i < variantDrafts.length; i++) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: variantDrafts[i].durationController,
                              decoration: const InputDecoration(
                                labelText: 'Duration (e.g. 2 hours)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 140,
                            child: TextField(
                              controller: variantDrafts[i].priceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'Price (Rs)'),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove variant',
                            onPressed: variantDrafts.length <= 1
                                ? null
                                : () => setLocalState(() {
                                      final removed = variantDrafts.removeAt(i);
                                      removed.dispose();
                                    }),
                            icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                                color: AdminTheme.error),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => setLocalState(() {
                          variantDrafts.add(
                            _VariantDraft(
                              durationController: TextEditingController(),
                              priceController: TextEditingController(),
                            ),
                          );
                        }),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add Variant'),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Dismiss')),
                  ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final options = <Map<String, dynamic>>[];
                      final prices = <num>[];
                      final durations = <num>[];

                      for (final draft in variantDrafts) {
                        final durationText =
                            draft.durationController.text.trim();
                        final price =
                            num.tryParse(draft.priceController.text.trim());
                        final durationHours = _durationToHours(durationText);

                        if (durationText.isEmpty && price == null) {
                          continue;
                        }

                        if (durationText.isEmpty ||
                            price == null ||
                            price <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Each variant needs duration text and a positive price')),
                          );
                          return;
                        }

                        prices.add(price);
                        if (durationHours > 0) {
                          durations.add(durationHours);
                        }

                        options.add({
                          'duration': durationText,
                          'durationHours':
                              durationHours > 0 ? durationHours : null,
                          'price': price,
                        });
                      }

                      if (name.isEmpty || options.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Name and variants are required')),
                        );
                        return;
                      }

                      prices.sort((a, b) => a.compareTo(b));
                      durations.sort((a, b) => a.compareTo(b));

                      try {
                        await AdminService.instance.createService({
                          'name': name,
                          'title': name,
                          'price': prices.first,
                          'durationHours':
                              durations.isEmpty ? 1 : durations.first,
                          'options': options,
                          'isActive': true,
                        });
                        if (!context.mounted) {
                          return;
                        }
                        Navigator.of(context).pop();
                        if (!rootContext.mounted) return;
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          const SnackBar(content: Text('Service created')),
                        );
                        _load();
                      } catch (e) {
                        if (!mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())));
                      }
                    },
                    child: const Text('Create'),
                  ),
                ],
              )),
    );

    nameController.dispose();
    for (final draft in variantDrafts) {
      draft.dispose();
    }
  }

  Future<void> _deleteService(String serviceId) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AdminTheme.surface,
        title: const Text('Delete Service',
            style: TextStyle(color: AdminTheme.textPrimary)),
        content: const Text(
          'This action cannot be undone. Continue?',
          style: TextStyle(color: AdminTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await AdminService.instance.deleteService(serviceId);
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Service deleted')));
                _load();
              } catch (e) {
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _VariantDraft {
  _VariantDraft({
    required this.durationController,
    required this.priceController,
    Map<String, dynamic>? seed,
  }) : seed = seed ?? const {};

  final TextEditingController durationController;
  final TextEditingController priceController;
  final Map<String, dynamic> seed;

  void dispose() {
    durationController.dispose();
    priceController.dispose();
  }
}

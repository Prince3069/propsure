import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/models/listing_model.dart';
import '../../../services/location_service.dart';
import '../listings/add_listing_screen.dart' show AreaBoundsLookup;
import '../../providers/app_providers.dart';

const String _template = 'title,area,bedrooms,bathrooms,annual_rent,description\n'
    '2-bedroom flat,Gwarinpa,2,2,2400000,Bright flat near the main road\n';

class _Row {
  final String title, area, description;
  final int beds, baths;
  final double price;
  final String? problem;
  _Row(this.title, this.area, this.beds, this.baths, this.price, this.description, this.problem);
  bool get valid => problem == null;
}

/// Imports rows as DRAFTS only. Imported text never marks a property
/// verified, and drafts still need media and a review before publishing.
class BulkImportScreen extends ConsumerStatefulWidget {
  const BulkImportScreen({super.key});
  @override
  ConsumerState<BulkImportScreen> createState() => _BulkState();
}

class _BulkState extends ConsumerState<BulkImportScreen> {
  List<_Row> _rows = const [];
  bool _busy = false;
  String? _error;

  Future<void> _pick() async {
    setState(() => _error = null);
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['csv'], withData: true);
    final bytes = res?.files.single.bytes;
    if (bytes == null) {
      return;
    }
    try {
      final table = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(String.fromCharCodes(bytes).replaceAll('\r\n', '\n'));
      if (table.length < 2) {
        setState(() => _error = 'That file has no rows.');
        return;
      }
      final head = table.first.map((e) => e.toString().trim().toLowerCase()).toList();
      int col(String n) => head.indexOf(n);
      String cell(List r, String n) { final i = col(n); return (i < 0 || i >= r.length) ? '' : r[i].toString().trim(); }
      final areas = AppConstants.abujaAreas.map((a) => a.toLowerCase()).toSet();
      final rows = <_Row>[];
      for (final r in table.skip(1).take(100)) {
        if (r.every((c) => c.toString().trim().isEmpty)) {
          continue;
        }
        final title = cell(r, 'title');
        final area = cell(r, 'area');
        final price = Money.parse(cell(r, 'annual_rent')) ?? 0;
        String? problem;
        if (title.length < 3) {
          problem = 'Missing title';
        } else if (!areas.contains(area.toLowerCase())) {
          problem = 'Unknown area';
        } else if (price <= 0) {
          problem = 'Missing price';
        }
        rows.add(_Row(title.isEmpty ? '(no title)' : title, area, int.tryParse(cell(r, 'bedrooms')) ?? 0, int.tryParse(cell(r, 'bathrooms')) ?? 0, price, cell(r, 'description'), problem));
      }
      setState(() => _rows = rows);
    } catch (_) {
      setState(() => _error = 'We could not read that file. Use the template and save it as CSV.');
    }
  }

  Future<void> _import() async {
    final user = ref.read(currentUserModelProvider).asData?.value;
    if (user == null) {
      return;
    }
    final valid = _rows.where((r) => r.valid).toList();
    setState(() { _busy = true; _error = null; });
    try {
      final repo = ref.read(listingRepositoryProvider);
      final loc = LocationService();
      for (final r in valid) {
        final b = AreaBoundsLookup.centre(r.area);
        final map = loc.buildLocationMap(latitude: b.$1, longitude: b.$2, area: r.area, fullAddress: '${r.area}, Abuja');
        await repo.saveDraft(ListingModel(
          id: '',
          title: r.title,
          description: r.description,
          price: r.price,
          propertyType: 'Flat / Apartment',
          bedrooms: r.beds,
          bathrooms: r.baths,
          toilets: r.baths,
          location: PropertyLocation.fromMap({...map, 'locationPrecision': 'approximate'}),
          images: const [],
          agentId: user.uid,
          agentName: user.name,
          agentPhone: user.phone,
          agentPhoto: user.profilePhoto,
          createdAt: DateTime.now(),
        ));
      }
      if (!mounted) {
        return;
      }
      showPsSnack(context, '${valid.length} drafts created. Add media and review each before publishing.');
      context.go('/my-listings');
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Some drafts could not be created. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final validCount = _rows.where((r) => r.valid).length;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const PsTopBar(title: 'Import listings'),
      body: Column(children: [
        Expanded(child: ListView(padding: kPagePadding, children: [
          const PsHeadline('Add several homes', accent: 'at once.', size: 34),
          const SizedBox(height: 8),
          Text('Import into drafts. Review before publishing.', style: AppText.bodyMuted),
          const SizedBox(height: 16),
          PsCard(onTap: _pick, semanticLabel: 'Choose CSV file', child: Row(children: [
            const Icon(Icons.insert_drive_file_outlined, size: 40, color: AppColors.primary),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Choose CSV file', style: AppText.h3), Text('Select a file from your device', style: AppText.small)])),
            const Icon(Icons.chevron_right_rounded),
          ])),
          const SizedBox(height: 10),
          PsLink('Download template', onTap: () async { await Clipboard.setData(const ClipboardData(text: _template)); if (context.mounted) showPsSnack(context, 'Template copied. Paste it into a spreadsheet and save as CSV.'); }),
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Preview', style: AppText.h2),
            const SizedBox(height: 10),
            PsCard(padding: EdgeInsets.zero, child: Column(children: [
              for (final r in _rows.take(30)) Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r.title} · ${r.area}', style: AppText.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text('${r.beds} beds · ${r.baths} baths${r.price > 0 ? ' · ${Money.short(r.price.round())}' : ''}', style: AppText.small),
                  ])),
                  const SizedBox(width: 8),
                  PsPill(r.valid ? 'Ready as draft' : r.problem!, tone: r.valid ? PsTone.success : PsTone.warning, icon: r.valid ? Icons.check_circle_rounded : Icons.error_outline_rounded, small: true),
                ]),
              ),
              Padding(padding: const EdgeInsets.all(14), child: Row(children: [const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.text2), const SizedBox(width: 8), Expanded(child: Text('Imported text does not verify a property. Drafts still need photos or video.', style: AppText.small))])),
            ])),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: AppText.small.copyWith(color: AppColors.error, fontWeight: FontWeight.w600))),
          const SizedBox(height: 12),
          PsCard(onTap: () => context.push('/whatsapp-assist'), semanticLabel: 'Import from WhatsApp instead', child: Row(children: [
            const Icon(Icons.chat_rounded, size: 32, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(child: Text('Import from WhatsApp instead', style: AppText.title)),
            const Icon(Icons.chevron_right_rounded),
          ])),
        ])),
        PsBottomBar(row: false, children: [
          PsButton(_rows.isEmpty ? 'Import drafts' : 'Import $validCount valid draft${validCount == 1 ? '' : 's'}', loading: _busy, onPressed: validCount == 0 ? null : _import),
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('This will only create drafts. You can review and edit before publishing.', textAlign: TextAlign.center, style: AppText.caption)),
        ]),
      ]),
    );
  }
}

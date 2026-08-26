// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';

class BulkUploadScreen extends ConsumerStatefulWidget {
  const BulkUploadScreen({super.key});
  @override
  ConsumerState<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends ConsumerState<BulkUploadScreen> {
  List<Map<String, dynamic>> _parsed = [];
  List<String> _errors = [];
  bool _uploading = false;
  int _uploaded = 0;
  int _failed = 0;
  String _status = '';

  // CSV column order expected:
  // title, description, price, property_type, area, city, bedrooms, bathrooms,
  // toilets, furnished, condition, amenities (semicolon separated), category
  static const _requiredColumns = [
    'title',
    'price',
    'property_type',
    'area',
    'bedrooms',
    'bathrooms',
  ];

  Future<void> _pickCSV() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _parsed = [];
      _errors = [];
      _status = 'Parsing CSV…';
    });

    try {
      final bytes = result.files.first.bytes;
      if (bytes == null) return;
      final content = utf8.decode(bytes);
      final rows = const CsvToListConverter().convert(content);

      if (rows.isEmpty) {
        setState(() {
          _errors = ['CSV file is empty.'];
          _status = '';
        });
        return;
      }

      // First row = headers
      final headers =
          rows.first.map((h) => h.toString().toLowerCase().trim()).toList();

      // Validate required columns
      final missing =
          _requiredColumns.where((c) => !headers.contains(c)).toList();
      if (missing.isNotEmpty) {
        setState(() {
          _errors = ['Missing required columns: ${missing.join(", ")}'];
          _status = '';
        });
        return;
      }

      final parsed = <Map<String, dynamic>>[];
      final errors = <String>[];

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.every((cell) => cell.toString().trim().isEmpty)) {
          continue; // skip blank rows
        }

        final record = <String, dynamic>{};
        for (int j = 0; j < headers.length && j < row.length; j++) {
          record[headers[j]] = row[j].toString().trim();
        }

        // Validate row
        final rowErrors = <String>[];
        if ((record['title'] as String? ?? '').isEmpty) {
          rowErrors.add('title is empty');
        }
        final price = double.tryParse(record['price']?.toString() ?? '');
        if (price == null || price <= 0) rowErrors.add('invalid price');
        final beds = int.tryParse(record['bedrooms']?.toString() ?? '');
        if (beds == null) rowErrors.add('invalid bedrooms');

        if (rowErrors.isNotEmpty) {
          errors.add('Row ${i + 1}: ${rowErrors.join(", ")}');
        } else {
          parsed.add({
            ...record,
            'price': price,
            'bedrooms': beds,
            'bathrooms':
                int.tryParse(record['bathrooms']?.toString() ?? '') ?? 1,
            'toilets': int.tryParse(record['toilets']?.toString() ?? '') ?? 1,
            '_rowNum': i + 1,
          });
        }
      }

      setState(() {
        _parsed = parsed;
        _errors = errors;
        _status = parsed.isEmpty
            ? 'No valid rows found.'
            : 'Found ${parsed.length} valid listings.${errors.isNotEmpty ? " ${errors.length} rows have errors." : ""}';
      });
    } catch (e) {
      setState(() {
        _errors = ['Failed to parse CSV: $e'];
        _status = '';
      });
    }
  }

  Future<void> _uploadAll() async {
    if (_parsed.isEmpty) return;
    final user = ref.read(currentUserModelProvider).value;
    if (user == null) return;

    setState(() {
      _uploading = true;
      _uploaded = 0;
      _failed = 0;
      _status = 'Uploading…';
    });

    final db = FirebaseFirestore.instance;
    const uuid = Uuid();

    for (final row in _parsed) {
      try {
        final amenitiesCsv = row['amenities'] as String? ?? '';
        final amenities = amenitiesCsv.isEmpty
            ? <String>[]
            : amenitiesCsv
                .split(';')
                .map((a) => a.trim())
                .where((a) => a.isNotEmpty)
                .toList();

        final area = row['area'] as String? ?? 'Abuja';
        await db.collection(AppConstants.colListings).doc(uuid.v4()).set({
          'title': row['title'],
          'description': row['description'] ?? '',
          'price': row['price'],
          'propertyType': row['property_type'] ?? 'Flat / Apartment',
          'category': row['category'] ?? 'For Rent',
          'bedrooms': row['bedrooms'],
          'bathrooms': row['bathrooms'],
          'toilets': row['toilets'],
          'isFurnished':
              (row['furnished'] as String? ?? '').toLowerCase() == 'yes',
          'condition': row['condition'] ?? 'New',
          'amenities': amenities,
          'area': area,
          'city': row['city'] ?? 'Abuja',
          'state': 'FCT',
          'location': {
            'area': area,
            'city': row['city'] ?? 'Abuja',
            'state': 'FCT',
            'fullAddress': '$area, ${row['city'] ?? "Abuja"}, FCT',
            'latitude': AppConstants.abujaLat,
            'longitude': AppConstants.abujaLng,
          },
          'agentId': user.uid,
          'agentName': user.name,
          'agentPhone': user.phone,
          'agentPhoto': user.profilePhoto ?? '',
          'images': <String>[],
          'status': 'active',
          'isVerified': false, // Bulk imports start unverified
          'isFeatured': false,
          'source': 'bulk_upload',
          'viewCount': 0,
          'inquiryCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'expiresAt':
              Timestamp.fromDate(DateTime.now().add(const Duration(days: 90))),
        });
        setState(() {
          _uploaded++;
          _status = 'Uploaded $_uploaded / ${_parsed.length}…';
        });
        // Small delay to avoid Firestore write limits
        if (_uploaded % 10 == 0) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        setState(() => _failed++);
      }
    }

    setState(() {
      _uploading = false;
      _status =
          '✅ Done! $_uploaded uploaded${_failed > 0 ? ", $_failed failed" : ""}.';
    });
  }

  void _downloadTemplate() {
    const template =
        'title,description,price,property_type,area,city,bedrooms,bathrooms,toilets,furnished,condition,amenities,category\n'
        '"3 Bedroom Flat in Maitama","Spacious flat with all amenities",2500000,"Flat / Apartment","Maitama","Abuja",3,2,3,"Yes","New","Generator;AC;Borehole","For Rent"\n'
        '"2 Bedroom Duplex Wuse 2","Modern duplex in prime location",1800000,"Duplex","Wuse 2","Abuja",2,2,2,"No","Fairly Used","Generator;Parking","For Rent"\n';
    // Copy to clipboard (web-safe)
    Clipboard.setData(const ClipboardData(text: template));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'CSV template copied to clipboard! Paste into Excel/Google Sheets.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Bulk Upload Listings',
            style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Intro card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📋 Bulk Listing Import',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                    SizedBox(height: 6),
                    Text(
                        'Upload a CSV file with multiple properties at once. Perfect for agents with large portfolios.',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12, height: 1.5)),
                    SizedBox(height: 14),
                    Row(children: [
                      _WhiteChip('Max 500 rows'),
                      SizedBox(width: 8),
                      _WhiteChip('CSV format'),
                      SizedBox(width: 8),
                      _WhiteChip('Starts as Unverified'),
                    ]),
                  ]),
            ),
            const SizedBox(height: 20),

            // Template download
            OutlinedButton.icon(
              onPressed: _downloadTemplate,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Copy CSV Template'),
            ),
            const SizedBox(height: 6),
            const Text(
                'Download the template, fill it in Excel or Google Sheets, then upload the .csv file.',
                style: TextStyle(fontSize: 12, color: AppColors.text3)),
            const SizedBox(height: 20),

            // Column guide
            _ColumnGuide(),
            const SizedBox(height: 20),

            // Upload area
            GestureDetector(
              onTap: _uploading ? null : _pickCSV,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  color: _parsed.isNotEmpty
                      ? AppColors.primaryPale
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _parsed.isNotEmpty
                        ? AppColors.primary
                        : AppColors.border,
                    width: _parsed.isNotEmpty ? 2 : 1,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(children: [
                  Icon(
                    _parsed.isNotEmpty
                        ? Icons.check_circle_rounded
                        : Icons.upload_file_rounded,
                    size: 44,
                    color: _parsed.isNotEmpty
                        ? AppColors.primary
                        : AppColors.text3,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _parsed.isNotEmpty
                        ? '${_parsed.length} listings ready to upload'
                        : 'Tap to select CSV file',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _parsed.isNotEmpty
                            ? AppColors.primary
                            : AppColors.text2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                      _status.isEmpty
                          ? 'Supported: .csv files up to 5MB'
                          : _status,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.text3)),
                ]),
              ),
            ),

            // Errors
            if (_errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.2)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${_errors.length} row error${_errors.length > 1 ? "s" : ""} found:',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                              fontSize: 13)),
                      const SizedBox(height: 8),
                      ..._errors.take(5).map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(children: [
                              const Icon(Icons.close_rounded,
                                  size: 13, color: AppColors.error),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(e,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.error))),
                            ]),
                          )),
                      if (_errors.length > 5)
                        Text('… and ${_errors.length - 5} more',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.text3)),
                    ]),
              ),
            ],

            // Preview table
            if (_parsed.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Preview (first 5 rows)',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _PreviewTable(rows: _parsed.take(5).toList()),
            ],

            // Upload button
            if (_parsed.isNotEmpty && !_uploading) ...[
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                    child: ElevatedButton.icon(
                  onPressed: _uploadAll,
                  icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                  label: Text('Upload ${_parsed.length} Listings',
                      style: GoogleFonts.syne(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: AppColors.primary,
                  ),
                )),
              ]),
              const SizedBox(height: 8),
              const Text(
                  'All imported listings will be marked "Unverified" until reviewed.',
                  style: TextStyle(fontSize: 11, color: AppColors.text3)),
            ],

            // Progress
            if (_uploading) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: _parsed.isNotEmpty ? _uploaded / _parsed.length : null,
                color: AppColors.primary,
                backgroundColor: AppColors.border,
              ),
              const SizedBox(height: 8),
              Text(_status,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ],

            const SizedBox(height: 80),
          ]),
        ),
      ),
    );
  }
}

class _WhiteChip extends StatelessWidget {
  final String label;
  const _WhiteChip(this.label);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(99)),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)));
}

class _ColumnGuide extends StatelessWidget {
  static const _cols = [
    ('title*', 'Property title', 'String'),
    ('price*', 'Annual rent in ₦', 'Number'),
    ('property_type*', 'Flat / Apartment, Duplex…', 'String'),
    ('area*', 'Wuse 2, Maitama…', 'String'),
    ('bedrooms*', 'Number of bedrooms', 'Integer'),
    ('bathrooms*', 'Number of bathrooms', 'Integer'),
    ('description', 'Property description', 'String'),
    ('city', 'Abuja, Lagos…', 'String'),
    ('toilets', 'Number of toilets', 'Integer'),
    ('furnished', 'Yes or No', 'String'),
    ('condition', 'New, Fairly Used, Old', 'String'),
    ('amenities', 'Semicolon separated', 'String'),
    ('category', 'For Rent, For Sale…', 'String'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Text('CSV Column Reference',
                style: Theme.of(context).textTheme.titleSmall)),
        const Divider(height: 1),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 40,
            columnSpacing: 20,
            columns: const [
              DataColumn(
                  label: Text('Column',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 11))),
              DataColumn(
                  label: Text('Description',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 11))),
              DataColumn(
                  label: Text('Type',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 11))),
            ],
            rows: _cols.map((c) {
              final (col, desc, type) = c;
              final required = col.endsWith('*');
              return DataRow(cells: [
                DataCell(Text(col,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: required ? AppColors.primary : AppColors.text))),
                DataCell(Text(desc, style: const TextStyle(fontSize: 11))),
                DataCell(Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(type,
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.text2,
                            fontFamily: 'monospace')))),
              ]);
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

class _PreviewTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _PreviewTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 44,
          columnSpacing: 16,
          columns: const [
            DataColumn(
                label: Text('Title',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
            DataColumn(
                label: Text('Area',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
            DataColumn(
                label: Text('Price',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
            DataColumn(
                label: Text('Beds',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
            DataColumn(
                label: Text('Type',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
          ],
          rows: rows
              .map((row) => DataRow(cells: [
                    DataCell(SizedBox(
                        width: 160,
                        child: Text(row['title']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11)))),
                    DataCell(Text(row['area']?.toString() ?? '',
                        style: const TextStyle(fontSize: 11))),
                    DataCell(Text('₦${_fmt(row['price'])}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700))),
                    DataCell(Text(row['bedrooms']?.toString() ?? '',
                        style: const TextStyle(fontSize: 11))),
                    DataCell(Text(row['property_type']?.toString() ?? '',
                        style: const TextStyle(fontSize: 11))),
                  ]))
              .toList(),
        ),
      ),
    );
  }

  String _fmt(dynamic price) {
    final p = (price as num?)?.toDouble() ?? 0;
    if (p >= 1000000) return '${(p / 1000000).toStringAsFixed(1)}M';
    if (p >= 1000) return '${(p / 1000).toStringAsFixed(0)}k';
    return '${p.toStringAsFixed(0)}';
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'city.dart';

/// Same rule as functions/lib/areas.js: lowercase, letters and digits only.
String _slug(String s) {
  final t = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return t.replaceAll(RegExp(r'^-+|-+$'), '');
}

String areaKeyOf(String city, String area) => '${_slug(canonicalCity(city))}__${_slug(area)}';

class AreaOption {
  final String value;
  final String label;
  const AreaOption(this.value, this.label);
}

class AreaTopic {
  final String key;
  final String title;
  final String question;
  final IconData icon;
  final List<AreaOption> options;
  const AreaTopic(this.key, this.title, this.question, this.icon, this.options);
}

/// Fixed options only: reports are comparable and cannot carry accusations.
const List<AreaTopic> kAreaTopics = [
  AreaTopic('power', 'Power', 'How many hours of light a day?', Icons.bolt_outlined, [
    AreaOption('under6', 'Under 6 hrs'),
    AreaOption('6to12', '6 to 12 hrs'),
    AreaOption('12to18', '12 to 18 hrs'),
    AreaOption('18plus', '18+ hrs'),
  ]),
  AreaTopic('water', 'Water', 'Where does water usually come from?', Icons.water_drop_outlined, [
    AreaOption('borehole', 'Boreholes'),
    AreaOption('public', 'Public supply'),
    AreaOption('tanker', 'Tankers'),
  ]),
  AreaTopic('flooding', 'Flooding', 'Have you seen flooding here?', Icons.waves_outlined, [
    AreaOption('never', 'Never seen'),
    AreaOption('once', 'Once'),
    AreaOption('often', 'Often'),
  ]),
  AreaTopic('security', 'Security', 'How secure does it feel?', Icons.shield_outlined, [
    AreaOption('secure', 'Gated or guarded'),
    AreaOption('average', 'Some security'),
    AreaOption('weak', 'Little security'),
  ]),
  AreaTopic('internet', 'Internet', 'What internet is available?', Icons.wifi_rounded, [
    AreaOption('fibre', 'Fibre'),
    AreaOption('mobile', 'Mobile data only'),
    AreaOption('poor', 'Poor connection'),
  ]),
  AreaTopic('roads', 'Roads', 'What are the roads like?', Icons.add_road_rounded, [
    AreaOption('good', 'Good'),
    AreaOption('fair', 'Fair'),
    AreaOption('poor', 'Poor'),
  ]),
];

/// Sentences for the headline of each answer.
const Map<String, String> kAreaHeadline = {
  'under6': 'Under 6 hrs a day',
  '6to12': '6 to 12 hrs a day',
  '12to18': '12 to 18 hrs a day',
  '18plus': '18+ hrs a day',
  'borehole': 'Boreholes are common',
  'public': 'Public supply',
  'tanker': 'Tankers are common',
  'never': 'No flooding seen',
  'once': 'Flooded once',
  'often': 'Floods often',
  'secure': 'Gated or guarded',
  'average': 'Some security',
  'weak': 'Little security',
  'fibre': 'Fibre on some streets',
  'mobile': 'Mobile data only',
  'poor': 'Poor',
  'good': 'Good',
  'fair': 'Fair',
};

class AreaTopicSummary {
  final int count;
  final Map<String, int> dist;
  final DateTime? latestAt;
  const AreaTopicSummary(this.count, this.dist, this.latestAt);

  /// The most common answer, or null when answers are split evenly.
  String? get leading {
    if (dist.isEmpty) return null;
    final sorted = dist.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.length > 1 && sorted[0].value == sorted[1].value) return null;
    return sorted.first.key;
  }

  /// Few reports: shown, but flagged as early.
  bool get early => count < 3;
}

class AreaSummary {
  final String key;
  final Map<String, AreaTopicSummary> topics;
  const AreaSummary(this.key, this.topics);

  static AreaSummary? fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>?;
    if (m == null) return null;
    final out = <String, AreaTopicSummary>{};
    final raw = (m['topics'] as Map?)?.cast<String, dynamic>() ?? const {};
    for (final e in raw.entries) {
      final t = (e.value as Map).cast<String, dynamic>();
      final dist = <String, int>{
        for (final x in ((t['dist'] as Map?) ?? const {}).entries) x.key as String: (x.value as num).toInt(),
      };
      final ts = t['latestAt'];
      out[e.key] = AreaTopicSummary((t['count'] as num?)?.toInt() ?? 0, dist, ts is Timestamp ? ts.toDate() : null);
    }
    return AreaSummary(d.id, out);
  }
}

String monthYear(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${m[d.month - 1]} ${d.year}';
}

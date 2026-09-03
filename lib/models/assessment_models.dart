import 'dart:convert';

import 'triage_result.dart';

class ModelAssessment {
  const ModelAssessment({
    required this.rawOutput,
    this.suggestedUrgency,
    this.summary = '',
    this.urgencyReasons = const [],
    this.possibleCauses = const [],
    this.recommendedCare = const [],
    this.seekHelpNowIf = const [],
    this.isStructured = false,
  });

  factory ModelAssessment.fromRawOutput(String rawOutput) {
    print('🔍 [PARSE] Starting to parse raw output...');
    print('📏 Raw output length: ${rawOutput.length}');
    print(
      '📝 First 200 chars: ${rawOutput.substring(0, rawOutput.length > 200 ? 200 : rawOutput.length)}',
    );

    try {
      final jsonObject = _extractJsonObject(rawOutput);
      if (jsonObject == null) {
        print('⚠️ [PARSE] No JSON object found in output, returning raw');
        return ModelAssessment(rawOutput: rawOutput);
      }

      print('✅ [PARSE] JSON extracted, length: ${jsonObject.length}');
      print('📝 JSON: $jsonObject');

      final decoded = jsonDecode(jsonObject);
      if (decoded is! Map<String, dynamic>) {
        print('⚠️ [PARSE] Decoded JSON is not a Map, returning raw');
        return ModelAssessment(rawOutput: rawOutput);
      }

      print('✅ [PARSE] JSON decoded successfully');
      print('🔑 Keys: ${decoded.keys.toList()}');

      final nested = decoded['assessment'];
      final values = nested is Map
          ? Map<String, dynamic>.from(nested)
          : decoded;

      print(
        '📦 [PARSE] Using values from: ${nested is Map ? "nested 'assessment'" : "root"}',
      );

      return ModelAssessment(
        rawOutput: rawOutput,
        suggestedUrgency: _parseUrgency(
          _first(values, const ['urgency', 'risk', 'risk_level', 'care_level']),
        ),
        summary: summaryVal,
        urgencyReasons: _stringList(
          _first(values, const [
            'urgency_reasons',
            'urgencyReasons',
            'reasons',
            'why_this_care_level',
          ]),
        ),
        possibleCauses: _possibleCauseList(
          _first(values, const [
            'possible_causes',
            'possibleCauses',
            'possibilities',
          ]),
        ),
        recommendedCare: _stringList(
          _first(values, const [
            'recommended_care',
            'recommendedCare',
            'care_advice',
            'next_steps',
          ]),
        ),
        seekHelpNowIf: _stringList(
          _first(values, const [
            'seek_help_now_if',
            'seekHelpNowIf',
            'red_flags',
            'warning_signs',
          ]),
        ),
        isStructured: true,
      );
    } catch (_) {
      return ModelAssessment(rawOutput: rawOutput);
    }
  }

  final String rawOutput;
  final TriageUrgency? suggestedUrgency;
  final String summary;
  final List<String> urgencyReasons;
  final List<String> possibleCauses;
  final List<String> recommendedCare;
  final List<String> seekHelpNowIf;
  final bool isStructured;

  /// A complete response can support every section on the result screen.
  bool get isComplete =>
      isStructured &&
      suggestedUrgency != null &&
      summary.length >= 40 &&
      _hasAdequateUrgencyReasons &&
      possibleCauses.length >= 2 &&
      recommendedCare.length >= 2 &&
      seekHelpNowIf.length >= 2;

  /// Whether the response contains enough case-specific evidence to display
  /// its care level. Optional sections may still be absent on small models.
  bool get canSupportCareLevel =>
      isStructured &&
      suggestedUrgency != null &&
      summary.length >= 15 &&
      _hasAdequateUrgencyReasons;

  /// Used to retain the richer result when a repair attempt only partially
  /// improves a response.
  int get informationScore =>
      (suggestedUrgency == null ? 0 : 3) +
      (summary.isEmpty ? 0 : 2) +
      urgencyReasons.length * 2 +
      possibleCauses.length +
      recommendedCare.length +
      seekHelpNowIf.length;

  bool get _hasAdequateUrgencyReasons {
    if (urgencyReasons.isEmpty ||
        urgencyReasons.any((reason) => reason.length < 30)) {
      return false;
    }
    if (suggestedUrgency != TriageUrgency.high &&
        suggestedUrgency != TriageUrgency.emergency) {
      return true;
    }

    // An urgent reason must connect a finding to its consequence, rather than
    // being a short label such as "symptoms getting worse".
    return urgencyReasons.every((reason) {
      final normalized = reason.toLowerCase();
      return reason.length >= 45 &&
          (reason.contains('—') ||
              reason.contains(' - ') ||
              normalized.contains(' because ') ||
              normalized.contains(' may ') ||
              normalized.contains(' can '));
    });
  }

  static TriageUrgency? _parseUrgency(Object? value) =>
      switch (value?.toString().trim().toLowerCase()) {
        'low' || 'green' => TriageUrgency.low,
        'medium' || 'moderate' || 'yellow' => TriageUrgency.medium,
        'high' || 'urgent' || 'urgent care' || 'red' => TriageUrgency.high,
        'emergency' || 'possible emergency' => TriageUrgency.emergency,
        _ => null,
      };

  static String _stringValue(Object? value) =>
      value is String ? value.trim() : '';

  static List<String> _stringList(Object? value) {
    if (value is String) {
      final item = value.trim();
      return item.isEmpty ? const [] : [item];
    }
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static List<String> _possibleCauseList(Object? value) {
    if (value is String) {
      final item = value.trim();
      return item.isEmpty ? const [] : [item];
    }
    if (value is! List) return const [];
    return value
        .map((item) {
          if (item is String) return item.trim();
          if (item is Map) {
            final name = _stringValue(item['name']);
            final reason = _stringValue(item['reason']);
            if (name.isEmpty) return reason;
            if (reason.isEmpty) return name;
            return '$name — $reason';
          }
          return '';
        })
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static Object? _first(Map<String, dynamic> values, List<String> keys) {
    for (final key in keys) {
      if (values.containsKey(key)) return values[key];
    }
    return null;
  }

  /// Extracts the first balanced JSON object instead of taking everything
  /// between the first and last brace. Models often append a short note after
  /// JSON, and that note can itself contain braces.
  static String? _extractJsonObject(String value) {
    var depth = 0;
    var start = -1;
    var inString = false;
    var escaped = false;

    for (var i = 0; i < value.length; i++) {
      final char = value[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == '\\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }
      if (char == '"') {
        inString = true;
      } else if (char == '{') {
        if (depth == 0) start = i;
        depth++;
      } else if (char == '}' && depth > 0) {
        depth--;
        if (depth == 0 && start >= 0) {
          return value.substring(start, i + 1);
        }
      }
    }
    return null;
  }
}

class Facility {
  const Facility({
    required this.id,
    required this.name,
    required this.distanceKm,
    required this.etaMinutes,
    required this.capabilities,
    required this.acceptingPatients,
    required this.latitude,
    required this.longitude,
    this.icuAvailable = 0,
    this.icuTotal = 0,
    this.bedsAvailable = 0,
    this.bedsTotal = 0,
    this.isRecommended = false,
    this.reason = '',
  });
  final String id;
  final String name;
  final double distanceKm;
  final int etaMinutes;
  final Set<String> capabilities;
  final bool acceptingPatients;
  final double latitude;
  final double longitude;
  final int icuAvailable;
  final int icuTotal;
  final int bedsAvailable;
  final int bedsTotal;
  final bool isRecommended;
  final String reason;
}

class AssessmentHistoryEntry {
  const AssessmentHistoryEntry({
    required this.timestamp,
    required this.symptoms,
    required this.severity,
  });
  final DateTime timestamp;
  final String symptoms;
  final TriageUrgency severity;
}

class AssessmentSession {
  String? imagePath;
  String originalText = '';
  String? transcript;
  final Map<String, String> answers = {};
  final List<String> modelOutputs = [];
  ModelAssessment? modelResult;
  TriageResult? triageResult;
  Facility? recommendedFacility;

  void reset() {
    imagePath = null;
    originalText = '';
    transcript = null;
    answers.clear();
    modelOutputs.clear();
    modelResult = null;
    triageResult = null;
    recommendedFacility = null;
  }
}

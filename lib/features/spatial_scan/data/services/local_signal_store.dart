import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/echo_node_model.dart';

/// Persists just the *planted* nodes (not the 6 ambient demo seeds, which
/// regenerate fresh every launch) to on-device key-value storage, so a
/// restart doesn't wipe out echoes the user actually planted. Demo-scoped
/// on purpose: a single JSON blob under one key is the fastest path to
/// "survives a restart," reusing EchoNodeModel's existing (de)serialization
/// rather than standing up a real database for a single list.
class LocalSignalStore {
  static const _key = 'planted_echo_nodes';

  Future<List<EchoNodeModel>> loadPlantedNodes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => EchoNodeModel.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<void> savePlantedNodes(List<EchoNodeModel> nodes) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(nodes.map((node) => node.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}

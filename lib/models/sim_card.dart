/// Network technology classification for a SIM card.
enum NetworkType { none, edge, twoG, threeG, fourG, fiveG }

extension NetworkTypeName on NetworkType {
  String get label {
    switch (this) {
      case NetworkType.none:
        return 'None';
      case NetworkType.edge:
        return 'EDGE';
      case NetworkType.twoG:
        return '2G';
      case NetworkType.threeG:
        return '3G';
      case NetworkType.fourG:
        return '4G';
      case NetworkType.fiveG:
        return '5G';
    }
  }

  static NetworkType parse(String? value) {
    if (value == null) return NetworkType.none;
    switch (value.toUpperCase()) {
      case '2G':
        return NetworkType.twoG;
      case '3G':
        return NetworkType.threeG;
      case '4G':
      case 'LTE':
        return NetworkType.fourG;
      case '5G':
      case 'NR':
        return NetworkType.fiveG;
      case 'EDGE':
      case 'GPRS':
        return NetworkType.edge;
      default:
        return NetworkType.none;
    }
  }
}

/// Logical state of a SIM card as reported by Android.
enum SimState { unknown, absent, ready, notReady, locked, active }

extension SimStateName on SimState {
  String get label {
    switch (this) {
      case SimState.unknown:
        return 'Unknown';
      case SimState.absent:
        return 'Absent';
      case SimState.ready:
        return 'Ready';
      case SimState.notReady:
        return 'Not Ready';
      case SimState.locked:
        return 'Locked';
      case SimState.active:
        return 'Active';
    }
  }
}

/// A SIM card detected by the platform channel.
///
/// Mirrors the `sim_cards` SQLite table from the project document.
class SimCard {
  SimCard({
    required this.simId,
    required this.slotNumber,
    required this.name,
    this.phoneNumber,
    this.carrier,
    this.signalStrength = 0,
    this.networkType = NetworkType.none,
    this.isActive = true,
    this.isRoaming = false,
    this.state = SimState.ready,
    this.lastUpdated,
  });

  final String simId;
  final int slotNumber;
  final String name;
  final String? phoneNumber;
  final String? carrier;
  final int signalStrength; // 0-4 bars.
  final NetworkType networkType;
  bool isActive;
  final bool isRoaming;
  final SimState state;
  final DateTime? lastUpdated;

  /// Builds a [SimCard] from a database row.
  factory SimCard.fromMap(Map<String, dynamic> map) {
    return SimCard(
      simId: map['sim_id'] as String,
      slotNumber: (map['slot_number'] as num).toInt(),
      name: (map['name'] as String?) ?? 'SIM ${map['slot_number']}',
      phoneNumber: map['phone_number'] as String?,
      carrier: map['carrier'] as String?,
      signalStrength: (map['last_signal_strength'] as num?)?.toInt() ?? 0,
      networkType: NetworkTypeName.parse(map['network_type'] as String?),
      isActive: (map['is_active'] as num?)?.toInt() == 1,
      isRoaming: (map['is_roaming'] as num?)?.toInt() == 1,
      state: _parseState(map['sim_state'] as String?),
      lastUpdated: map['last_updated'] == null
          ? null
          : DateTime.parse(map['last_updated'] as String).toUtc(),
    );
  }

  static SimState _parseState(String? value) {
    if (value == null) return SimState.unknown;
    return SimState.values.firstWhere(
      (s) => s.name == value.toLowerCase(),
      orElse: () => SimState.unknown,
    );
  }

  /// Serializes for persistence.
  Map<String, dynamic> toMap() => {
    'sim_id': simId,
    'slot_number': slotNumber,
    'name': name,
    'phone_number': phoneNumber,
    'carrier': carrier,
    'last_signal_strength': signalStrength,
    'network_type': networkType.label,
    'is_active': isActive ? 1 : 0,
    'is_roaming': isRoaming ? 1 : 0,
    'sim_state': state.name,
    'last_updated': (lastUpdated ?? DateTime.now().toUtc()).toIso8601String(),
  };

  /// API-style JSON representation.
  Map<String, dynamic> toApiJson() => {
    'simId': simId,
    'slotNumber': slotNumber,
    'name': name,
    'phoneNumber': phoneNumber,
    'carrier': carrier,
    'signalStrength': signalStrength,
    'networkType': networkType.label,
    'isActive': isActive,
    'isRoaming': isRoaming,
    'state': state.name,
  };

  /// Returns `true` when the SIM can be used for sending.
  bool get canSend => isActive && state == SimState.ready;
}

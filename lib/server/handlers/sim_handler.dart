import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../services/sim_service.dart';
import '../api_response.dart';

/// SIM endpoints: list active, activate/deactivate.
class SimHandler {
  SimHandler(this._sim);

  final SimService _sim;

  Router get router {
    final r = Router();
    r.get('/active', _active);
    r.post('/activate', _activate);
    return r;
  }

  /// `GET /api/sims/active`
  Future<Response> _active(Request request) async {
    final sims = await _sim.getAll();
    final active = sims.where((s) => s.isActive).toList();
    return ApiResponse.ok({
      'simCards': sims.map((s) => s.toApiJson()).toList(),
      'activeSIMCount': active.length,
      'totalSIMCount': sims.length,
    });
  }

  /// `POST /api/sims/activate`
  Future<Response> _activate(Request request) async {
    final body = await parseJsonBody(request);
    if (body == null) {
      return ApiResponse.error('Invalid JSON body', status: 400);
    }
    final simId = body['simId'] as String?;
    final activate = body['activate'] as bool? ?? true;
    if (simId == null || simId.isEmpty) {
      return ApiResponse.error('simId is required', status: 400);
    }
    try {
      await _sim.toggle(simId, activate);
      return ApiResponse.ok({
        'simId': simId,
        'isActive': activate,
        'message': activate ? 'SIM card activated' : 'SIM card deactivated',
      });
    } on StateError catch (e) {
      return ApiResponse.error(e.message, status: 409);
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kristal_laboratorial/services/corporate_sync_service.dart';

void main() {
  group('CorporateInitialSyncDecision', () {
    test('requires server-first load when state is absent', () {
      final decision = CorporateInitialSyncDecision.fromStoredValue(null);
      expect(decision.initialPullRequired, isTrue);
    });

    test('requires server-first load when state is incomplete', () {
      final decision = CorporateInitialSyncDecision.fromStoredValue('0');
      expect(decision.initialPullRequired, isTrue);
    });

    test('allows bidirectional sync only after persisted completion', () {
      final decision = CorporateInitialSyncDecision.fromStoredValue('1');
      expect(decision.initialPullRequired, isFalse);
    });

    test('rejects malformed completion values', () {
      final decision = CorporateInitialSyncDecision.fromStoredValue('true');
      expect(decision.initialPullRequired, isTrue);
    });
  });

  group('CorporateInitialSyncOutboxPolicy', () {
    test('suppresses records queued before the initial pull', () {
      expect(
        CorporateInitialSyncOutboxPolicy.suppressAsPreexisting(
          queueId: 10,
          initialWatermark: 15,
        ),
        isTrue,
      );
    });

    test('suppresses the record at the initial watermark', () {
      expect(
        CorporateInitialSyncOutboxPolicy.suppressAsPreexisting(
          queueId: 15,
          initialWatermark: 15,
        ),
        isTrue,
      );
    });

    test('preserves changes queued while the initial pull is running', () {
      expect(
        CorporateInitialSyncOutboxPolicy.suppressAsPreexisting(
          queueId: 16,
          initialWatermark: 15,
        ),
        isFalse,
      );
    });
  });
}

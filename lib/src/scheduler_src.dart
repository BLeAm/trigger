part of '../trigger.dart';

/// ตัวจัดการคิวการอัปเดต (Batching Engine)
class UpdateScheduler {
  final Set<Updateable> _updateQueue = LinkedHashSet.identity();
  bool _isBatchingScheduled = false;

  // Hook สำหรับทำ Logger หรือ Debug
  void Function(Set<Updateable> updatedStates)? onBatchUpdate;

  void enqueue(Iterable<Updateable>? listeners) {
    if (listeners == null || listeners.isEmpty) return;

    _updateQueue.addAll(listeners);

    if (!_isBatchingScheduled) {
      _isBatchingScheduled = true;
      // รวบตึงไปประมวลผลท้าย Microtask
      Future.microtask(_processQueue);
    }
  }

  void _processQueue() {
    if (onBatchUpdate != null) {
      onBatchUpdate!(Set.from(_updateQueue));
    }

    for (final state in _updateQueue) {
      try {
        state.update();
      } catch (e, stack) {
        Zone.current.handleUncaughtError(e, stack);
      }
    }

    _updateQueue.clear();
    _isBatchingScheduled = false;
  }

  /// ใช้สำหรับล้างคิวค้างในกรณีพิเศษ เช่น การรัน Test ใหม่
  void reset() {
    _updateQueue.clear();
    _isBatchingScheduled = false;
  }

  void cancel(Updateable state) {
    _updateQueue.remove(state);
  }
}

// สร้าง Default Instance ไว้ใช้ร่วมกันทั้งแอป (ลด Global Coupling แบบ Static)
final defaultUpdateScheduler = UpdateScheduler();

part of '../trigger.dart';

// ประกาศลายเซ็นของฟังก์ชันที่จะใช้ส่อง
typedef BatchUpdateHook = void Function(Set<Updateable> updatedStates);

/// ตัวจัดการคิวการอัปเดต (Batching Engine)
class UpdateScheduler {
  final Set<Updateable> _updateQueue = LinkedHashSet.identity();
  bool _isBatchingScheduled = false;

  // Hook สำหรับทำ Logger หรือ Debug
  final List<BatchUpdateHook> _hooks = [];

  void addBatchHook(BatchUpdateHook hook) => _hooks.add(hook);

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
    if (_updateQueue.isEmpty) return;

    // 1. Snapshot: ย้ายงานทั้งหมดออกมาใส่รายการใหม่
    final processingList = _updateQueue.toList();

    // 2. ล้างคิวหลักทันที เพื่อรองรับ mutation ใหม่ๆ ที่จะเกิดขึ้นระหว่าง update()
    _updateQueue.clear();
    _isBatchingScheduled = false;
    // 1.3 วนลูปแจ้งเตือนทุกลูกตัวที่มา Register ไว้
    final updatedSet = Set<Updateable>.unmodifiable(processingList);
    for (final hook in _hooks) {
      hook(updatedSet);
    }
    // 3. วนลูปจากรายการที่เรา Snapshot ไว้
    for (final state in processingList) {
      try {
        state.update();
      } catch (e, stack) {
        Zone.current.handleUncaughtError(e, stack);
      }
    }
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

import 'dart:async';

/// A utility to handle async tasks with Last-In-Wins policy.
/// คลาสช่วยจัดการงานแบบ Latest-Only
/// เหมาะกับกรณีที่ต้องการรันงานซ้ำๆ แต่สนใจแค่ผลลัพธ์ล่าสุดเท่านั้น
/// เช่น การดึงข้อมูลจาก API ที่ต้องการแค่ผลลัพธ์ล่าสุด
/// โดยงานเก่าจะถูกยกเลิกทันทีที่มีงานใหม่เข้ามาแทนที่
/// ตัวอย่างการใช้งาน:
/// ```dart
/// final latest = Latest<String>();
/// latest<int>(
///   key: 'fetchData',
///   task: () async {
///     // ดึงข้อมูลจาก API
///     return await fetchDataFromApi();
///   },
///   onSuccess: (data) {
///     // อัพเดต UI ด้วยข้อมูลที่ได้
///   },
///   onError: (error) {
///     // จัดการข้อผิดพลาด
///   },
/// );
/// ```
class Latest<K> {
  final Map<K, Completer<dynamic>> _registry = {};

  /// [key] คือ Identity ของงาน (String หรือ Enum, ฯลฯ แล้วแต่กรณีใช้งาน/userเลือก)
  /// [task] คือ Future งานที่ต้องการรัน
  /// [onSuccess] จะทำงานเมื่อเป็นงานล่าสุด ณ ตอนที่ operator เสร็จเท่านั้น
  /// [onError] (Optional) สำหรับจัดการ Error ของงานล่าสุด
  void call<T>({
    required K key,
    required Future<T> Function() task,
    required void Function(T data) onSuccess,
    void Function(Object error)? onError,
  }) {
    // 1. ทิ้งสายใยเดิมทันที (Cancel existing logic)
    final old = _registry.remove(key);
    if (old != null && !old.isCompleted) {
      old.completeError('_superseded_');
    }

    final completer = Completer<T>();
    _registry[key] = completer;

    // 2. Execute งานจริง
    task()
        .then((value) {
          if (!completer.isCompleted) completer.complete(value);
        })
        .catchError((e, stack) {
          if (!completer.isCompleted) completer.completeError(e, stack);
        });

    // 3. รอรับผลผ่านกำแพง Completer
    completer.future
        .then((value) {
          // ตรวจสอบอีกครั้งว่าเรายังเป็น "คนล่าสุด" ใน Registry หรือไม่
          // (เพื่อความปลอดภัยสูงสุดในจังหวะ Microtask)
          if (_registry[key] == completer) {
            onSuccess(value);
            _registry.remove(key);
          }
        })
        .catchError((e) {
          if (e != '_superseded_') {
            onError?.call(e);
            if (_registry[key] == completer) _registry.remove(key);
          }
        });
  }

  /// แถม: สั่งล้างงานทั้งหมด (ใช้ตอน dispose)
  void cancelAll() {
    for (var c in _registry.values) {
      if (!c.isCompleted) c.completeError('_disposed_');
    }
    _registry.clear();
  }
}

// enum _MyTask { waitAndPrint, run }

// void _main() async {
//   final latest = Latest<_MyTask>();
//   latest<int>(
//     key: _MyTask.waitAndPrint,
//     task: () async {
//       await Future.delayed(Duration(seconds: 5));
//       return 5;
//     },
//     onSuccess: (value) {
//       print('Fetched value: $value');
//     },
//   );
//   latest<int>(
//     key: _MyTask.waitAndPrint,
//     task: () async {
//       await Future.delayed(Duration(seconds: 2));
//       return 2;
//     },
//     onSuccess: (value) {
//       print('Fetched value: $value');
//     },
//   );
// }

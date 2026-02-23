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

  void call<T>({
    required K key,
    required Future<T> Function() task,
    required void Function(T data) onSuccess,
    void Function(Object error)? onError,
  }) {
    // ลบ async ออกจากหัวฟังก์ชันนี้ เพื่อคุมลำดับเอง

    // 1. จัดการงานเก่า
    final old = _registry[key];
    if (old != null && !old.isCompleted) {
      old.completeError('_superseded_');
    }

    final completer = Completer<T>();
    _registry[key] = completer;

    // 2. ผูก Error Listener ไว้กับ Future ทันที (ป้องกัน Error หลุดไป Global)
    completer.future
        .then((result) {
          if (_registry[key] == completer) {
            _registry.remove(key);
            onSuccess(result);
          }
        })
        .catchError((e) {
          if (e.toString() == '_superseded_' || e.toString() == '_disposed_') {
            return; // จบเงียบๆ ตามแผน
          }

          if (_registry[key] == completer) {
            _registry.remove(key);
            if (onError != null) {
              onError(e);
            } else {
              // แทนที่จะ rethrow เราใช้การพิมพ์บอก Developer
              print('Latest Task Error ($key): $e');
            }
          }
        });

    // 3. เริ่มรัน Task จริง
    // ใช้ปีกกาครอบเพื่อให้แน่ใจว่า task() จะไม่หลุดออกไปข้างนอก
    () async {
      try {
        final value = await task();
        if (!completer.isCompleted) completer.complete(value);
      } catch (e, stack) {
        if (!completer.isCompleted) completer.completeError(e, stack);
      }
    }();
  }

  void cancelAll() {
    for (var key in _registry.keys.toList()) {
      final c = _registry.remove(key);
      if (c != null && !c.isCompleted) {
        c.completeError('_disposed_');
      }
    }
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

class Course {
  const Course({
    this.courseCode,
    this.classCode,
    this.groupCode,
    this.availableSlots,
    this.rawText = '',
  });

  final String? courseCode;
  final String? classCode;
  final String? groupCode;
  final int? availableSlots;
  final String rawText;
}

class CourseTarget {
  const CourseTarget({
    required this.courseCode,
    this.classCode,
    this.groupCode,
    this.priority = 1,
  });

  final String courseCode;
  final String? classCode;
  final String? groupCode;
  final int priority;

  List<String> validate() {
    final errors = <String>[];
    if (courseCode.trim().isEmpty) {
      errors.add('Cần nhập mã môn học');
    }
    if (!_validToken(courseCode)) {
      errors.add('Mã môn học không hợp lệ: $courseCode');
    }
    if (classCode != null && !_validToken(classCode!)) {
      errors.add('Mã lớp không hợp lệ: $classCode');
    }
    if (groupCode != null && !_validToken(groupCode!)) {
      errors.add('Mã nhóm không hợp lệ: $groupCode');
    }
    if (priority < 1) {
      errors.add('Độ ưu tiên phải từ 1 trở lên');
    }
    return errors;
  }

  static final RegExp _token = RegExp(r'^[A-Za-z0-9_.-]{2,32}$');

  static bool _validToken(String value) => _token.hasMatch(value.trim());
}

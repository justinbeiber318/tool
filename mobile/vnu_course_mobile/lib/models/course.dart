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
      errors.add('Course code is required');
    }
    if (!_validToken(courseCode)) {
      errors.add('Malformed course code: $courseCode');
    }
    if (classCode != null && !_validToken(classCode!)) {
      errors.add('Malformed class code: $classCode');
    }
    if (groupCode != null && !_validToken(groupCode!)) {
      errors.add('Malformed group code: $groupCode');
    }
    if (priority < 1) {
      errors.add('Priority must be 1 or greater');
    }
    return errors;
  }

  static final RegExp _token = RegExp(r'^[A-Za-z0-9_.-]{2,32}$');

  static bool _validToken(String value) => _token.hasMatch(value.trim());
}

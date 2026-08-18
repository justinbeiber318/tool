import 'package:flutter_test/flutter_test.dart';
import 'package:vnu_course_mobile/automation/course_matching.dart';
import 'package:vnu_course_mobile/models/course.dart';

void main() {
  test('prefers exact class code', () {
    final result = findCourse(
      const <Course>[
        Course(courseCode: 'INT1001', classCode: 'CL1', groupCode: 'G1'),
        Course(courseCode: 'INT1001', classCode: 'CL2', groupCode: 'G2'),
      ],
      const CourseTarget(courseCode: 'INT1001', classCode: 'CL2'),
    );

    expect(result.status, CourseMatchStatus.matched);
    expect(result.course?.classCode, 'CL2');
  });

  test('returns ambiguous when course code has multiple matches', () {
    final result = findCourse(
      const <Course>[
        Course(courseCode: 'INT1001', classCode: 'CL1'),
        Course(courseCode: 'INT1001', classCode: 'CL2'),
      ],
      const CourseTarget(courseCode: 'INT1001'),
    );

    expect(result.status, CourseMatchStatus.ambiguous);
  });

  test('sorts priority ascending', () {
    final sorted = sortTargetsByPriority(
      const <CourseTarget>[
        CourseTarget(courseCode: 'B', priority: 2),
        CourseTarget(courseCode: 'A', priority: 1),
      ],
    );

    expect(sorted.map((target) => target.courseCode), <String>['A', 'B']);
  });
}

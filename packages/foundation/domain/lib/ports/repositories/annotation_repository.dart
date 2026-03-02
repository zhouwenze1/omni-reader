import '../../models/annotation.dart';

abstract class AnnotationRepository {
  Future<List<Annotation>> listAnnotations(String bookUid);

  Future<void> appendAnnotation(String bookUid, Annotation annotation);

  Future<void> replaceAnnotations(String bookUid, List<Annotation> annotations);
}

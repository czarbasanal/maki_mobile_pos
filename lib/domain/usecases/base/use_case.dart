import 'package:maki_mobile_pos/core/errors/exceptions.dart';

/// Result wrapper returned by every use-case.
///
/// Mirrors the shape used by `ProcessSaleResult` in
/// [lib/domain/usecases/pos/process_sale_usecase.dart] so feature use-cases
/// stay convertible without breakage.
class UseCaseResult<T> {
  final bool success;
  final T? data;
  final String? errorMessage;
  final String? errorCode;
  final List<String> warnings;

  const UseCaseResult._({
    required this.success,
    this.data,
    this.errorMessage,
    this.errorCode,
    this.warnings = const [],
  });

  const UseCaseResult.successData(T data, {List<String> warnings = const []})
      : this._(success: true, data: data, warnings: warnings);

  const UseCaseResult.successVoid({List<String> warnings = const []})
      : this._(success: true, warnings: warnings);

  const UseCaseResult.failure({
    required String message,
    String? code,
  }) : this._(success: false, errorMessage: message, errorCode: code);

  /// Builds a failure result from a thrown [AppException], preserving its code.
  factory UseCaseResult.fromException(AppException e) =>
      UseCaseResult._(success: false, errorMessage: e.message, errorCode: e.code);

  bool get isFailure => !success;
  bool get hasWarnings => warnings.isNotEmpty;
}

/// Base class for use-cases. Implement [execute] in concrete subclasses.
///
/// Use [P] = `void` (and pass `null`) for parameter-free use-cases.
abstract class UseCase<T, P> {
  Future<UseCaseResult<T>> execute(P params);
}

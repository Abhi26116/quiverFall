import 'package:meta/meta.dart';

/// A value that is either a success ([Ok]) or a failure ([Err]).
///
/// Layers in Quiverfall do not throw across their boundaries. Repositories,
/// stores, and services return a [Result] so that every caller is forced by the
/// type system to consider failure. Exceptions are reserved for genuine
/// programmer errors (assertion failures, illegal state), not for expected
/// outcomes like "the save file is corrupt" or "the network is down".
///
/// This matters most in the save system: a swallowed exception there costs a
/// player their account.
@immutable
sealed class Result<T, E> {
  const Result();

  /// Wraps a synchronous computation, converting a thrown object into [Err].
  ///
  /// Only use this at the boundary of code you do not control (platform
  /// channels, third-party packages). Inside Quiverfall, return a [Result]
  /// directly rather than throwing and catching.
  static Result<T, Object> guard<T>(T Function() body) {
    try {
      return Ok<T, Object>(body());
    } catch (error) {
      return Err<T, Object>(error);
    }
  }

  /// Asynchronous counterpart to [guard].
  static Future<Result<T, Object>> guardAsync<T>(
    Future<T> Function() body,
  ) async {
    try {
      return Ok<T, Object>(await body());
    } catch (error) {
      return Err<T, Object>(error);
    }
  }

  bool get isOk => this is Ok<T, E>;

  bool get isErr => this is Err<T, E>;

  /// The success value, or `null` if this is an [Err].
  T? get valueOrNull => switch (this) {
        Ok<T, E>(:final T value) => value,
        Err<T, E>() => null,
      };

  /// The error, or `null` if this is an [Ok].
  E? get errorOrNull => switch (this) {
        Ok<T, E>() => null,
        Err<T, E>(:final E error) => error,
      };

  /// The success value, or [fallback] if this is an [Err].
  T valueOr(T fallback) => switch (this) {
        Ok<T, E>(:final T value) => value,
        Err<T, E>() => fallback,
      };

  /// Collapses both branches into a single value.
  R fold<R>(R Function(T value) onOk, R Function(E error) onErr) =>
      switch (this) {
        Ok<T, E>(:final T value) => onOk(value),
        Err<T, E>(:final E error) => onErr(error),
      };

  /// Transforms the success value, leaving an [Err] untouched.
  Result<R, E> map<R>(R Function(T value) transform) => switch (this) {
        Ok<T, E>(:final T value) => Ok<R, E>(transform(value)),
        Err<T, E>(:final E error) => Err<R, E>(error),
      };

  /// Transforms the error, leaving an [Ok] untouched.
  Result<T, F> mapErr<F>(F Function(E error) transform) => switch (this) {
        Ok<T, E>(:final T value) => Ok<T, F>(value),
        Err<T, E>(:final E error) => Err<T, F>(transform(error)),
      };

  /// Chains another fallible operation onto a success.
  Result<R, E> andThen<R>(Result<R, E> Function(T value) next) =>
      switch (this) {
        Ok<T, E>(:final T value) => next(value),
        Err<T, E>(:final E error) => Err<R, E>(error),
      };
}

@immutable
final class Ok<T, E> extends Result<T, E> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Ok<T, E> && other.value == value);

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

@immutable
final class Err<T, E> extends Result<T, E> {
  const Err(this.error);

  final E error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Err<T, E> && other.error == error);

  @override
  int get hashCode => Object.hash(Err, error);

  @override
  String toString() => 'Err($error)';
}

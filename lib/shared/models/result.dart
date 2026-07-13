/// A simple Result type for representing success or failure outcomes.
sealed class Result<T, E> {
  const Result();
}

/// Represents a successful result containing a [value].
class Success<T, E> extends Result<T, E> {
  final T value;
  const Success(this.value);
}

/// Represents a failed result containing an [error].
class Failure<T, E> extends Result<T, E> {
  final E error;
  const Failure(this.error);
}

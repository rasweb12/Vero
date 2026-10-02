sealed class Result<T> {
  const Result();

  R fold<R>({
    required R Function(AppFailure failure) onFailure,
    required R Function(T value) onSuccess,
  }) {
    return switch (this) {
      Failure<T>(:final failure) => onFailure(failure),
      Success<T>(:final value) => onSuccess(value),
    };
  }

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.failure);

  final AppFailure failure;
}

class AppFailure {
  const AppFailure({required this.message, this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;
}

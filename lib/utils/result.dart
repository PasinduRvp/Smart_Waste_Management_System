abstract class Result<T> {
  const Result();

  R when<R>({
    required R Function(T data) success,
    required R Function(String message) failure,
    required R Function(String message) loading,
  });

  bool get isSuccess => this is Success;
  bool get isFailure => this is Failure;
  bool get isLoading => this is Loading;

  T? getOrNull() {
    if (this is Success<T>) {
      return (this as Success<T>).data;
    }
    return null;
  }

  String? getErrorMessage() {
    if (this is Failure<T>) {
      return (this as Failure<T>).message;
    }
    return null;
  }
}

class Success<T> extends Result<T> {
  final T data;

  const Success(this.data);

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(String message) failure,
    required R Function(String message) loading,
  }) =>
      success(data);
}

class Failure<T> extends Result<T> {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(String message) failure,
    required R Function(String message) loading,
  }) =>
      failure(message);
}

class Loading<T> extends Result<T> {
  final String message;

  const Loading(this.message);

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(String message) failure,
    required R Function(String message) loading,
  }) =>
      loading(message);
}
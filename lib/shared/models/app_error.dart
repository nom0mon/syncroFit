sealed class AppError {
  String get message;
}

class NotFoundError extends AppError {
  final String entityType;
  final String id;

  NotFoundError({required this.entityType, required this.id});

  @override
  String get message => '$entityType with id $id not found';
}

class ValidationError extends AppError {
  final Map<String, String> fieldErrors;

  ValidationError({required this.fieldErrors});

  @override
  String get message => 'Validation failed';
}

class AuthError extends AppError {
  final String reason;

  AuthError({required this.reason});

  @override
  String get message => reason;
}

class NetworkError extends AppError {
  @override
  String get message => 'Network error occurred';
}

class ServerError extends AppError {
  final int statusCode;
  final String serverMessage;

  ServerError({required this.statusCode, required this.serverMessage});

  @override
  String get message => serverMessage;
}

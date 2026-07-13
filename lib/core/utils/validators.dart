/// Form validation helpers for the SyncroFit application.
///
/// All validators return `null` for valid input and an error string for invalid input,
/// following the Flutter `TextFormField.validator` convention.
library;

/// Validates that the value is a non-empty email containing "@" followed by
/// a domain segment (at least one character, a dot, and at least one more character).
String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Email is required';
  }
  // Must contain "@" followed by at least "x.x"
  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
  if (!emailRegex.hasMatch(value.trim())) {
    return 'Please enter a valid email address';
  }
  return null;
}

/// Validates that the password is at least 8 characters long.
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Password is required';
  }
  if (value.length < 8) {
    return 'Password must be at least 8 characters';
  }
  return null;
}

/// Validates that the name is between 1 and 50 characters (non-empty).
String? validateName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Name is required';
  }
  if (value.trim().length > 50) {
    return 'Name must be 50 characters or fewer';
  }
  return null;
}

/// Validates that the age is a numeric value between 13 and 120 (inclusive).
String? validateAge(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Age is required';
  }
  final age = int.tryParse(value.trim());
  if (age == null) {
    return 'Please enter a valid number';
  }
  if (age < 13 || age > 120) {
    return 'Age must be between 13 and 120';
  }
  return null;
}

/// Validates that the height is a numeric value between 50 and 300 cm (inclusive).
String? validateHeight(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Height is required';
  }
  final height = double.tryParse(value.trim());
  if (height == null) {
    return 'Please enter a valid number';
  }
  if (height < 50 || height > 300) {
    return 'Height must be between 50 and 300 cm';
  }
  return null;
}

/// Validates that the weight is a numeric value between 20 and 500 kg (inclusive).
String? validateWeight(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Weight is required';
  }
  final weight = double.tryParse(value.trim());
  if (weight == null) {
    return 'Please enter a valid number';
  }
  if (weight < 20 || weight > 500) {
    return 'Weight must be between 20 and 500 kg';
  }
  return null;
}

/// Validates that the value is non-empty and not only whitespace.
String? validateRequired(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'This field is required';
  }
  return null;
}

/// Validates that the value does not exceed [max] characters.
String? validateMaxLength(String? value, int max) {
  if (value == null) {
    return null;
  }
  if (value.length > max) {
    return 'Must be $max characters or fewer';
  }
  return null;
}

/// Validates that [password] and [confirm] are character-for-character identical.
String? validatePasswordMatch(String? password, String? confirm) {
  if (confirm == null || confirm.isEmpty) {
    return 'Please confirm your password';
  }
  if (password != confirm) {
    return 'Passwords do not match';
  }
  return null;
}

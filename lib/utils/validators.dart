class PickupValidator {
  // Eliminate Code Smell: Magic strings
  static const int minAddressLength = 10;
  static const int maxAddressLength = 200;
  static const int minNotesLength = 5;
  static const int maxNotesLength = 500;
  static const int maxDaysAhead = 30;
  static const int minDaysAhead = 1;
  static const double minAmount = 0.0;

  static String? validateWasteType(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please select a waste type';
    }
    return null;
  }

  static String? validateDate(DateTime? date) {
    if (date == null) {
      return 'Please select a date';
    }

    final now = DateTime.now();
    final requestDate = DateTime(date.year, date.month, date.day);
    final todayDate = DateTime(now.year, now.month, now.day);

    if (requestDate.isBefore(todayDate)) {
      return 'Date cannot be in the past';
    }

    final maxDate = todayDate.add(const Duration(days: maxDaysAhead));
    if (requestDate.isAfter(maxDate)) {
      return 'Date must be within $maxDaysAhead days';
    }

    return null;
  }

  static String? validateTimeSlot(String? slot) {
    if (slot == null || slot.isEmpty) {
      return 'Please select a time slot';
    }

    final parts = slot.split('-');
    if (parts.length != 2) {
      return 'Invalid time slot format';
    }

    return null;
  }

  static String? validateAddress(String? address) {
    if (address == null || address.isEmpty) {
      return 'Address is required';
    }

    if (address.length < minAddressLength) {
      return 'Address must be at least $minAddressLength characters';
    }

    if (address.length > maxAddressLength) {
      return 'Address cannot exceed $maxAddressLength characters';
    }

    return null;
  }

  static String? validateNotes(String? notes) {
    if (notes == null || notes.isEmpty) {
      return null; // Optional field
    }

    if (notes.length < minNotesLength) {
      return 'Notes must be at least $minNotesLength characters';
    }

    if (notes.length > maxNotesLength) {
      return 'Notes cannot exceed $maxNotesLength characters';
    }

    return null;
  }

  static String? validateAmount(double? amount) {
    if (amount == null || amount <= minAmount) {
      return 'Amount must be greater than zero';
    }

    return null;
  }

  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (!_hasUpperCase(password)) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!_hasLowerCase(password)) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!_hasNumber(password)) {
      return 'Password must contain at least one number';
    }

    return null;
  }

  static bool _hasUpperCase(String text) {
    return text.contains(RegExp(r'[A-Z]'));
  }

  static bool _hasLowerCase(String text) {
    return text.contains(RegExp(r'[a-z]'));
  }

  static bool _hasNumber(String text) {
    return text.contains(RegExp(r'[0-9]'));
  }
}
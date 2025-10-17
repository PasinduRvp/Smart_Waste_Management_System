class AppConstants {
  // Waste Types
  static const List<String> wasteTypes = [
    'Electronic Waste',
    'Hazardous Materials',
    'Large Items',
    'Garden Waste',
    'Construction Debris',
  ];

  // Pickup Status
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';
  static const String statusCompleted = 'completed';

  // Time Slots
  static const List<String> defaultTimeSlots = [
    '09:00-12:00',
    '12:00-15:00',
    '15:00-18:00',
  ];

  // Pagination
  static const int pageSize = 20;
  static const int maxRetries = 3;

  // Timeouts
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration dbTimeout = Duration(seconds: 60);

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String pickupsCollection = 'pickups';
  static const String specialPickupsCollection = 'special_pickups';
  static const String timeSlotsCollection = 'time_slots';
  static const String serviceAreasCollection = 'service_areas';
  static const String paymentsCollection = 'payments';
  static const String routesCollection = 'routes';

  // Limit
  static const int nearestAreasLimit = 3;
  static const int maxFileSize = 5242880; // 5MB

  // Rates and Amounts
  static const double specialPickupBaseRate = 250.0;
  static const double rebatePercentage = 0.1; // 10%
}
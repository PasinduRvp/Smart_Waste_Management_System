import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_waste_management/controllers/auth_controller.dart';
import 'package:smart_waste_management/services/pickup_service.dart';
import 'package:smart_waste_management/services/payment_service.dart';
import 'package:smart_waste_management/utils/app_themes.dart';
import 'package:smart_waste_management/views/widgets/custom_textfield.dart';
import 'package:smart_waste_management/views/resident/resident_home_page.dart';

class ScheduleSpecialPickupScreen extends StatefulWidget {
  const ScheduleSpecialPickupScreen({super.key});

  @override
  State<ScheduleSpecialPickupScreen> createState() => _ScheduleSpecialPickupScreenState();
}

class _ScheduleSpecialPickupScreenState extends State<ScheduleSpecialPickupScreen> {
  final AuthController _authController = Get.find();
  final PickupService _pickupService = PickupService();
  final PaymentService _paymentService = PaymentService();
  final ImagePicker _imagePicker = ImagePicker();
  
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _nicController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _wasteAmountController = TextEditingController(); // NEW
  
  String? _selectedWasteType;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  Map<String, dynamic>? _selectedLocation;
  XFile? _paymentSlipImage;
  bool _isLoading = false;
  bool _isGettingLocation = false;
  bool _isUploadingImage = false;
  LatLng? _currentLatLng;

  final List<String> _wasteTypes = [
    'Paper',
    'Polythene & Plastic',
    'Food Waste',
    'E-Waste',
    'Other Special Waste'
  ];

  // Waste type descriptions
  final Map<String, String> _wasteTypeDescriptions = {
    'Paper': 'Newspapers, magazines, cardboard, office paper',
    'Polythene & Plastic': 'Plastic bottles, containers, bags, packaging',
    'Food Waste': 'Organic kitchen waste, food scraps',
    'E-Waste': 'Electronic devices, batteries, cables, appliances',
    'Other Special Waste': 'Other items requiring special handling'
  };

  // Waste type icons
  final Map<String, IconData> _wasteTypeIcons = {
    'Paper': Icons.description,
    'Polythene & Plastic': Icons.local_drink,
    'Food Waste': Icons.restaurant,
    'E-Waste': Icons.computer,
    'Other Special Waste': Icons.warning,
  };

  // Waste type base prices (per kg)
  final Map<String, double> _wasteTypeBasePrices = {
    'Paper': 50.00,
    'Polythene & Plastic': 75.00,
    'Food Waste': 30.00,
    'E-Waste': 150.00,
    'Other Special Waste': 100.00,
  };

  // Calculate total price based on waste amount
  double get _calculatedPrice {
    if (_selectedWasteType == null || _wasteAmountController.text.isEmpty) {
      return 0.0;
    }
    final basePrice = _wasteTypeBasePrices[_selectedWasteType] ?? 0.0;
    final amount = double.tryParse(_wasteAmountController.text) ?? 0.0;
    return basePrice * amount;
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<bool> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.deniedForever) {
      Get.snackbar(
        'Location Permission',
        'Location permission is permanently denied. Enable it in app settings.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        icon: const Icon(Icons.warning, color: Colors.white),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return false;
    }
    
    return permission == LocationPermission.whileInUse || 
           permission == LocationPermission.always;
  }

  Future<String> _getAddressFromLatLng(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        return '${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}';
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    return 'Location: $latitude, $longitude';
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      final hasPermission = await _requestLocationPermission();
      
      if (!hasPermission) {
        Get.snackbar(
          'Error',
          'Location permission is required',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          icon: const Icon(Icons.error_outline, color: Colors.white),
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        setState(() {
          _isGettingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final address = await _getAddressFromLatLng(position.latitude, position.longitude);

      setState(() {
        _currentLatLng = LatLng(position.latitude, position.longitude);
        _selectedLocation = {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'address': address,
        };
      });

      Get.snackbar(
        'Success',
        'Current location retrieved',
        backgroundColor: AppThemes.collectedColor,
        colorText: Colors.white,
        icon: const Icon(Icons.check_circle, color: Colors.white),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to get current location: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: const Icon(Icons.error_outline, color: Colors.white),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  Future<void> _selectLocationFromMap() async {
    final result = await Get.to<Map<String, dynamic>>(
      () => LocationPickerScreen(currentLocation: _currentLatLng),
    );
    
    if (result != null) {
      setState(() {
        _selectedLocation = result;
        _currentLatLng = LatLng(result['latitude'], result['longitude']);
      });
    }
  }

  Future<void> _pickPaymentSlip() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _paymentSlipImage = image;
        });
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to pick image: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: const Icon(Icons.error_outline, color: Colors.white),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> _submitSpecialPickup() async {
    // Validation
    if (_selectedWasteType == null ||
        _selectedDate == null ||
        _selectedTime == null ||
        _selectedLocation == null ||
        _descriptionController.text.isEmpty ||
        _fullNameController.text.isEmpty ||
        _nicController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _wasteAmountController.text.isEmpty || // NEW validation
        _paymentSlipImage == null) {
      Get.snackbar(
        'Error',
        'Please fill all required fields and upload payment slip',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: const Icon(Icons.error_outline, color: Colors.white),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Validate waste amount
    final wasteAmount = double.tryParse(_wasteAmountController.text);
    if (wasteAmount == null || wasteAmount <= 0) {
      Get.snackbar(
        'Error',
        'Please enter a valid waste amount',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: const Icon(Icons.error_outline, color: Colors.white),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload payment slip first
      setState(() {
        _isUploadingImage = true;
      });

      final slipImageUrl = await _paymentService.uploadPaymentSlip(_paymentSlipImage!);
      
      setState(() {
        _isUploadingImage = false;
      });

      // Submit payment
      await _paymentService.submitPayment(
        userId: _authController.user!.uid,
        userName: _authController.user!.displayName ?? 'Resident',
        userEmail: _authController.user!.email!,
        fullName: _fullNameController.text.trim(),
        nic: _nicController.text.trim(),
        address: _addressController.text.isNotEmpty 
            ? _addressController.text 
            : _selectedLocation!['address'],
        phone: _phoneController.text.trim(),
        amount: _calculatedPrice,
        paymentMethod: 'Bank Transfer',
        slipImageUrl: slipImageUrl,
      );

      // Schedule pickup
      final DateTime scheduledDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      await _pickupService.scheduleSpecialPickup(
        userId: _authController.user!.uid,
        userName: _authController.user!.displayName ?? 'Resident',
        userEmail: _authController.user!.email!,
        wasteType: _selectedWasteType!,
        description: _descriptionController.text,
        scheduledDate: scheduledDateTime,
        location: _selectedLocation!,
        address: _addressController.text.isNotEmpty 
            ? _addressController.text 
            : _selectedLocation!['address'],
        estimatedAmount: wasteAmount, // NEW: Include waste amount
      );

      // Show success toast notification
      Get.snackbar(
        'Success!',
        'Special pickup scheduled successfully! Payment is under review.',
        backgroundColor: AppThemes.collectedColor,
        colorText: Colors.white,
        icon: const Icon(Icons.check_circle, color: Colors.white),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 3),
        animationDuration: const Duration(milliseconds: 500),
      );

      // Wait a moment for the user to see the toast
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Navigate to ResidentHomePage and remove all previous routes
      Get.offAll(() => const ResidentHomePage());
      
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to schedule pickup: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: const Icon(Icons.error_outline, color: Colors.white),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 4),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isUploadingImage = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    // Pre-fill user data if available
    if (_authController.userData.isNotEmpty) {
      _fullNameController.text = _authController.userData['name'] ?? '';
      _phoneController.text = _authController.userData['phone'] ?? '';
    }
    // Recalculate price when waste amount changes
    _wasteAmountController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    _nicController.dispose();
    _phoneController.dispose();
    _fullNameController.dispose();
    _wasteAmountController.dispose(); // NEW
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Schedule Special Pickup',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple[400]!,
                    Colors.purple[600]!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.star_rounded, size: 40, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    'Special Waste Pickup',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Schedule pickup for special waste items with payment',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Personal Information Section
            Text(
              'Personal Information',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            CustomTextfield(
              label: 'Full Name *',
              prefixIcon: Icons.person_outline,
              controller: _fullNameController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your full name';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            CustomTextfield(
              label: 'NIC Number *',
              prefixIcon: Icons.badge_outlined,
              controller: _nicController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your NIC number';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            CustomTextfield(
              label: 'Phone Number *',
              prefixIcon: Icons.phone_outlined,
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Waste Type Selection
            Text(
              'Waste Type *',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            if (_selectedWasteType != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _wasteTypeIcons[_selectedWasteType],
                      color: Colors.purple,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedWasteType!,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _wasteTypeDescriptions[_selectedWasteType]!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Base Price: LKR ${_wasteTypeBasePrices[_selectedWasteType]!.toStringAsFixed(2)}/kg',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _wasteTypes.map((type) {
                return ChoiceChip(
                  label: Text(type),
                  selected: _selectedWasteType == type,
                  onSelected: (selected) {
                    setState(() {
                      _selectedWasteType = selected ? type : null;
                    });
                  },
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  selectedColor: Colors.purple.withOpacity(0.2),
                  labelStyle: GoogleFonts.poppins(
                    color: _selectedWasteType == type ? Colors.purple : null,
                    fontWeight: _selectedWasteType == type ? FontWeight.w600 : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // NEW: Waste Amount Field
            CustomTextfield(
              label: 'Estimated Waste Amount (kg) *',
              prefixIcon: Icons.scale_rounded,
              controller: _wasteAmountController,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter waste amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                if (amount > 1000) {
                  return 'Amount too large. Contact support for bulk pickup.';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Description
            CustomTextfield(
              label: 'Description *',
              prefixIcon: Icons.description_outlined,
              controller: _descriptionController,
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please describe the waste items';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Date and Time Selection
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pickup Date *',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                _selectedDate != null
                                    ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                    : 'Select Date',
                                style: GoogleFonts.poppins(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pickup Time *',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _selectTime,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                _selectedTime != null
                                    ? _selectedTime!.format(context)
                                    : 'Select Time',
                                style: GoogleFonts.poppins(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Location Selection
            Text(
              'Pickup Location *',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isGettingLocation ? null : _getCurrentLocation,
                    icon: _isGettingLocation 
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(_isGettingLocation ? 'Getting...' : 'Current Location'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectLocationFromMap,
                    icon: const Icon(Icons.map),
                    label: const Text('Select on Map'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (_selectedLocation != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppThemes.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: AppThemes.primaryGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location Selected',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppThemes.primaryGreen,
                            ),
                          ),
                          Text(
                            _selectedLocation!['address'] ?? 'Location selected',
                            style: GoogleFonts.poppins(fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Additional Address Details
            CustomTextfield(
              label: 'Additional Address Details (Optional)',
              prefixIcon: Icons.home_outlined,
              controller: _addressController,
              maxLines: 2,
            ),

            const SizedBox(height: 24),

            // Payment Section
            Text(
              'Payment',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            if (_selectedWasteType != null && _wasteAmountController.text.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Waste Amount',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '${_wasteAmountController.text} kg',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Base Price',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              'LKR ${_wasteTypeBasePrices[_selectedWasteType]!.toStringAsFixed(2)}/kg',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'LKR ${_calculatedPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Payment Slip Upload
            Text(
              'Upload Payment Slip *',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            GestureDetector(
              onTap: _pickPaymentSlip,
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _paymentSlipImage != null ? Colors.green : Colors.grey[300]!,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: isDark ? Colors.grey[800] : Colors.grey[50],
                ),
                child: _paymentSlipImage != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(_paymentSlipImage!.path),
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to upload payment slip',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 8),
            Text(
              'Please upload a clear image of your bank transfer receipt',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    Colors.purple[400]!,
                    Colors.purple[600]!,
                  ],
                ),
              ),
              child: ElevatedButton(
                onPressed: (_isLoading || _isUploadingImage) ? null : _submitSpecialPickup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading || _isUploadingImage
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.schedule_send, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Schedule & Pay',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// Location Picker Screen with Flutter Map
class LocationPickerScreen extends StatefulWidget {
  final LatLng? currentLocation;

  const LocationPickerScreen({
    super.key,
    this.currentLocation,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late MapController _mapController;
  LatLng? _selectedLatLng;
  String _selectedAddress = '';
  bool _isLoadingAddress = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLatLng = widget.currentLocation ?? 
        const LatLng(6.9271, 79.8612); // Default to Colombo, Sri Lanka
  }

  Future<void> _getAddressFromLatLng(LatLng latLng) async {
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        setState(() {
          _selectedAddress = '${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}';
        });
      }
    } catch (e) {
      setState(() {
        _selectedAddress = 'Lat: ${latLng.latitude.toStringAsFixed(4)}, Lng: ${latLng.longitude.toStringAsFixed(4)}';
      });
    } finally {
      setState(() {
        _isLoadingAddress = false;
      });
    }
  }

  void _handleMapTap(LatLng latLng) {
    setState(() {
      _selectedLatLng = latLng;
    });
    _getAddressFromLatLng(latLng);
  }

  void _confirmLocation() {
    if (_selectedLatLng != null) {
      Get.back(result: {
        'latitude': _selectedLatLng!.latitude,
        'longitude': _selectedLatLng!.longitude,
        'address': _selectedAddress,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Select Location',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: _selectedLatLng,
                zoom: 15.0,
                onTap: (TapPosition tapPosition, LatLng latLng) {
                  _handleMapTap(latLng);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                MarkerLayer(
                  markers: [
                    if (_selectedLatLng != null)
                      Marker(
                        point: _selectedLatLng!,
                        width: 60,
                        height: 60,
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.location_on,
                                color: Colors.red[600],
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoadingAddress)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      height: 20,
                      child: LinearProgressIndicator(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                if (_selectedLatLng != null && !_isLoadingAddress)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppThemes.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppThemes.primaryGreen.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Address',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppThemes.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _selectedAddress,
                          style: GoogleFonts.poppins(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Lat: ${_selectedLatLng!.latitude.toStringAsFixed(4)}, Lng: ${_selectedLatLng!.longitude.toStringAsFixed(4)}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _confirmLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemes.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Confirm Location',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
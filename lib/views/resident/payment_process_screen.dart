import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_waste_management/controllers/auth_controller.dart';
import 'package:smart_waste_management/services/payment_service.dart';
import 'package:smart_waste_management/utils/app_themes.dart';
import 'package:smart_waste_management/views/widgets/custom_textfield.dart';

class PaymentProcessScreen extends StatefulWidget {
  const PaymentProcessScreen({super.key});

  @override
  State<PaymentProcessScreen> createState() => _PaymentProcessScreenState();
}

class _PaymentProcessScreenState extends State<PaymentProcessScreen> {
  final AuthController _authController = Get.find();
  final PaymentService _paymentService = PaymentService();
  final ImagePicker _imagePicker = ImagePicker();
  
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _nicController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(text: '1500.00');
  
  String? _selectedPaymentMethod;
  String? _slipImageUrl;
  bool _isLoading = false;
  bool _isUploading = false;
  bool _paymentSubmitted = false;

  final List<String> _paymentMethods = [
    'Bank Transfer',
    'Credit Card',
    'Debit Card',
    'Digital Wallet'
  ];

  Future<void> _pickSlipImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _isUploading = true;
        });

        // Upload image to Cloudinary
        final String imageUrl = await _paymentService.uploadPaymentSlip(image);
        
        setState(() {
          _slipImageUrl = imageUrl;
          _isUploading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      Get.snackbar(
        'Error',
        'Failed to pick image: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _submitPayment() async {
    if (_fullNameController.text.isEmpty ||
        _nicController.text.isEmpty ||
        _addressController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _selectedPaymentMethod == null ||
        _slipImageUrl == null) {
      Get.snackbar(
        'Error',
        'Please fill all fields and upload payment slip',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _paymentService.submitPayment(
        userId: _authController.user!.uid,
        userName: _authController.user!.displayName ?? _fullNameController.text,
        userEmail: _authController.user!.email!,
        fullName: _fullNameController.text,
        nic: _nicController.text,
        address: _addressController.text,
        phone: _phoneController.text,
        amount: double.parse(_amountController.text),
        paymentMethod: _selectedPaymentMethod!,
        slipImageUrl: _slipImageUrl!,
      );

      setState(() {
        _paymentSubmitted = true;
      });

      Get.snackbar(
        'Success',
        'Payment submitted successfully! Waiting for admin approval.',
        backgroundColor: AppThemes.collectedColor,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to submit payment: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Pre-fill user data if available
    _fullNameController.text = _authController.user?.displayName ?? '';
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _nicController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Membership Payment',
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
            // Show real-time status if payment was submitted
            if (_paymentSubmitted) _buildPaymentStatusAfterSubmission(),

            // Payment Information Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppThemes.primaryGreen,
                    AppThemes.lightGreen,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.verified_user_rounded, size: 40, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    'Annual Membership Fee',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'LKR ${_amountController.text}',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'One-year waste collection service membership',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Required to schedule pickups',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Only show form if payment not submitted
            if (!_paymentSubmitted) ..._buildPaymentForm(isDark),

            const SizedBox(height: 20),

            // Important Information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Important Information',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Your membership will be activated after admin approval\n'
                    '• You can schedule pickups only after membership approval\n'
                    '• Approval usually takes 24-48 hours\n'
                    '• You will receive a notification once approved',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPaymentForm(bool isDark) {
    return [
      // Personal Information Form
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
        prefixIcon: Icons.person_outline_rounded,
        controller: _fullNameController,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your full name';
          }
          return null;
        },
      ),

      const SizedBox(height: 16),

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

      const SizedBox(height: 16),

      CustomTextfield(
        label: 'Address *',
        prefixIcon: Icons.location_on_outlined,
        controller: _addressController,
        maxLines: 3,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your address';
          }
          return null;
        },
      ),

      const SizedBox(height: 16),

      CustomTextfield(
        label: 'Phone Number *',
        prefixIcon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
        controller: _phoneController,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your phone number';
          }
          return null;
        },
      ),

      const SizedBox(height: 24),

      // Payment Method
      Text(
        'Payment Method *',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      const SizedBox(height: 12),

      DropdownButtonFormField<String>(
        value: _selectedPaymentMethod,
        decoration: InputDecoration(
          labelText: 'Select Payment Method',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          prefixIcon: Icon(Icons.payment_rounded),
        ),
        items: _paymentMethods.map((method) {
          return DropdownMenuItem(
            value: method,
            child: Text(method),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedPaymentMethod = value;
          });
        },
        validator: (value) {
          if (value == null) {
            return 'Please select a payment method';
          }
          return null;
        },
      ),

      const SizedBox(height: 24),

      // Payment Slip Upload
      Text(
        'Upload Payment Slip *',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      const SizedBox(height: 12),

      GestureDetector(
        onTap: _pickSlipImage,
        child: Container(
          width: double.infinity,
          height: 150,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _slipImageUrl != null ? AppThemes.primaryGreen : Colors.grey[300]!,
              width: _slipImageUrl != null ? 2 : 1,
            ),
          ),
          child: _isUploading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(
                        'Uploading...',
                        style: GoogleFonts.poppins(),
                      ),
                    ],
                  ),
                )
              : _slipImageUrl != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _slipImageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
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
                          Icons.cloud_upload_outlined,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to upload payment slip',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Upload screenshot or photo of payment confirmation',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
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
              AppThemes.primaryGreen,
              AppThemes.lightGreen,
            ],
          ),
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isLoading
              ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(
                  'Submit Membership Payment',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    ];
  }

  Widget _buildPaymentStatusAfterSubmission() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _authController.getPaymentStatusStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData && snapshot.data != null) {
          final payment = snapshot.data!;
          final status = payment['status'] ?? 'pending';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: status == 'pending' ? Colors.blue[50] : 
                     status == 'approved' ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: status == 'pending' ? Colors.blue[200]! : 
                       status == 'approved' ? Colors.green[200]! : Colors.red[200]!,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      status == 'pending' ? Icons.pending_actions_rounded :
                      status == 'approved' ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: status == 'pending' ? Colors.blue : 
                             status == 'approved' ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        status == 'pending' ? 'Payment Under Review' :
                        status == 'approved' ? 'Payment Approved!' : 'Payment Rejected',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: status == 'pending' ? Colors.blue[700] : 
                                 status == 'approved' ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  status == 'pending' ? 
                  'Your payment is being reviewed. You will be notified once approved.' :
                  status == 'approved' ?
                  'Your membership has been activated! You can now schedule pickups.' :
                  'Your payment was rejected. Please contact support.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                if (status == 'rejected') ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _paymentSubmitted = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Resubmit Payment'),
                  ),
                ],
              ],
            ),
          );
        }
        
        return const SizedBox();
      },
    );
  }
}
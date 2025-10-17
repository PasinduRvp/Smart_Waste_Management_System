// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String name;
  final String role;
  final String? phone;
  final String? address;
  final String membershipStatus;
  final DateTime? membershipApprovedAt;
  final DateTime? membershipExpiry;
  final String? lastPaymentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.phone,
    this.address,
    this.membershipStatus = 'inactive',
    this.membershipApprovedAt,
    this.membershipExpiry,
    this.lastPaymentId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? 'resident',
      phone: data['phone'],
      address: data['address'],
      membershipStatus: data['membershipStatus'] ?? 'inactive',
      membershipApprovedAt: data['membershipApprovedAt'] != null 
          ? (data['membershipApprovedAt'] as Timestamp).toDate() 
          : null,
      membershipExpiry: data['membershipExpiry'] != null 
          ? (data['membershipExpiry'] as Timestamp).toDate() 
          : null,
      lastPaymentId: data['lastPaymentId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'phone': phone,
      'address': address,
      'membershipStatus': membershipStatus,
      'membershipApprovedAt': membershipApprovedAt != null 
          ? Timestamp.fromDate(membershipApprovedAt!) 
          : null,
      'membershipExpiry': membershipExpiry != null 
          ? Timestamp.fromDate(membershipExpiry!) 
          : null,
      'lastPaymentId': lastPaymentId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    String? phone,
    String? address,
    String? membershipStatus,
    DateTime? membershipApprovedAt,
    DateTime? membershipExpiry,
    String? lastPaymentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      membershipStatus: membershipStatus ?? this.membershipStatus,
      membershipApprovedAt: membershipApprovedAt ?? this.membershipApprovedAt,
      membershipExpiry: membershipExpiry ?? this.membershipExpiry,
      lastPaymentId: lastPaymentId ?? this.lastPaymentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get hasActiveMembership {
    if (membershipStatus != 'active') return false;
    if (membershipExpiry == null) return false;
    return membershipExpiry!.isAfter(DateTime.now());
  }

  bool get canSchedulePickups {
    return role == 'admin' || role == 'collector' || hasActiveMembership;
  }
}
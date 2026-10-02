import 'package:flutter/foundation.dart';

/// Model biểu diễn một lần thanh toán nợ (trả gốc và/hoặc trả lãi)
@immutable
class LoanPayment {
  final int? id;
  final int loanId;
  final DateTime paymentDate;
  final double totalAmount;
  final double principalPaid;
  final double interestPaid;
  final double remainingPrincipalAfter;
  final String? notes;
  final DateTime createdAt;

  const LoanPayment({
    this.id,
    required this.loanId,
    required this.paymentDate,
    required this.totalAmount,
    required this.principalPaid,
    required this.interestPaid,
    required this.remainingPrincipalAfter,
    this.notes,
    required this.createdAt,
  });

  factory LoanPayment.fromMap(Map<String, dynamic> map) {
    return LoanPayment(
      id: map['id'] as int?,
      loanId: map['loanId'] as int,
      paymentDate: DateTime.parse(map['paymentDate'] as String),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      principalPaid: (map['principalPaid'] as num).toDouble(),
      interestPaid: (map['interestPaid'] as num).toDouble(),
      remainingPrincipalAfter: (map['remainingPrincipalAfter'] as num).toDouble(),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'loanId': loanId,
      'paymentDate': paymentDate.toIso8601String(),
      'totalAmount': totalAmount,
      'principalPaid': principalPaid,
      'interestPaid': interestPaid,
      'remainingPrincipalAfter': remainingPrincipalAfter,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  LoanPayment copyWith({
    int? id,
    int? loanId,
    DateTime? paymentDate,
    double? totalAmount,
    double? principalPaid,
    double? interestPaid,
    double? remainingPrincipalAfter,
    String? notes,
    DateTime? createdAt,
  }) {
    return LoanPayment(
      id: id ?? this.id,
      loanId: loanId ?? this.loanId,
      paymentDate: paymentDate ?? this.paymentDate,
      totalAmount: totalAmount ?? this.totalAmount,
      principalPaid: principalPaid ?? this.principalPaid,
      interestPaid: interestPaid ?? this.interestPaid,
      remainingPrincipalAfter: remainingPrincipalAfter ?? this.remainingPrincipalAfter,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_schedule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PaymentScheduleAdapter extends TypeAdapter<PaymentSchedule> {
  @override
  final int typeId = 71;

  @override
  PaymentSchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PaymentSchedule(
      id: fields[0] as String,
      contractId: fields[1] as String,
      dueDate: fields[2] as DateTime,
      principalAmount: fields[3] as double,
      interestAmount: fields[4] as double,
      totalAmount: fields[5] as double,
      status: fields[6] as PaymentScheduleStatus,
      paymentDate: fields[7] as DateTime?,
      paidAmount: fields[8] as double,
      remainingAmount: fields[9] as double,
      paymentMethod: fields[10] as String?,
      transactionReference: fields[11] as String?,
      scheduleNumber: fields[12] as int,
      notes: fields[13] as String?,
      latePaymentStartDate: fields[14] as DateTime?,
      lateFee: fields[15] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, PaymentSchedule obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.contractId)
      ..writeByte(2)
      ..write(obj.dueDate)
      ..writeByte(3)
      ..write(obj.principalAmount)
      ..writeByte(4)
      ..write(obj.interestAmount)
      ..writeByte(5)
      ..write(obj.totalAmount)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.paymentDate)
      ..writeByte(8)
      ..write(obj.paidAmount)
      ..writeByte(9)
      ..write(obj.remainingAmount)
      ..writeByte(10)
      ..write(obj.paymentMethod)
      ..writeByte(11)
      ..write(obj.transactionReference)
      ..writeByte(12)
      ..write(obj.scheduleNumber)
      ..writeByte(13)
      ..write(obj.notes)
      ..writeByte(14)
      ..write(obj.latePaymentStartDate)
      ..writeByte(15)
      ..write(obj.lateFee);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PaymentScheduleStatusAdapter extends TypeAdapter<PaymentScheduleStatus> {
  @override
  final int typeId = 30;

  @override
  PaymentScheduleStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PaymentScheduleStatus.pending;
      case 1:
        return PaymentScheduleStatus.paid;
      case 2:
        return PaymentScheduleStatus.late;
      case 3:
        return PaymentScheduleStatus.defaulted;
      case 4:
        return PaymentScheduleStatus.partial;
      default:
        return PaymentScheduleStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, PaymentScheduleStatus obj) {
    switch (obj) {
      case PaymentScheduleStatus.pending:
        writer.writeByte(0);
        break;
      case PaymentScheduleStatus.paid:
        writer.writeByte(1);
        break;
      case PaymentScheduleStatus.late:
        writer.writeByte(2);
        break;
      case PaymentScheduleStatus.defaulted:
        writer.writeByte(3);
        break;
      case PaymentScheduleStatus.partial:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentScheduleStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

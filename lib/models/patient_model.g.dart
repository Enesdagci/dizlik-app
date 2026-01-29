// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patient_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PatientAdapter extends TypeAdapter<Patient> {
  @override
  final int typeId = 0;

  @override
  Patient read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Patient(
      id: fields[0] as String,
      deviceMac: fields[1] as String,
      fullName: fields[2] as String,
      tcNo: fields[3] as String,
      surgeryDate: fields[4] as DateTime,
      notes: fields[5] as String,
      createdAt: fields[6] as DateTime,
      lastMeasurement: fields[7] as DateTime?,
      surgeryType: fields[8] as String?,
      age: fields[9] as int?,
      gender: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Patient obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.deviceMac)
      ..writeByte(2)
      ..write(obj.fullName)
      ..writeByte(3)
      ..write(obj.tcNo)
      ..writeByte(4)
      ..write(obj.surgeryDate)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.lastMeasurement)
      ..writeByte(8)
      ..write(obj.surgeryType)
      ..writeByte(9)
      ..write(obj.age)
      ..writeByte(10)
      ..write(obj.gender);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatientAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
import 'package:flutter/material.dart';

// Method from https://github.com/riftdweb/rift/blob/main/packages/core/src/components/SkylinkInfo.tsx

const excellent = 8;
const good = 6;
const poor = 4;

class HealthStatus {
  final Color color;
  final String label;
  final int redundancy;
  final bool isPending;

  HealthStatus({
    required this.color,
    required this.label,
    required this.redundancy,
    required this.isPending,
  });
}

HealthStatus getHealthStatus(
    {required int redundancy, bool isPending = false}) {
  if (isPending && redundancy >= excellent) {
    return HealthStatus(
      color: Colors.green,
      label: 'Excellent health ($redundancy)',
      redundancy: redundancy,
      isPending: isPending,
    );
  }
  if (isPending && redundancy >= good) {
    return HealthStatus(
      color: Colors.green,
      label: 'At least good health ($redundancy)',
      redundancy: redundancy,
      isPending: isPending,
    );
  }
  if (isPending) {
    return HealthStatus(
      color: Colors.grey,
      label: 'Checking health ($redundancy)',
      redundancy: redundancy,
      isPending: isPending,
    );
  }

  if (redundancy >= excellent) {
    return HealthStatus(
      color: Colors.green,
      label: 'Excellent health ($redundancy)',
      redundancy: redundancy,
      isPending: isPending,
    );
  }
  if (redundancy >= good) {
    return HealthStatus(
      color: Colors.green,
      label: 'Good health ($redundancy)',
      redundancy: redundancy,
      isPending: isPending,
    );
  }
  if (redundancy >= poor) {
    return HealthStatus(
      color: Colors.red,
      label: 'Poor health ($redundancy)',
      redundancy: redundancy,
      isPending: isPending,
    );
  }
  return HealthStatus(
    color: Colors.red,
    label: 'Health at risk ($redundancy)',
    redundancy: redundancy,
    isPending: isPending,
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/models/app_models.dart';

class AppState {
  static final Semester _emptySemester = Semester(
    id: '',
    name: 'Select semester',
    subjects: const [],
  );

  static final ValueNotifier<UserProfile> profile =
      ValueNotifier<UserProfile>(
    UserProfile(
      name: 'Student',
      email: '',
      collegeName: '',
      semester: _emptySemester,
      subjects: [],
      isAdmin: false,
      isBlocked: false,
    ),
  );

  static void updateProfile(UserProfile updated) {
    profile.value = updated;
  }

  static final ValueNotifier<int> gameHubVisits = ValueNotifier<int>(0);

  static void notifyGameHub() {
    gameHubVisits.value = gameHubVisits.value + 1;
  }

  static void updateFromAuth(User? user) {
    if (user == null) {
      return;
    }
    final displayName = user.userMetadata?['full_name']?.toString();
    final college =
        user.userMetadata?['college_name']?.toString() ?? '';
    profile.value = UserProfile(
      name: displayName ?? (user.email ?? 'Student'),
      email: user.email ?? '',
      collegeName: college,
      semester: _emptySemester,
      subjects: const [],
      isAdmin: false,
      isBlocked: false,
    );
  }

  static void reset() {
    profile.value = UserProfile(
      name: 'Student',
      email: '',
      collegeName: '',
      semester: _emptySemester,
      subjects: const [],
      isAdmin: false,
      isBlocked: false,
    );
  }

  static final ValueNotifier<FocusLock?> focusLock =
      ValueNotifier<FocusLock?>(null);
  static final ValueNotifier<Duration> focusRemaining =
      ValueNotifier<Duration>(Duration.zero);
  static final ValueNotifier<bool> focusRunning = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> focusInBreak = ValueNotifier<bool>(false);
  static Timer? _focusTicker;

  static void startFocusLock({
    DateTime? endsAt,
    List<int> allowedIndices = const [1],
  }) {
    final safeAllowed =
        allowedIndices.isEmpty ? const [1] : allowedIndices;
    focusLock.value = FocusLock(
      startedAt: DateTime.now(),
      endsAt: endsAt,
      allowedIndices: safeAllowed,
    );
    _syncFocusTicker();
  }

  static void endFocusLock() {
    focusLock.value = null;
    _stopFocusTicker();
    focusRunning.value = false;
    focusInBreak.value = false;
  }

  static void updateFocusState({
    Duration? remaining,
    bool? running,
    bool? inBreak,
  }) {
    if (remaining != null) {
      focusRemaining.value = remaining;
    }
    if (running != null) {
      focusRunning.value = running;
    }
    if (inBreak != null) {
      focusInBreak.value = inBreak;
    }
    _syncFocusTicker();
  }

  static void _syncFocusTicker() {
    final lock = focusLock.value;
    if (lock == null || !focusRunning.value) {
      _stopFocusTicker();
      return;
    }
    if (_focusTicker != null) {
      return;
    }
    _focusTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final active = focusLock.value;
      if (active == null || !focusRunning.value) {
        _stopFocusTicker();
        return;
      }
      final endsAt = active.endsAt;
      if (endsAt == null) {
        return;
      }
      final remaining = endsAt.difference(DateTime.now());
      if (remaining.inSeconds <= 0) {
        focusRemaining.value = Duration.zero;
        focusRunning.value = false;
        _stopFocusTicker();
        return;
      }
      focusRemaining.value = remaining;
    });
  }

  static void _stopFocusTicker() {
    _focusTicker?.cancel();
    _focusTicker = null;
  }
}

class FocusLock {
  final DateTime startedAt;
  final DateTime? endsAt;
  final List<int> allowedIndices;

  const FocusLock({
    required this.startedAt,
    this.endsAt,
    this.allowedIndices = const [1],
  });
}

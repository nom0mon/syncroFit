import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/time_slot.dart';
import '../../../shared/models/trainer.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/consultation_provider.dart';

/// Booking form screen with date picker (no past dates), time slot selector,
/// consultation type selection, and an optional notes field (max 500 chars).
///
/// Validates: Requirements 11.4, 11.5, 11.6
class BookingFormScreen extends ConsumerStatefulWidget {
  const BookingFormScreen({required this.trainerId, super.key});

  final String trainerId;

  @override
  ConsumerState<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends ConsumerState<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime? _selectedDate;
  TimeSlot? _selectedTimeSlot;
  ConsultationType _consultationType = ConsultationType.inPerson;
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Returns available (not booked) slots for the selected date.
  List<TimeSlot> _availableSlotsForDate(Trainer trainer) {
    if (_selectedDate == null) return [];
    return trainer.availableSlots
        .where((slot) =>
            !slot.isBooked &&
            slot.date.year == _selectedDate!.year &&
            slot.date.month == _selectedDate!.month &&
            slot.date.day == _selectedDate!.day)
        .toList();
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        // Reset time slot when date changes
        _selectedTimeSlot = null;
      });
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null || _selectedTimeSlot == null) {
      // Validation should catch this, but guard anyway
      return;
    }

    setState(() => _isSubmitting = true);

    final success =
        await ref.read(consultationProvider.notifier).submitBooking(
              trainerId: widget.trainerId,
              date: _selectedDate!,
              timeSlot: _selectedTimeSlot!.time,
              consultationType: _consultationType,
              notes: _notesController.text.isNotEmpty
                  ? _notesController.text
                  : null,
            );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Consultation booked successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Pop back to trainer profile
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to book consultation. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainerAsync = ref.watch(trainerDetailProvider(widget.trainerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Consultation'),
      ),
      body: trainerAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => Center(
          child: Text('Error: ${error.toString()}'),
        ),
        data: (trainer) {
          if (trainer == null) {
            return const Center(
              child: Text('Trainer not found'),
            );
          }
          return _buildForm(context, trainer);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, Trainer trainer) {
    final theme = Theme.of(context);
    final availableSlots = _availableSlotsForDate(trainer);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trainer header
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    trainer.avatarPlaceholder,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  trainer.name,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Date picker field
            Text(
              'Select Date',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            FormField<DateTime>(
              validator: (_) {
                if (_selectedDate == null) {
                  return 'Please select a date';
                }
                return null;
              },
              builder: (fieldState) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _pickDate(context),
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          hintText: 'Tap to select date',
                          prefixIcon: const Icon(Icons.calendar_today),
                          errorText: fieldState.errorText,
                        ),
                        child: Text(
                          _selectedDate != null
                              ? '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}'
                              : 'Tap to select date',
                          style: _selectedDate != null
                              ? theme.textTheme.bodyLarge
                              : theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // Time slot selector
            Text(
              'Select Time Slot',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_selectedDate == null)
              Text(
                'Please select a date first',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else if (availableSlots.isEmpty)
              Text(
                'No available slots for this date',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            else
              FormField<TimeSlot>(
                validator: (_) {
                  if (_selectedTimeSlot == null) {
                    return 'Please select a time slot';
                  }
                  return null;
                },
                builder: (fieldState) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: availableSlots.map((slot) {
                          final isSelected = _selectedTimeSlot == slot;
                          return ChoiceChip(
                            label: Text(slot.time),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() => _selectedTimeSlot = slot);
                            },
                          );
                        }).toList(),
                      ),
                      if (fieldState.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            fieldState.errorText!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: AppSpacing.lg),

            // Consultation type
            Text(
              'Consultation Type',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<ConsultationType>(
              segments: const [
                ButtonSegment(
                  value: ConsultationType.inPerson,
                  label: Text('In-Person'),
                  icon: Icon(Icons.person),
                ),
                ButtonSegment(
                  value: ConsultationType.videoCall,
                  label: Text('Video Call'),
                  icon: Icon(Icons.videocam),
                ),
              ],
              selected: {_consultationType},
              onSelectionChanged: (selected) {
                setState(() => _consultationType = selected.first);
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // Notes field
            Text(
              'Notes (optional)',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _notesController,
              maxLength: 500,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Add any notes for the trainer...',
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value != null && value.length > 500) {
                  return 'Notes must be 500 characters or less';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submitBooking,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirm Booking'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

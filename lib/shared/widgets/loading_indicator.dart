import 'package:flutter/material.dart';

/// A centered [CircularProgressIndicator] for use during async data fetches.
///
/// Drop this into any builder when an `AsyncValue` is in the loading state.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:quiverfall/core/theme/tokens.dart';

/// Stand-in for a screen that a later phase will build.
///
/// Every route in docs/11-screen-flow.md is wired from Phase 1 so the
/// navigation graph, guards, and back-stack behaviour are testable before any
/// screen exists. Each placeholder names the phase that replaces it, so an
/// unfinished screen is self-documenting rather than a mystery.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    required this.title,
    required this.buildPhase,
    this.detail,
    super.key,
  });

  final String title;

  /// Roadmap phase that implements this screen.
  final int buildPhase;

  final String? detail;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Tokens.bgRaised,
                  borderRadius: BorderRadius.circular(Tokens.radiusCard),
                ),
                alignment: Alignment.center,
                child: Text('P$buildPhase', style: text.titleMedium),
              ),
              const SizedBox(height: Tokens.space4),
              Text(title, style: text.titleLarge),
              const SizedBox(height: Tokens.space2),
              Text(
                detail ?? 'Built in Phase $buildPhase.',
                style: text.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

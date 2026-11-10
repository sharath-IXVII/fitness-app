import '../../core/i18n/i18n.dart';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/page_background.dart';
import 'domain/move.dart';
import 'widgets/move_widgets.dart';

/// Every exercise with its animation and how-to, filterable by body part.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  /// null = all; otherwise a body focus, or 'stretch' for warm-ups.
  Object? _filter;
  String _query = '';

  List<Move> get _moves {
    final q = _query.trim().toLowerCase();
    return [
      for (final m in Moves.all)
        if ((_filter == null || (_filter == 'stretch' ? Moves.stretches.contains(m) : m.focus.contains(_filter))) &&
            (q.isEmpty || m.name.toLowerCase().contains(q) || m.muscles.toLowerCase().contains(q)))
          m,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final moves = _moves;
    final filters = <(Object?, String)>[
      (null, 'All'),
      for (final f in BodyFocus.values) (f, f.label),
      ('stretch', 'Warm-up & stretch'),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(tr('Exercise library'))),
      body: PageBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: tr('Search exercises or muscles'),
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ChoicePill(
                  label: filters[i].$2,
                  selected: _filter == filters[i].$1,
                  onTap: () => setState(() => _filter = filters[i].$1),
                ),
              ),
            ),
            Expanded(
              child: moves.isEmpty
                  ? Center(child: Text(tr('No exercises found'), style: text.bodyMedium))
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        Text(
                          '${moves.length} exercises',
                          style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                        ),
                        for (final m in moves) MoveRow(move: m),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/ui/theme.dart';
import '../../domain/entities/interest.dart';
import '../../domain/entities/registration_data.dart';
import '../auth_texts.dart';

/// Hoja inferior para editar intereses (FR-018). Se cierra con `true` si se
/// guardaron cambios.
class EditInterestsSheet extends StatefulWidget {
  const EditInterestsSheet({
    required this.initial,
    required this.onSave,
    super.key,
  });

  final List<Interest> initial;
  final Future<Result<void>> Function(List<Interest> interests) onSave;

  static Future<bool?> show(
    BuildContext context, {
    required List<Interest> initial,
    required Future<Result<void>> Function(List<Interest>) onSave,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => EditInterestsSheet(initial: initial, onSave: onSave),
    );
  }

  @override
  State<EditInterestsSheet> createState() => _EditInterestsSheetState();
}

class _EditInterestsSheetState extends State<EditInterestsSheet> {
  late final List<Interest> _selected = [...widget.initial];
  bool _saving = false;
  Failure? _failure;

  bool get _isValid => RegistrationRules.isValidInterests(_selected);

  bool get _changed =>
      _selected.length != widget.initial.length ||
      !_selected.every(widget.initial.contains);

  void _toggle(Interest interest) {
    setState(() {
      _failure = null;
      if (!_selected.remove(interest)) _selected.add(interest);
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _failure = null;
    });
    final result = await widget.onSave(List.unmodifiable(_selected));
    if (!mounted) return;
    switch (result) {
      case Success():
        Navigator.of(context).pop(true);
      case Err(:final failure):
        setState(() {
          _saving = false;
          _failure = failure;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failure = _failure;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.spacing * 1.5,
          0,
          AppSizes.spacing * 1.5,
          AppSizes.spacing * 1.5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text('Tus intereses', style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            Text(
              'Elige de ${RegistrationRules.interestsMin} a '
              '${RegistrationRules.interestsMax} temas '
              '(${_selected.length} seleccionados). Tu inicio se adapta a '
              'lo que elijas.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSizes.spacing),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final interest in Interest.values)
                  FilterChip(
                    avatar: Icon(interest.icon, size: 18),
                    label: Text(interest.label),
                    selected: _selected.contains(interest),
                    onSelected: _saving ? null : (_) => _toggle(interest),
                  ),
              ],
            ),
            if (!_isValid) ...[
              const SizedBox(height: AppSizes.spacing),
              Semantics(
                liveRegion: true,
                child: Text(
                  AuthTexts.fieldError('interests'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
            if (failure != null) ...[
              const SizedBox(height: AppSizes.spacing),
              Semantics(
                liveRegion: true,
                child: Text(
                  AuthTexts.forFailure(failure),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: AppSizes.spacing * 1.5),
            FilledButton(
              onPressed: _isValid && _changed && !_saving ? _save : null,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: 'Guardando',
                      ),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

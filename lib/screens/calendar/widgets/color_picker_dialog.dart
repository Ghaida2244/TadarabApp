import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../calendar_styles.dart';

/// Below this content width, `flutter_colorpicker`'s hex input row overflows
/// its own `Row` (measured: it breaks between 230px and 240px). Narrower
/// than this the bar is dropped rather than shipped clipped — the saturation
/// area and hue slider still give the full gamut.
const double kHexInputMinWidth = 240;

/// The free-form event colour picker behind the swatch row's dashed "+".
///
/// The handoff uses the platform's native colour input, so this offers the
/// same full gamut: a saturation/value area, a hue slider and a hex field.
/// Calendar only — the Courses feature keeps its own hue-slider dialog, so
/// the two are deliberately no longer identical.
///
/// Resolves to the chosen colour, or null if the student cancels.
Future<Color?> showEventColorPicker({
  required BuildContext context,
  required Color initial,
}) {
  return showDialog<Color>(
    context: context,
    builder: (_) => EventColorPickerDialog(initial: initial),
  );
}

/// The dialog behind [showEventColorPicker]. Public so it can be
/// widget-tested directly.
class EventColorPickerDialog extends StatefulWidget {
  const EventColorPickerDialog({super.key, required this.initial});

  /// The colour the picker opens on — whatever the form currently holds.
  final Color initial;

  @override
  State<EventColorPickerDialog> createState() =>
      _EventColorPickerDialogState();
}

class _EventColorPickerDialogState extends State<EventColorPickerDialog> {
  late Color _color = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      // Tighter than the delete dialog's 26px so a 320dp phone still clears
      // [kHexInputMinWidth] and keeps the hex field.
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pick a color', style: CalendarText.dialogTitle),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) => ColorPicker(
                  pickerColor: _color,
                  onColorChanged: (picked) => setState(() => _color = picked),
                  // Events store "#RRGGBB", so there is nowhere to put an
                  // alpha channel.
                  enableAlpha: false,
                  hexInputBar: constraints.maxWidth >= kHexInputMinWidth,
                  displayThumbColor: true,
                  colorPickerWidth: constraints.maxWidth,
                  pickerAreaHeightPercent: 0.7,
                  // The package picks its layout from MediaQuery.orientation,
                  // and its landscape branch lays the picker out beside a
                  // hard-coded 260px slider — which overflows any dialog.
                  // A dialog on a phone wants the stacked layout either way,
                  // so pin it rather than depend on orientation.
                  portraitOnly: true,
                  paletteType: PaletteType.hsvWithHue,
                  // The built-in label rows restate the hex field; the
                  // design shows neither.
                  labelTypes: const [],
                  pickerAreaBorderRadius: const BorderRadius.all(
                    Radius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Use this color',
                variant: AppButtonVariant.accent,
                height: 52,
                borderRadius: 16,
                fontSize: 15,
                onPressed: () => Navigator.of(context).pop(_color),
              ),
              const SizedBox(height: 13),
              AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.outlinedNeutral,
                height: 46,
                borderRadius: 16,
                borderColor: AppColors.borderDefault,
                fontSize: 14,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

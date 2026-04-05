// excel_import_widgets.dart - Part of function_excel_import_page.dart.
// _ImportModeCard: card for selecting samples vs strains import mode.
// _FilePicker: file pick button row showing selected file name.
// _StepIndicator: horizontal step progress bar.
// _FakeVsync: TickerProvider stub for dialogs without a State mixin.
part of 'function_excel_import_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Import mode selection card
// ─────────────────────────────────────────────────────────────────────────────
class _ImportModeCard extends StatelessWidget {
  final String mode;
  final String label;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ImportModeCard({
    required this.mode,
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.08)
              : const Color(0xFFF8FAFC),
          border: Border.all(
              color: selected ? primary : const Color(0xFFCBD5E1),
              width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(icon, color: selected ? primary : Colors.grey.shade500, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:
                              selected ? primary : const Color(0xFF334155))),
                  Text(description,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ]),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, color: primary, size: 20),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step indicator
// ─────────────────────────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current;
  final List<String> labels;
  const _StepIndicator({required this.current, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 12, right: 12),
      child: Row(
        children: List.generate(labels.length, (i) {
          final done = i < current;
          final active = i == current;
          final color = active
              ? Theme.of(context).colorScheme.primary
              : done
                  ? Colors.green
                  : Colors.grey.shade400;
          return Expanded(
            child: Row(children: [
              if (i > 0)
                Expanded(
                    child: Container(
                        height: 2,
                        color: done ? Colors.green : Colors.grey.shade300)),
              Column(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: color,
                  child: done
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 2),
                Text(labels[i],
                    style: TextStyle(
                        fontSize: 9,
                        color: color,
                        fontWeight: active
                            ? FontWeight.bold
                            : FontWeight.normal)),
              ]),
            ]),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// File picker row
// ─────────────────────────────────────────────────────────────────────────────
class _FilePicker extends StatelessWidget {
  final String label;
  final String fileName;
  final IconData icon;
  final VoidCallback onPick;

  const _FilePicker({
    required this.label,
    required this.fileName,
    required this.icon,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final picked = fileName.isNotEmpty;
    return OutlinedButton.icon(
      onPressed: onPick,
      icon: Icon(picked ? Icons.check_circle : icon,
          color: picked ? Colors.green : null),
      label: Text(
        picked ? fileName : label,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(44),
        foregroundColor: picked ? Colors.green : null,
        side: picked
            ? BorderSide(color: Colors.green.shade400)
            : null,
      ),
    );
  }
}

class _FakeVsync implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}
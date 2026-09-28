import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Ferme le clavier quand on touche l'écran hors du champ actif, comme sur
/// le web. Posé une fois autour de l'app (`MaterialApp.builder`), il vaut
/// pour toutes les pages et feuilles.
///
/// Par défaut, Flutter ne le fait pas sur téléphone : sur iOS, le pavé
/// numérique n'a pas de touche pour se fermer et le clavier restait bloqué.
/// Seul un toucher bref ferme le clavier : faire défiler la page le laisse
/// ouvert (les corps défilants le ferment eux-mêmes au glissé). Toucher un
/// autre champ passe simplement le focus à celui-ci.
class KeyboardTapOutside extends StatefulWidget {
  const KeyboardTapOutside({super.key, required this.child});

  final Widget child;

  @override
  State<KeyboardTapOutside> createState() => _KeyboardTapOutsideState();
}

class _KeyboardTapOutsideState extends State<KeyboardTapOutside> {
  PointerDownEvent? _down;

  void _onTapOutsideDown(EditableTextTapOutsideIntent intent) {
    final event = intent.pointerDownEvent;
    if (event.kind == PointerDeviceKind.touch) {
      // Décision au relâché : un glissé n'est pas un toucher.
      _down = event;
    } else {
      // Souris, stylet : comportement par défaut de Flutter.
      intent.focusNode.unfocus();
    }
  }

  void _onTapOutsideUp(EditableTextTapUpOutsideIntent intent) {
    final down = _down;
    _down = null;
    if (down == null || down.pointer != intent.pointerUpEvent.pointer) return;
    final distance = (intent.pointerUpEvent.position - down.position).distance;
    if (distance < kTouchSlop) intent.focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        EditableTextTapOutsideIntent:
            CallbackAction<EditableTextTapOutsideIntent>(
          onInvoke: _onTapOutsideDown,
        ),
        EditableTextTapUpOutsideIntent:
            CallbackAction<EditableTextTapUpOutsideIntent>(
          onInvoke: _onTapOutsideUp,
        ),
      },
      child: widget.child,
    );
  }
}

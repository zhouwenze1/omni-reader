typedef RendererJson = Map<String, dynamic>;

enum RendererCommand {
  init,
  configure,
  open,
  navigate,
  clearSelection,
  reset,
  getSelectionAnchor,
  applyHighlight,
  applyHighlights,
  removeHighlight,
  updateHighlight,
}

extension RendererCommandName on RendererCommand {
  String get wireName {
    switch (this) {
      case RendererCommand.init:
        return 'init';
      case RendererCommand.configure:
        return 'configure';
      case RendererCommand.open:
        return 'open';
      case RendererCommand.navigate:
        return 'navigate';
      case RendererCommand.clearSelection:
        return 'clearSelection';
      case RendererCommand.reset:
        return 'reset';
      case RendererCommand.getSelectionAnchor:
        return 'getSelectionAnchor';
      case RendererCommand.applyHighlight:
        return 'applyHighlight';
      case RendererCommand.applyHighlights:
        return 'applyHighlights';
      case RendererCommand.removeHighlight:
        return 'removeHighlight';
      case RendererCommand.updateHighlight:
        return 'updateHighlight';
    }
  }
}

RendererCommand? rendererCommandFromWireName(String value) {
  for (final command in RendererCommand.values) {
    if (command.wireName == value) {
      return command;
    }
  }
  return null;
}

class RendererNavigatePayload {
  const RendererNavigatePayload._(this.kind, [this.value]);

  const RendererNavigatePayload.next() : this._('next');

  const RendererNavigatePayload.prev() : this._('prev');

  const RendererNavigatePayload.progression(double value)
    : this._('progression', value);

  const RendererNavigatePayload.anchor(String value) : this._('anchor', value);

  final String kind;
  final Object? value;

  RendererJson toJson() {
    return <String, dynamic>{'kind': kind, if (value != null) 'value': value};
  }
}

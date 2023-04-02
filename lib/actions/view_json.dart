import 'dart:convert';

import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';

import 'base.dart';

class ViewJSONVupAction extends VupFSAction {
  @override
  VupFSActionInstance? check(
      bool isFile,
      dynamic entity,
      PathNotifierState pathNotifier,
      BuildContext context,
      bool isDirectoryView,
      bool hasWriteAccess,
      FileState fileState,
      bool isSelected) {
    if (isDirectoryView) return null;
    if (!devModeEnabled) return null;
    if (entity == null) return null;

    return VupFSActionInstance(
      label: 'View JSON (Debug)',
      icon: UniconsLine.brackets_curly,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('JSON Metadata'),
        content: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: SingleChildScrollView(
            reverse: true,
            child: SelectableText(
              // TODO Include full JSON fields
              const JsonEncoder.withIndent('  ').convert(
                instance.entity,
              ),
              /* language: 'json',
                            theme: draculaTheme,
                            padding: EdgeInsets.all(12), */
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

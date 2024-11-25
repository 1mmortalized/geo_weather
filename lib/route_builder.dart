import 'package:flutter/material.dart';

class NavigateFullscreenDialog extends StatefulWidget {
  const NavigateFullscreenDialog({super.key});

  @override
  State<NavigateFullscreenDialog> createState() => _NavigateFullscreenDialogState();
}

class _NavigateFullscreenDialogState extends State<NavigateFullscreenDialog> {
  @override
  Widget build(BuildContext context) {
    return const Hero(
      tag: 'navigate-dialog',
      child: Dialog.fullscreen(

      ),
    );
  }
}

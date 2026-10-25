import 'package:flutter/material.dart';

class ShopFlowPageLayout extends StatelessWidget {
  const ShopFlowPageLayout({
    super.key,
    required this.child,
    this.maxWidth = 820,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 600;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isPhone ? 16 : 20,
          isPhone ? 16 : 20,
          isPhone ? 16 : 20,
          0,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}
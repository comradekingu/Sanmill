import 'package:flutter/material.dart';

import 'board-widget.dart';

abstract class PainterBase extends CustomPainter {
  //
  final double width;

  final thePaint = Paint();
  final gridWidth;
  final squareWidth;

  PainterBase({@required this.width})
      : gridWidth = (width - BoardWidget.padding * 2),
        squareWidth = (width - BoardWidget.padding * 2) / 7;
}
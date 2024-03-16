import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ScrollHideShowLogic {
  final double containerHeight;
  late double fromTop;
  final ScrollController controller;

  ScrollHideShowLogic({required this.containerHeight, required this.controller}) {
    fromTop = 0.0;
    controller.addListener(_listener);
  }

  void _listener() {
    double offset = controller.offset;
    var direction = controller.position.userScrollDirection;

    if (direction == ScrollDirection.reverse) {
      if (fromTop > 0) {
        var difference = offset - (offset - fromTop);
        fromTop = fromTop - difference;
        if (fromTop < 0) fromTop = 0;
      }
    } else if (direction == ScrollDirection.forward) {
      if (fromTop < containerHeight) {
        var difference = offset - (offset - fromTop);
        fromTop = fromTop + difference;
        if (fromTop > containerHeight) fromTop = containerHeight;
      }
    }
  }
}

import 'package:flutter/material.dart';

// Dark mode colors based on your hex codes
const Color darkLBackgroundColor =
    Color(0xFF282828); // Dark background for mobile
const Color darkBackgroundColor = Color(
    0xff1e1e1e); // Dark background for web (can be the same or slightly different if needed)

const Color darkerBackgroundColor = Color.fromARGB(255, 19, 19, 19);

const Color primaryColor = Color(0xFFFFFFFF); // White color for text and icons
const Color secondaryColor = Color(
    0xFF282828); // Assuming secondary color is the same as the background for certain elements
const Color highlightColor =
    Color(0xFF2AF89B); // Highlight color, used for buttons and icons


Color darkerHighlightColor1 = Color.lerp(highlightColor, Colors.black, 0.2)!; // 20% darker
Color darkerHighlightColor2 = Color.lerp(highlightColor, Colors.black, 0.4)!; // 40% darker
Color darkerHighlightColor3 = Color.lerp(highlightColor, Colors.black, 0.6)!; // 60% darker


// Additional colors that you might need
const Color blueColor = Color(
    0xFF95f985); // If you need a blue color, replace this with the hex value you desire
const Color greyColor =
    Color(0xFF9E9E9E); // Grey color for less emphasized text or elements
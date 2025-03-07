import 'package:flutter/material.dart';

class AppTheme {
  // ---------------------------
  // Couleurs & Images
  // ---------------------------
  static const Color primaryColor   = Color(0xFF4D758A);
  static const Color accentYellow   = Color(0xFFFEE8BB);
  static const Color subtitleWhite  = Color(0xFFFFFCF6);
  static const Color textBlue       = Color(0xFF355474);
  static const Color darkerBlue     = Color(0xFF162B40);
  static const Color white          = Colors.white;
  static const Color incorrectRed   = Color.fromARGB(255, 223, 10, 10);
  static const Color boldRed        = Color(0xFFB71C1C);
  static const Color correctGreen   = Color.fromARGB(255, 3, 207, 6);

  static const String homeBackground    = 'assets/images/home-background.png';
  static const String defaultBackground = 'assets/images/background2.png';

  // ---------------------------
  // Theme Global
  // ---------------------------
  static ThemeData get themeData {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'Nunito',
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(fontSize: 14, color: primaryColor),
        floatingLabelStyle: TextStyle(fontSize: 12, color: primaryColor),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: primaryColor),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: primaryColor,
        selectionColor: Color.fromARGB(100, 77, 117, 138),
        selectionHandleColor: primaryColor,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          fontFamily: 'PermanentMarker',
          color: accentYellow,
          shadows: [
            Shadow(
              color: Colors.black38,
              blurRadius: 6,
              offset: Offset(2, 4),
            ),
          ],
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: subtitleWhite,
        ),
        bodyLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
        bodyMedium: TextStyle(
          fontSize: 18,
          color: primaryColor,
        ),
        bodySmall: TextStyle(
          fontSize: 16,
          color: primaryColor,
        ),
      ),
      appBarTheme: const AppBarTheme(
        color: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: white),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Nunito'),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: subtitleWhite,
        titleTextStyle: const TextStyle(fontSize: 22, color: primaryColor, fontFamily: 'Nunito'),
        contentTextStyle: const TextStyle(fontSize: 15, color: primaryColor, fontFamily: 'Nunito'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: primaryColor, width: 4),
        ),
      ),
    );
  }

  // ---------------------------
  // Utilitaires de Style
  // ---------------------------
  static TextStyle nunitoTextStyle({
    double fontSize = 20,
    Color? color,
    bool bold = false,
    FontStyle fontStyle = FontStyle.normal,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontFamily: 'Nunito',
      color: color ?? primaryColor,
      fontStyle: fontStyle,
    );
  }

  static BoxDecoration backgroundDecoration({bool isHome = false}) {
    return BoxDecoration(
      image: DecorationImage(
        image: AssetImage(isHome ? homeBackground : defaultBackground),
        fit: BoxFit.cover,
      ),
    );
  }

  static Widget customButton({
    required String label,
    required VoidCallback? onPressed,
    Color? backgroundColor,
  }) {
    final Color mainColor = backgroundColor ?? primaryColor;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        boxShadow: const [
          BoxShadow(
            color: darkerBlue,
            blurRadius: 3,
            offset: Offset(3, 5),
          ),
        ],
        borderRadius: BorderRadius.circular(25),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith<Color>(
            (states) {
              if (states.contains(MaterialState.disabled)) return mainColor.withOpacity(0.5);
              if (states.contains(MaterialState.pressed)) return mainColor.withOpacity(0.7);
              return mainColor;
            },
          ),
          foregroundColor: MaterialStateProperty.all<Color>(white),
          textStyle: MaterialStateProperty.all<TextStyle>(
            const TextStyle(fontSize: 20, fontFamily: 'Nunito-bold'),
          ),
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
              side: const BorderSide(color: white, width: 2),
            ),
          ),
        ),
        child: Text(label),
      ),
    );
  }

  static TextStyle topLabelStyle(BuildContext context, double fontScale) {
    final screenWidth = MediaQuery.of(context).size.width;
    return TextStyle(
      fontFamily: 'Nunito',
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.italic,
      fontSize: screenWidth * fontScale,
      color: textBlue,
    );
  }

  static TextStyle rankStyle(BuildContext context, double fontScale) {
    final screenWidth = MediaQuery.of(context).size.width;
    return TextStyle(
      fontFamily: 'Nunito',
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.italic,
      fontSize: screenWidth * fontScale,
      color: textBlue,
    );
  }

  static TextStyle circleNumberStyle(double circleSize) {
    return TextStyle(
      fontSize: circleSize * 0.2,
      color: white,
      fontWeight: FontWeight.bold,
      fontFamily: 'Nunito',
    );
  }

  static BoxDecoration transientMessageBoxDecoration(double borderRadius) {
    return BoxDecoration(
      color: primaryColor,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: const [
        BoxShadow(
          color: Colors.black26,
          blurRadius: 5,
          offset: Offset(0, 3),
        ),
      ],
    );
  }

  static TextStyle transientMessageTextStyle(double fontSize) {
    return TextStyle(
      fontSize: fontSize,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.bold,
      color: white,
    );
  }
}

// lib/styles/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // ---------------------------------------------------------------------------
  // COULEURS
  // ---------------------------------------------------------------------------
  static const Color titleYellow   = Color(0xFFFEE8BB);
  static const Color subtitleWhite = Color(0xFFFFFCF6);

  static const Color white         = Colors.white;
  static const Color textBlue = Color.fromRGBO(53, 84, 116, 0);

  static const Color buttonBlue    = Color(0xFF4D758A);
  static const Color incorrectRed    = Color.fromARGB(255, 223, 10, 10);
  static const Color correctGreen    = Color.fromARGB(255, 3, 207, 6);

  

  // ---------------------------------------------------------------------------
  // IMAGES DE FOND
  // ---------------------------------------------------------------------------
  static const String homeBackground    = 'assets/images/home-background.png';
  static const String defaultBackground = 'assets/images/background2.png';

  // ---------------------------------------------------------------------------
  // THEME GLOBAL
  // ---------------------------------------------------------------------------
  static ThemeData themeData = ThemeData(
    primaryColor: buttonBlue,
    scaffoldBackgroundColor: Colors.transparent,
    fontFamily: 'Nunito',

    // Personnalisation de l'écriture dans les TextFields
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: const TextStyle(
        fontSize: 14,
        color: buttonBlue,
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 12,
        color: buttonBlue,
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: buttonBlue),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: buttonBlue, width: 2),
      ),
    ),

    // Personnalisation de la sélection, du curseur etc.
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: buttonBlue, // Couleur du curseur
      // Sélection en bleu translucide (exemple ARGB similaire à l'ancien code)
      selectionColor: const Color.fromARGB(100, 77, 117, 138),
      selectionHandleColor: buttonBlue,
    ),

    // Thème de la typo
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        fontFamily: 'PermanentMarker',
        color: titleYellow,
        shadows: [
          // On conserve l'ombre du style précédent
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
        color: buttonBlue,
      ),
      bodyMedium: TextStyle(
        fontSize: 18,
        color: buttonBlue,
      ),
      bodySmall: TextStyle(
        fontSize: 16,
        color: buttonBlue,
      ),
    ),

    // Barre d'app bar
    appBarTheme: const AppBarTheme(
      color: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: white,
      ),
    ),

    // Thème des TextButtons
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: buttonBlue,
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Nunito',
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    ),

    // Thème des Dialogues
    dialogTheme: DialogTheme(
      backgroundColor: subtitleWhite,
      titleTextStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: buttonBlue,
        fontFamily: 'Nunito-Bold',
      ),
      contentTextStyle: const TextStyle(
        fontSize: 15,
        color: buttonBlue,
        fontFamily: 'Nunito',
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: buttonBlue, width: 4),
      ),
    ),
  );

  // ---------------------------------------------------------------------------
  // UTILITAIRES DE STYLE
  // ---------------------------------------------------------------------------

  /// Style "Nunito" paramétrable pour du texte
  static TextStyle nunitoTextStyle({
    double fontSize = 20,
    Color? color,
    bool bold = false,
    FontStyle fontStyle = FontStyle.normal,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontFamily: 'Nunito-Bold',
      color: color ?? buttonBlue,
      fontStyle: fontStyle,
    );
  }

  /// Décoration de fond par défaut
  /// isHome = true => background de la home
  /// isHome = false => background par défaut
  static BoxDecoration backgroundDecoration({bool isHome = false}) {
    return BoxDecoration(
      image: DecorationImage(
        image: AssetImage(isHome ? homeBackground : defaultBackground),
        fit: BoxFit.cover,
      ),
    );
  }

  /// Bouton personnalisé
  static Widget customButton({
    required String label,
    required VoidCallback? onPressed,
    Color? backgroundColor,
  }) {
    final Color mainColor = backgroundColor ?? buttonBlue;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.8),
            blurRadius: 5,
            offset: const Offset(4, 7),
          ),
        ],
        borderRadius: BorderRadius.circular(25),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith<Color>(
            (states) {
              // État désactivé
              if (states.contains(MaterialState.disabled)) {
                return mainColor.withOpacity(0.5);
              }
              // État pressé
              if (states.contains(MaterialState.pressed)) {
                return mainColor.withOpacity(0.7);
              }
              // État normal
              return mainColor;
            },
          ),
          foregroundColor: MaterialStateProperty.all<Color>(white),
          textStyle: MaterialStateProperty.all<TextStyle>(
            const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Nunito',
            ),
          ),
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
              side: const BorderSide(
                color: white,
                width: 2,
              ),
            ),
          ),
        ),
        child: Text(label),
      ),
    );
  }

  /// Exemple de style de label en haut
  static TextStyle topLabelStyle(BuildContext context, double fontScale) {
    final screenWidth = MediaQuery.of(context).size.width;
    return TextStyle(
      fontFamily: 'Nunito',
      fontWeight: FontWeight.w300,
      fontStyle: FontStyle.italic,
      fontSize: screenWidth * fontScale,
      color: buttonBlue,
    );
  }

  /// Exemple de style rank
  static TextStyle rankStyle(BuildContext context, double fontScale) {
    final screenWidth = MediaQuery.of(context).size.width;
    return TextStyle(
      fontFamily: 'Nunito',
      fontWeight: FontWeight.w300,
      fontStyle: FontStyle.italic,
      fontSize: screenWidth * fontScale,
      color: buttonBlue,
    );
  }

  /// Style pour un chiffre dans un cercle
  static TextStyle circleNumberStyle(double circleSize) {
    return TextStyle(
      fontSize: circleSize * 0.2,
      color: white,
      fontWeight: FontWeight.bold,
      fontFamily: 'Nunito',
    );
  }

  /// Décoration d'un petit message en surimpression
  static BoxDecoration transientMessageBoxDecoration(double borderRadius) {
    return BoxDecoration(
      color: buttonBlue,
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

  /// Style texte pour un petit message en surimpression
  static TextStyle transientMessageTextStyle(double fontSize) {
    return TextStyle(
      fontSize: fontSize,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.bold,
      color: white,
    );
  }
}

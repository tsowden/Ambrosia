// lib/styles/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // ---------------------------------------------------------------------------
  // COULEURS
  // ---------------------------------------------------------------------------
  static const Color greenButton = Color(0xFF135836);
  static const Color redButton = Color(0xFFBF1A2F); 
  static const Color darkerGreen = Color.fromARGB(255, 6, 37, 22);
  static const Color lightMint   = Color.fromARGB(255, 211, 248, 228);
  static const Color orangeTitle = Color.fromARGB(255, 240, 110, 10);
  static const Color white       = Colors.white;

  static const Color correctGreen  = Color(0xFF8BDD8E); 
  static const Color incorrectRed  = Color(0xFFF28080);

  // ---------------------------------------------------------------------------
  // IMAGE DE FOND
  // ---------------------------------------------------------------------------
  static const String backgroundImage = 'assets/images/fond2.png';

  // ---------------------------------------------------------------------------
  // THEME GLOBAL
  // ---------------------------------------------------------------------------
  static ThemeData themeData = ThemeData(
    // Couleurs principales
    primaryColor: greenButton,
    scaffoldBackgroundColor: Colors.transparent,
    fontFamily: 'Nunito',

    // Personnalisation de l'écriture dans les TextFields
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: const TextStyle(
        fontSize: 14,
        color: greenButton,
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 12,
        color: greenButton,
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: const BorderSide(color: greenButton),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: const BorderSide(color: greenButton, width: 2),
      ),
    ),

    // Personnalisation de la sélection, du curseur etc.
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: greenButton, // Couleur du curseur
      selectionColor: Color.fromARGB(100, 19, 88, 54), // Sélection en vert translucide
      selectionHandleColor: greenButton, // Poignet de sélection (pour le drag)
    ),

    // Thème de la typo
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        fontFamily: 'PermanentMarker',
        color: orangeTitle,
        shadows: [
          Shadow(
            color: Colors.black38,
            blurRadius: 6,
            offset: Offset(2, 4),
          ),
        ],
      ),
      titleLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: greenButton,
      ),
      bodyLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: greenButton,
      ),
      bodyMedium: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
        color: greenButton,
      ),
      bodySmall: TextStyle(
        fontSize: 16,
        color: greenButton,
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
        foregroundColor: greenButton,
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
      backgroundColor: lightMint,
      titleTextStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: greenButton,
        fontFamily: 'Nunito-Bold',
      ),
      contentTextStyle: const TextStyle(
        fontSize: 15,
        color: greenButton,
        fontFamily: 'Nunito',
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: greenButton, width: 4),
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
      color: color ?? greenButton,
      fontStyle: fontStyle,
    );
  }

  /// Décoration de fond par défaut (image en plein écran)
  static BoxDecoration backgroundDecoration() {
    return const BoxDecoration(
      image: DecorationImage(
        image: AssetImage(backgroundImage),
        fit: BoxFit.cover,
      ),
    );
  }

  /// Bouton personnalisé (ex: "Connexion", "Inscription", etc.)
  static Widget customButton({
    required String label,
    required VoidCallback? onPressed,
    Color? backgroundColor,
  }) {
    // Valeur par défaut
    final Color mainColor = backgroundColor ?? AppTheme.greenButton;

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
          // Couleur de fond par défaut
          backgroundColor: MaterialStateProperty.resolveWith<Color>(
            (states) {
              // État désactivé
              if (states.contains(MaterialState.disabled)) {
                // Couleur pour un bouton disabled
                return mainColor.withOpacity(0.5); 
              }
              // État pressé
              if (states.contains(MaterialState.pressed)) {
                // Couleur plus sombre ou plus claire selon ton goût
                return mainColor.withOpacity(0.7);
              }
              // État normal
              return mainColor;
            },
          ),
          foregroundColor: MaterialStateProperty.all<Color>(AppTheme.white),
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
                color: AppTheme.white,
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
      color: darkerGreen,
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
      color: darkerGreen,
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
      color: Colors.green[900],
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

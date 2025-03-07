import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ambrosia/screens/game_home_screen.dart';
import '../services/game_service.dart';
import '../styles/app_theme.dart';

class TutorialScreen extends StatefulWidget {
  final String gameId;
  final String playerId;
  final String playerName;
  final GameService gameService;

  const TutorialScreen({
    Key? key,
    required this.gameId,
    required this.playerId,
    required this.playerName,
    required this.gameService,
  }) : super(key: key);

  @override
  _TutorialScreenState createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  // Liste principale de dialogues.
  final List<Map<String, String>> dialogues = [
    {
      'speaker': 'Zeus',
      'text':
          'Bienvenue, mortels. Vous vous ennuyez et voulez jouer ? Très bien, moi aussi. Jouons ensemble.'
    },
    {
      'speaker': 'Zeus',
      'text':
          'Vous avez été plongé dans le Labyrinthe de Brume, et seul le plus valeureux d’entre vous en sortira.'
    },
    {
      'speaker': 'Héphaïstos',
      'text':
          'C’est moi qui ai conçu ce labyrinthe, et j’ai beaucoup de temps libre. Mais ne vous inquiétez pas, il y a plusieurs sorties.'
    },
    {
      'speaker': 'Zeus',
      'text':
          'C’est pourquoi trouver une sortie ne suffira pas, c’est bien trop facile. Il faudra prouver votre valeur et gagner de la Faveur Divine.'
    },
    {
      'speaker': 'Héra',
      'text':
          'Nous vous avons concocté de nombreuses épreuves de tout type, mortels. Vous devrez répondre à nos énigmes, combattre des monstres ou vous affronter entre vous.'
    },
    {
      'speaker': 'Zeus',
      'text':
          'Si vous avez suffisamment de Faveur Divine lorsque vous atteignez la sortie, vous gagnerez ce jeu et le droit de goûter à l’Ambroisie.'
    },
    {
      'speaker': 'Héra',
      'text':
          'Qui aura le privilège de goûter à l’Ambroisie et l’honneur de venir festoyer avec nous ? A vous de me le dire. Nous vous observerons de très près, bon courage.'
    }
  ];

  // Mapping pour le contenu additionnel (extra) qui doit défiler après certaines répliques.
  final Map<int, Map<String, dynamic>> extraContent = {
    1: {
      'text':
          "Vous pourrez vous déplacer d'une case par tour. Vous ne verrez que ce qu'il y a autour de vous.",
      'image': "assets/images/move_example.png",
    },
    3: {
      'text':
          "La faveur divine sera visible en haut à gauche de votre écran (icone ci-dessous), votre but est d'avoir été reconnu à juste valeur par les Dieux avant de trouver la sortie.",
      'image': "assets/images/FD2.png",
    },
    5: {
      'text':
          "Gagner le droit à l'Ambroisie mettra fin à la partie. Il n'y a qu'un seul gagnant.",
    },
  };

  int currentDialogueIndex = 0;
  String displayedText = "";
  Timer? _typewriterTimer;
  int _currentCharIndex = 0;
  bool typewriterCompleted = false;

  // Variables pour le contenu additionnel.
  String extraDisplayedText = "";
  Timer? _extraTypewriterTimer;
  int _extraCurrentCharIndex = 0;
  bool extraTypewriterCompleted = false;

  bool isFinished = false;
  bool isWaitingOthers = false;

  @override
  void initState() {
    super.initState();
    widget.gameService.socket.on('tutorialAllFinished', _onTutorialAllFinished);
    _startTypewriter();
  }

  @override
  void dispose() {
    widget.gameService.socket.off('tutorialAllFinished', _onTutorialAllFinished);
    _cancelTypewriterTimer();
    _cancelExtraTypewriterTimer();
    super.dispose();
  }

  void _cancelTypewriterTimer() {
    _typewriterTimer?.cancel();
    _typewriterTimer = null;
  }

  void _cancelExtraTypewriterTimer() {
    _extraTypewriterTimer?.cancel();
    _extraTypewriterTimer = null;
  }

  void _startTypewriter() {
    _cancelTypewriterTimer();
    setState(() {
      displayedText = "";
      _currentCharIndex = 0;
      typewriterCompleted = false;
    });
    final fullText = dialogues[currentDialogueIndex]['text']!;
    _typewriterTimer =
        Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_currentCharIndex < fullText.length) {
        setState(() {
          _currentCharIndex++;
          displayedText = fullText.substring(0, _currentCharIndex);
        });
      } else {
        _cancelTypewriterTimer();
        setState(() {
          typewriterCompleted = true;
          displayedText = fullText;
        });
      }
    });
  }

  void _startExtraTypewriter() {
    _cancelExtraTypewriterTimer();
    setState(() {
      extraDisplayedText = "";
      _extraCurrentCharIndex = 0;
      extraTypewriterCompleted = false;
    });
    final extraMap = extraContent[currentDialogueIndex];
    if (extraMap == null) return;
    final fullExtraText = extraMap['text'] as String;
    _extraTypewriterTimer =
        Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_extraCurrentCharIndex < fullExtraText.length) {
        setState(() {
          _extraCurrentCharIndex++;
          extraDisplayedText =
              fullExtraText.substring(0, _extraCurrentCharIndex).trim();
        });
      } else {
        _cancelExtraTypewriterTimer();
        setState(() {
          extraTypewriterCompleted = true;
          extraDisplayedText = fullExtraText.trim();
        });
      }
    });
  }

  void _advanceDialogue() {
    if (currentDialogueIndex < dialogues.length - 1) {
      setState(() {
        currentDialogueIndex++;
        extraDisplayedText = "";
        _extraCurrentCharIndex = 0;
        extraTypewriterCompleted = false;
      });
      _startTypewriter();
    }
  }

  void _finishTutorial() {
    setState(() {
      isFinished = true;
      isWaitingOthers = true;
    });
    widget.gameService.finishTutorial(widget.gameId, widget.playerId);
  }

  void _onTutorialAllFinished(data) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameHomeScreen(
          gameId: widget.gameId,
          playerName: widget.playerName,
          playerId: widget.playerId,
          gameService: widget.gameService,
          initialData: Map<String, dynamic>.from(data),
        ),
      ),
    );
  }

  String _getImageAsset(String speaker) {
    switch (speaker) {
      case 'Zeus':
        return 'assets/images/zeus_tuto.png';
      case 'Héra':
      case 'Hera':
        return 'assets/images/hera_tuto.png';
      case 'Héphaïstos':
        return 'assets/images/hephaistos_tuto.png';
      default:
        return 'assets/images/default_tuto.png';
    }
  }

  TextSpan _parseText(String text) {
    const boldKeywords = ["Labyrinthe de Brume", "Faveur Divine", "Ambroisie", "plusieurs sorties"];
    final List<_MatchInfo> matches = [];
    for (final keyword in boldKeywords) {
      final regExp = RegExp(RegExp.escape(keyword));
      for (final match in regExp.allMatches(text)) {
        matches.add(_MatchInfo(match.start, match.end));
      }
    }
    matches.sort((a, b) => a.start.compareTo(b.start));
    final List<TextSpan> spans = [];
    int currentIndex = 0;
    const normalStyle = TextStyle(
      fontSize: 18,
      color: AppTheme.primaryColor,
      height: 1.5,
    );
    final boldStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: AppTheme.boldRed,
      height: 1.5,
    );
    for (final match in matches) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(
            text: text.substring(currentIndex, match.start), style: normalStyle));
      }
      spans.add(TextSpan(
          text: text.substring(match.start, match.end), style: boldStyle));
      currentIndex = match.end;
    }
    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex), style: normalStyle));
    }
    return TextSpan(children: spans, style: normalStyle);
  }

  Widget _buildFormattedText(String text) {
    return RichText(
      textAlign: TextAlign.center,
      text: _parseText(text),
    );
  }

  void _handleScreenTap() {
    final fullText = dialogues[currentDialogueIndex]['text']!;
    if (!typewriterCompleted) {
      _cancelTypewriterTimer();
      setState(() {
        typewriterCompleted = true;
        displayedText = fullText;
      });
      return;
    }
    if (extraContent.containsKey(currentDialogueIndex)) {
      if (extraDisplayedText.isEmpty) {
        _startExtraTypewriter();
        return;
      } else if (!extraTypewriterCompleted) {
        _cancelExtraTypewriterTimer();
        final fullExtraText =
            extraContent[currentDialogueIndex]!['text'] as String;
        setState(() {
          extraTypewriterCompleted = true;
          extraDisplayedText = fullExtraText.trim();
        });
        return;
      } else {
        _advanceDialogue();
        return;
      }
    }
    _advanceDialogue();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth  = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bubbleWidth  = screenWidth * 0.8;
    final bubbleHeight = screenHeight * 0.17;
    final bubblePadding = EdgeInsets.only(
      left: screenWidth * 0.05,
      right: screenWidth * 0.05,
      top: screenHeight * 0.012,
      bottom: screenHeight * 0.03,
    );

    final currentDialogue = dialogues[currentDialogueIndex];
    final speaker       = currentDialogue['speaker']!;

    Widget extraWidget = const SizedBox.shrink();
    if (extraContent.containsKey(currentDialogueIndex)) {
      List<Widget> extraChildren = [];
      extraChildren.add(
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: 0.0),
          child: Text(
            extraDisplayedText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: AppTheme.textBlue),
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
          ),
        ),
      );
      if (extraContent[currentDialogueIndex]!['image'] != null && extraTypewriterCompleted) {
        extraChildren.add(
          Padding(
            // Ajout d'un petit padding vertical pour espacer l'image du texte extra.
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenHeight * 0.02),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: Image.asset(
                extraContent[currentDialogueIndex]!['image'],
                key: ValueKey(extraContent[currentDialogueIndex]!['image']),
                width: screenWidth * 0.3,
                height: screenHeight * 0.15,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      }
      extraWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: extraChildren,
      );
    }

    return Scaffold(
      body: GestureDetector(
        onTap: _handleScreenTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Container(decoration: AppTheme.backgroundDecoration()),
            SafeArea(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: screenHeight -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        SizedBox(height: screenHeight * 0.02),
                        Text(
                          "Tutoriel",
                          style: AppTheme.themeData.textTheme.displayLarge?.copyWith(
                            fontSize: screenWidth * 0.09,
                            color: AppTheme.accentYellow,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                        Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(opacity: animation, child: child),
                            child: Image.asset(
                              _getImageAsset(speaker),
                              key: ValueKey(speaker),
                              width: screenWidth * 0.5,
                              height: screenWidth * 0.5,
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.015),
                        Padding(
                          padding: bubblePadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                speaker,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.005),
                              SizedBox(
                                width: bubbleWidth,
                                height: bubbleHeight,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: SingleChildScrollView(
                                    physics: const NeverScrollableScrollPhysics(),
                                    child: _buildFormattedText(displayedText),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        extraWidget,
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Message fixe en bas de l'écran.
            Positioned(
              bottom: screenHeight * 0.03,
              left: 0,
              right: 0,
              child: Center(
                child: currentDialogueIndex < dialogues.length - 1
                    ? const Text(
                        "Cliquez sur l'écran pour continuer",
                        style: TextStyle(fontSize: 16, color: AppTheme.textBlue),
                      )
                    : (!isWaitingOthers
                        ? AppTheme.customButton(
                            label: "Commencer",
                            onPressed: _finishTutorial,
                          )
                        : const Text(
                            "Veuillez patienter, en attendant que tous les joueurs aient terminé le tutoriel.",
                            style: TextStyle(fontSize: 16, color: AppTheme.textBlue),
                            textAlign: TextAlign.center,
                          )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchInfo {
  final int start;
  final int end;
  _MatchInfo(this.start, this.end);
}

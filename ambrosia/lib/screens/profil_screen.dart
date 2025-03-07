import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../styles/app_theme.dart';
import 'collection_screen.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  _ProfilScreenState createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  final AuthService _authService = AuthService();

  bool isLoggedIn = false;
  Map<String, dynamic>? userProfile;

  // Champs pseudo / mail / mdp
  final TextEditingController _pseudoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    bool loggedIn = await _authService.isLoggedIn();
    setState(() => isLoggedIn = loggedIn);
    if (loggedIn) {
      final profile = await _authService.getProfile();
      setState(() => userProfile = profile);
    }
  }

  //-------------------------
  // Gestion d'erreurs
  //-------------------------
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) {
        return _CustomPositionedDialog(
          child: AlertDialog(
            title: const Text('Erreur'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }

  //-------------------------
  // Authentification
  //-------------------------
  Future<void> _login(String pseudo, String password) async {
    try {
      final result = await _authService.login(
        pseudo: pseudo.trim(),
        password: password.trim(),
      );
      if (result != null) {
        await _checkLoginStatus();
      }
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  Future<void> _register(String email, String pseudo, String password) async {
    try {
      final result = await _authService.register(
        email: email.trim(),
        pseudo: pseudo.trim(),
        password: password.trim(),
      );
      if (result != null) {
        await _checkLoginStatus();
      }
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    setState(() {
      isLoggedIn = false;
      userProfile = null;
    });
  }

  //-------------------------
  // Dialogues Connexion / Inscription
  //-------------------------
  Future<void> _showLoginDialog() async {
    _pseudoController.clear();
    _passwordController.clear();

    await showDialog(
      context: context,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        return MediaQuery(
          data: mq.copyWith(viewInsets: EdgeInsets.zero),
          child: _CustomPositionedDialog(
            child: AlertDialog(
              title: const Text('Connexion'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: _pseudoController,
                      decoration: const InputDecoration(
                        labelText: 'Pseudo',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _login(_pseudoController.text, _passwordController.text);
                  },
                  child: const Text('Se connecter'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRegisterDialog() async {
    _emailController.clear();
    _pseudoController.clear();
    _passwordController.clear();

    await showDialog(
      context: context,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        return MediaQuery(
          data: mq.copyWith(viewInsets: EdgeInsets.zero),
          child: _CustomPositionedDialog(
            child: AlertDialog(
              title: const Text('Inscription'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Mail',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _pseudoController,
                      decoration: const InputDecoration(
                        labelText: 'Pseudo',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _register(
                      _emailController.text,
                      _pseudoController.text,
                      _passwordController.text,
                    );
                  },
                  child: const Text("S'inscrire"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  //-------------------------
  // Édition du pseudo
  //-------------------------
  Future<void> _showEditPseudoDialog() async {
    // Pré-remplir le controller avec le pseudo actuel
    final currentPseudo = userProfile?['pseudo'] ?? '';
    _pseudoController.text = currentPseudo;

    await showDialog(
      context: context,
      builder: (ctx) {
        return _CustomPositionedDialog(
          child: AlertDialog(
            title: const Text('Modifier le pseudo'),
            content: TextField(
              controller: _pseudoController,
              decoration: const InputDecoration(
                labelText: 'Nouveau pseudo',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);

                  // Mise à jour du pseudo
                  final newPseudo = _pseudoController.text.trim();
                  final currentAvatar = userProfile?['avatarBase64'] ?? '';

                  try {
                    final success = await _authService.updateProfile(
                      newPseudo: newPseudo,
                      newAvatarBase64: currentAvatar,
                    );
                    if (success) {
                      await _checkLoginStatus();
                    }
                  } catch (e) {
                    _showErrorDialog(e.toString());
                  }
                },
                child: const Text('Valider'),
              ),
            ],
          ),
        );
      },
    );
  }

  //-------------------------
  // Sélecteur d'images
  //-------------------------
  Future<void> _showImagePickerOptions() async {
    showModalBottomSheet(
      backgroundColor: AppTheme.white,
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
                title: Text(
                  'Prendre une photo',
                  style: AppTheme.nunitoTextStyle(color: AppTheme.primaryColor),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
                title: Text(
                  'Choisir depuis la galerie',
                  style: AppTheme.nunitoTextStyle(color: AppTheme.primaryColor),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 300,
      maxHeight: 300,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // On récupère le pseudo actuel si on en a un
      final pseudo = userProfile?['pseudo'] ?? '';
      try {
        final success = await _authService.updateProfile(
          newPseudo: pseudo,
          newAvatarBase64: base64Image,
        );
        if (success) {
          await _checkLoginStatus();
        }
      } catch (e) {
        _showErrorDialog(e.toString());
      }
    }
  }

  //-------------------------
  // UI NON CONNECTÉ
  //-------------------------
  Widget _buildLoggedOutView(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Aucun profil',
          style: AppTheme.themeData.textTheme.displayLarge?.copyWith(
            fontSize: 36,
            color: AppTheme.accentYellow,
            fontWeight: FontWeight.w100
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        Image.asset(
          'assets/images/nain-profil.png',
          height: 180,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTheme.themeData.textTheme.bodyMedium?.copyWith(
                fontSize: 19,
                color: AppTheme.textBlue,
              ),
              children: [
                const TextSpan(text: "Vous n'êtes pas connecté.\n\n"),
                TextSpan(
                  text: "Vous n'êtes pas obligé d'avoir un profil pour jouer !",
                  style: AppTheme.nunitoTextStyle(bold: true),
                ),
                const TextSpan(
                  text:
                      "\n\nAvoir son propre profil permet cependant de collectionner "
                      "les cartes du labyrinthe et de retrouver chaque personnage rencontré précédemment "
                      "à tout moment dans l'onglet collection.",
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: AppTheme.customButton(
                  label: 'Connexion',
                  onPressed: _showLoginDialog,
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: AppTheme.customButton(
                  label: 'Inscription',
                  onPressed: _showRegisterDialog,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => _CustomPositionedDialog(
                child: AlertDialog(
                  title: const Text('Mot de passe oublié ?'),
                  content: const Text('Fonctionnalité en cours de développement...'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
            );
          },
          child: Text(
            'Mot de passe oublié ?',
            style: AppTheme.themeData.textTheme.bodyMedium?.copyWith(
              decoration: TextDecoration.underline,
              fontStyle: FontStyle.italic,
              fontSize: 18,
              color: AppTheme.textBlue,
            ),
          ),
        ),
      ],
    );
  }

  //-------------------------
  // UI CONNECTÉ
  //-------------------------
  Widget _buildLoggedInView(BuildContext context) {
    final avatarBase64 = userProfile?['avatarBase64'] as String? ?? '';
    final userEmail = userProfile?['email'] ?? '';
    final userPseudo = userProfile?['pseudo'] ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Mon profil',
          style: AppTheme.themeData.textTheme.displayLarge?.copyWith(
            fontSize: 36,
            color: AppTheme.accentYellow,
            fontWeight: FontWeight.w100
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // =============== AVATAR ===============
        GestureDetector(
          onTap: _showImagePickerOptions,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 80,
                backgroundColor: AppTheme.primaryColor,
                backgroundImage: avatarBase64.isNotEmpty
                    ? MemoryImage(base64Decode(avatarBase64))
                    : null,
                child: avatarBase64.isEmpty
                    ? const Icon(
                        Icons.camera_alt,
                        size: 100,
                        color: AppTheme.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        // ============ MES INFORMATIONS ============
        Text(
          "Mes informations :",
          style: AppTheme.themeData.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),

        // --- ESPACE VERTICAL
        const SizedBox(height: 12),

        // 1ÈRE LIGNE : MAIL
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Row(
            children: [
              Text(
                'Mail : ',
                style: AppTheme.themeData.textTheme.bodyMedium,
              ),
              const SizedBox(width: 6),
              Text(
                userEmail,
                style: AppTheme.themeData.textTheme.bodyMedium,
              ),
            ],
          ),
        ),

        // --- ESPACE ENTRE MAIL ET PSEUDO
        const SizedBox(height: 4),

        // 2E LIGNE : PSEUDO
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Row(
            children: [
              Text(
                'Pseudo : ',
                style: AppTheme.themeData.textTheme.bodyMedium,
              ),
              const SizedBox(width: 6),
              Text(
                userPseudo,
                style: AppTheme.themeData.textTheme.bodyMedium,
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                color: AppTheme.primaryColor,
                tooltip: "Modifier le pseudo",
                onPressed: _showEditPseudoDialog,
              ),
            ],
          ),
        ),
        // --- FIN MES INFORMATIONS
        const SizedBox(height: 25),

        // TEXTE SUR LA COLLECTION
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTheme.themeData.textTheme.bodyMedium?.copyWith(
                fontSize: 20,
                color: AppTheme.primaryColor,
              ),
              children: const [
                TextSpan(
                  text:
                      "Chaque personnage ou évènement rencontré pendant une partie est "
                      "consigné et consultable dans l'onglet \"Collection\".\n\n",
                ),
                TextSpan(
                  text:
                      "Certains personnages sont plus rares à croiser que d'autres. "
                      "Parviendrez-vous à découvrir l'entièreté du labyrinthe de brume et lever le voile "
                      "sur ses mystères au fil des parties ?",
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: AppTheme.customButton(
                  label: 'Collection',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CollectionScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: AppTheme.customButton(
                  label: 'Déconnexion',
                  backgroundColor: AppTheme.incorrectRed,
                  onPressed: _logout,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  //-------------------------
  // BUILD
  //-------------------------
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Fond
          Container(
            decoration: AppTheme.backgroundDecoration(),
          ),
          // Contenu
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  top: screenHeight * 0.05,
                  bottom: 40,
                ),
                child: isLoggedIn
                    ? _buildLoggedInView(context)
                    : _buildLoggedOutView(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Petit widget qui déplace AlertDialog plus haut, pour version Flutter < 3.7.
class _CustomPositionedDialog extends StatelessWidget {
  final Widget child;
  const _CustomPositionedDialog({Key? key, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -100),
      child: child,
    );
  }
}

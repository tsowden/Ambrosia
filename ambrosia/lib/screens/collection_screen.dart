// lib/screens/collection_screen.dart
import 'package:flutter/material.dart';
import '../styles/app_theme.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection'),
        backgroundColor: AppTheme.primaryColor,
        // La flèche de retour est gardée pour la navigation mais rendue invisible
        iconTheme: const IconThemeData(color: Colors.transparent),
      ),
      body: Container(
        decoration: AppTheme.backgroundDecoration(),
        child: ListView.builder(
          itemCount: 10, // Exemple : 10 éléments dans la collection
          itemBuilder: (context, index) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.collections, color: AppTheme.primaryColor),
                title: Text(
                  'Item ${index + 1}',
                  style: AppTheme.themeData.textTheme.bodyMedium,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, color: AppTheme.primaryColor),
                onTap: () {
                  // Action lors du tap sur un item (à personnaliser)
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

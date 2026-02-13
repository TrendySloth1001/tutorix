import 'package:flutter/material.dart';
import '../models/user_model.dart';

class ProfileScreen extends StatelessWidget {
  final UserModel user;
  final VoidCallback onLogout;

  const ProfileScreen({super.key, required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: onLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              if (user.picture != null)
                CircleAvatar(
                  radius: 60,
                  backgroundImage: NetworkImage(user.picture!),
                  backgroundColor: Colors.grey[200],
                )
              else
                const CircleAvatar(
                  radius: 60,
                  child: Icon(Icons.person, size: 60),
                ),
              const SizedBox(height: 20),
              Text(
                user.name ?? 'No Name',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(user.email, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.settings_rounded,
                  color: Colors.deepPurple,
                ),
                title: const Text('Settings'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(
                  Icons.help_outline_rounded,
                  color: Colors.deepPurple,
                ),
                title: const Text('Help & Support'),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

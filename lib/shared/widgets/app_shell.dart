import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, required this.path, super.key});
  final Widget child;
  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: child,
    bottomNavigationBar: NavigationBar(
      selectedIndex: path.startsWith('/training')
          ? 1
          : path.startsWith('/measurements')
          ? 2
          : path.startsWith('/progress')
          ? 3
          : path.startsWith('/profile')
          ? 4
          : 0,
      onDestinationSelected: (index) => context.goNamed(
        ['home', 'training', 'measurements', 'progress', 'profile'][index],
      ),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.fitness_center),
          label: 'Treinos',
        ),
        NavigationDestination(icon: Icon(Icons.straighten), label: 'Medidas'),
        NavigationDestination(icon: Icon(Icons.show_chart), label: 'Evolucao'),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
    ),
  );
}

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import '../../routes/app_router.dart';

class HomeModule extends Module {
  @override
  void binds(Binder i) {}
}

@RoutePage()
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ModuleScope(
      module: HomeModule(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: ListView.builder(
          itemCount: 5,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text('Item $index'),
              onTap: () => context.router.push(DetailsRoute(id: '$index')),
            );
          },
        ),
      ),
    );
  }
}

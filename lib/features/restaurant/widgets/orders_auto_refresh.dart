import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/restaurant_orders_cubit.dart';

/// Relit les commandes du service à intervalle régulier tant que l'écran
/// enveloppé est affiché.
///
/// Un écran de cuisine ou de salle reste ouvert des heures sans qu'on y
/// touche : sans relecture, il ne voyait jamais les commandes ouvertes,
/// complétées ou réglées sur les autres postes.
class RestaurantOrdersAutoRefresh extends StatefulWidget {
  const RestaurantOrdersAutoRefresh({
    super.key,
    required this.child,
    this.intervalle = const Duration(seconds: 20),
  });

  final Widget child;
  final Duration intervalle;

  @override
  State<RestaurantOrdersAutoRefresh> createState() =>
      _RestaurantOrdersAutoRefreshState();
}

class _RestaurantOrdersAutoRefreshState
    extends State<RestaurantOrdersAutoRefresh> {
  Timer? _minuterie;

  @override
  void initState() {
    super.initState();
    _relire();
    _minuterie = Timer.periodic(widget.intervalle, (_) => _relire());
  }

  void _relire() {
    if (!mounted) return;
    context.read<RestaurantOrdersCubit>().load();
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

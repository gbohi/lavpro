import 'package:flutter/material.dart';

/// Traduit les noms d'icônes paramétrés dans le back-office (Material Symbols) en IconData Flutter.
const _icons = <String, IconData>{
  'directions_car': Icons.directions_car_rounded,
  'car': Icons.directions_car_rounded,
  'airport_shuttle': Icons.airport_shuttle_rounded,
  'two_wheeler': Icons.two_wheeler_rounded,
  'local_shipping': Icons.local_shipping_rounded,
  'fire_truck': Icons.fire_truck_rounded,
  'agriculture': Icons.agriculture_rounded,
  'directions_bus': Icons.directions_bus_rounded,
  'electric_car': Icons.electric_car_rounded,
  'rv_hookup': Icons.rv_hookup_rounded,
  'pedal_bike': Icons.pedal_bike_rounded,
  'local_car_wash': Icons.local_car_wash_rounded,
  'auto_awesome': Icons.auto_awesome_rounded,
  'settings': Icons.settings_rounded,
  'eco': Icons.eco_rounded,
  'water': Icons.water_rounded,
  'water_drop': Icons.water_drop_rounded,
  'waves': Icons.waves_rounded,
  'public': Icons.public_rounded,
  'cleaning_services': Icons.cleaning_services_rounded,
  'dry_cleaning': Icons.dry_cleaning_rounded,
  'tire_repair': Icons.tire_repair_rounded,
  'airline_seat_recline_extra': Icons.airline_seat_recline_extra_rounded,
  'wash': Icons.wash_rounded,
  'bubble_chart': Icons.bubble_chart_rounded,
  'star': Icons.star_rounded,
  'shower': Icons.shower_rounded,
  'local_drink': Icons.local_drink_rounded,
  // catégories de récompenses
  'fragrance': Icons.air_rounded,
  'mat': Icons.dashboard_rounded,
  'oil': Icons.oil_barrel_rounded,
  'discount': Icons.percent_rounded,
  'gift': Icons.redeem_rounded,
};

IconData iconFor(String? name, {IconData fallback = Icons.local_car_wash_rounded}) =>
    _icons[name] ?? fallback;

IconData rewardIcon(String category) => switch (category) {
      'wash' => Icons.local_car_wash_rounded,
      'eco' => Icons.eco_rounded,
      _ => iconFor(category, fallback: Icons.redeem_rounded),
    };

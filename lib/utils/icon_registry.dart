import 'package:flutter/material.dart';

/// Wspólny rejestr nazw ikon Material → obiektów `IconData`.
///
/// Używany przez ekrany ładujące ikony z `trip.json` (np. kategorie rozmówek,
/// wąwozy, w przyszłości inne sekcje). Pozwala odzwierciedlać `Icons.xxx` 1:1
/// w JSON — klucz mapy to nazwa atrybutu z `Icons.*`.
///
/// Aby dodać nową ikonę: wpisz pozycję poniżej (klucz = nazwa, wartość =
/// `Icons.<name>`). Plik mapy jest świadomie centralizowany w jednym miejscu,
/// żeby wszystkie ekrany apki ładujące ikony z JSON-a miały wspólny słownik.
const Map<String, IconData> kIconRegistry = <String, IconData>{
  // Rozmówki — kategorie sytuacji
  'waving_hand_outlined': Icons.waving_hand_outlined,
  'hotel_outlined': Icons.hotel_outlined,
  'restaurant_menu': Icons.restaurant_menu,
  'shopping_basket_outlined': Icons.shopping_basket_outlined,
  'local_gas_station_outlined': Icons.local_gas_station_outlined,
  'directions_outlined': Icons.directions_outlined,
  'car_repair_outlined': Icons.car_repair_outlined,
  'medical_services_outlined': Icons.medical_services_outlined,
  'warning_amber_outlined': Icons.warning_amber_outlined,
  'chat_bubble_outline': Icons.chat_bubble_outline,
  'flight_outlined': Icons.flight_outlined,
  'beach_access_outlined': Icons.beach_access_outlined,
  'pool_outlined': Icons.pool_outlined,
  'directions_bus_outlined': Icons.directions_bus_outlined,
  'train_outlined': Icons.train_outlined,
  'attach_money': Icons.attach_money,
  'translate': Icons.translate,

  // Wąwozy / przyroda
  'water_drop_outlined': Icons.water_drop_outlined,
  'water_outlined': Icons.water_outlined,
  'water': Icons.water,
  'forest_outlined': Icons.forest_outlined,
  'park_outlined': Icons.park_outlined,
  'terrain': Icons.terrain,
  'hiking': Icons.hiking,
  'landscape': Icons.landscape,
};

/// Resolwer ikony — przyjmuje nazwę z JSON i zwraca `IconData`.
/// Gdy nazwy brak w rejestrze, zwraca podaną domyślną ikonę.
IconData resolveIcon(String? name, {IconData fallback = Icons.label_outline}) {
  if (name == null) return fallback;
  return kIconRegistry[name] ?? fallback;
}

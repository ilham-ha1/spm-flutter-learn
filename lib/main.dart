import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Offline dummy data. No network, no DB — the point of this app is the
// iOS build plumbing (SPM), not the Dart side.
const coffees = [
  (id: 'espresso', name: 'Espresso', origin: 'Aceh Gayo', price: 18000),
  (id: 'latte', name: 'Caffe Latte', origin: 'Toraja', price: 28000),
  (id: 'v60', name: 'V60 Pour Over', origin: 'Kintamani', price: 32000),
  (id: 'kopi-susu', name: 'Es Kopi Susu', origin: 'Flores Bajawa', price: 22000),
  (id: 'cold-brew', name: 'Cold Brew', origin: 'Java Preanger', price: 30000),
  (id: 'tubruk', name: 'Kopi Tubruk', origin: 'Lampung', price: 12000),
];

void main() => runApp(const MaterialApp(home: CoffeeList()));

class CoffeeList extends StatefulWidget {
  const CoffeeList({super.key});

  @override
  State<CoffeeList> createState() => _CoffeeListState();
}

class _CoffeeListState extends State<CoffeeList> {
  // shared_preferences is the native plugin here: on iOS it ships a
  // Package.swift, so Flutter resolves it through Swift Package Manager.
  final prefs = SharedPreferencesAsync();
  Set<String> favorites = {};

  @override
  void initState() {
    super.initState();
    prefs.getStringList('favorites').then((v) => setState(() => favorites = {...?v}));
  }

  Future<void> toggle(String id) async {
    setState(() => favorites.contains(id) ? favorites.remove(id) : favorites.add(id));
    await prefs.setStringList('favorites', favorites.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Coffee menu (${favorites.length} fav)')),
      body: ListView(
        children: [
          for (final c in coffees)
            ListTile(
              title: Text(c.name),
              subtitle: Text('${c.origin} · Rp${c.price}'),
              trailing: IconButton(
                icon: Icon(favorites.contains(c.id) ? Icons.favorite : Icons.favorite_border),
                onPressed: () => toggle(c.id),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/building_config.dart';

class DestinationSearchPage extends StatefulWidget {
  final BuildingConfig config;

  const DestinationSearchPage({
    super.key,
    required this.config,
  });

  @override
  State<DestinationSearchPage> createState() =>
      _DestinationSearchPageState();
}

class _DestinationSearchPageState
    extends State<DestinationSearchPage> {
  final TextEditingController _searchController =
      TextEditingController();

  String searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = widget.config.rooms.where((room) {
      return room.name
          .toLowerCase()
          .contains(searchText.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Destination'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  searchText = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search room or destination',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchText.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();

                          setState(() {
                            searchText = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          Expanded(
            child: rooms.isEmpty
                ? const Center(
                    child: Text('No destination found'),
                  )
                : ListView.builder(
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      final room = rooms[index];

                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.location_on),
                        ),
                        title: Text(room.name),
                        subtitle: Text(room.id),
                        trailing:
                            const Icon(Icons.chevron_right),
                        onTap: () {
  Navigator.pop(context, room);
},
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
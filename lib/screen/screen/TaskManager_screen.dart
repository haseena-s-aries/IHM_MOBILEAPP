import 'package:Auras/model/certificatedto.dart';
import 'package:Auras/screen/screen/certificate_details_screen.dart';

import 'package:Auras/service/api_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TaskManagerScreen extends StatefulWidget {
  const TaskManagerScreen({super.key});

  @override
  State<TaskManagerScreen> createState() => _TaskManagerScreenState();
}

class PagedCertificateResult {
  final List<CertificateDto> data;
  final int totalCount;

  PagedCertificateResult({required this.data, required this.totalCount});
}

class _TaskManagerScreenState extends State<TaskManagerScreen> {
  String _selectedType = 'towage';
  List<CertificateDto> _certificates = [];
  bool _isLoading = true;
  int _page = 1;
  int _totalPages = 1;
  final int _pageSize = 10;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCertificates();
  }

  Future<void> _fetchCertificates() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.fetchCertificatesPaged(
        type: _selectedType,
        page: _page,
        search: _searchQuery,
        pageSize: _pageSize,
      );
      setState(() {
        _certificates = response.data;
        _totalPages = (response.totalCount / _pageSize).ceil();
      });
    } catch (e) {
      print("❌ Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load certificates")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleSearch() {
    setState(() {
      _searchQuery = _searchController.text.trim();
      _page = 1;
    });
    _fetchCertificates();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Task Manager"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          // 🔍 Dropdown and Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                // Dropdown
                DropdownButton<String>(
                  value: _selectedType,
                  items: const [
                    DropdownMenuItem(value: 'towage', child: Text("Towage")),
                    DropdownMenuItem(
                      value: 'seafastening',
                      child: Text("Sea Fastening"),
                    ),
                    DropdownMenuItem(value: 'loadout', child: Text("Loadout")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                      _page = 1;
                    });
                    _fetchCertificates();
                  },
                ),
                const SizedBox(width: 10),
                // Search Field + Button
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by project or client...',
                            // prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onSubmitted: (_) => _handleSearch(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _handleSearch,
                        child: const Icon(Icons.search),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 🔄 List or Loader
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _certificates.isEmpty
                ? const Center(child: Text("No certificates found."))
                : ListView.builder(
                    itemCount: _certificates.length,
                    itemBuilder: (context, index) {
                      final cert = _certificates[index];
                      return ListTile(
                        title: Text(cert.projectTitle),
                        subtitle: Text("Client: ${cert.clientName}"),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.remove_red_eye,
                            color: Colors.deepPurple,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CertificateDetailsScreen(certificate: cert),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),

          // ⏪⏩ Pagination
          if (_totalPages > 1)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _page > 1
                        ? () {
                            setState(() => _page--);
                            _fetchCertificates();
                          }
                        : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Previous"),
                  ),
                  Text("Page $_page of $_totalPages"),
                  ElevatedButton.icon(
                    onPressed: _page < _totalPages
                        ? () {
                            setState(() => _page++);
                            _fetchCertificates();
                          }
                        : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text("Next"),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

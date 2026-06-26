// import 'package:flutter/material.dart';
// import '../db/database_helper.dart';

// class LocalCertificateScreen extends StatefulWidget {
//   const LocalCertificateScreen({super.key});

//   @override
//   State<LocalCertificateScreen> createState() => _LocalCertificateScreenState();
// }

// class _LocalCertificateScreenState extends State<LocalCertificateScreen> {
//   final dbHelper = DatabaseHelper();
//   List<Map<String, dynamic>> _certList = [];

//   final TextEditingController _titleController = TextEditingController();
//   final TextEditingController _typeController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     _loadCertificates();
//   }

//   void _loadCertificates() async {
//     final data = await dbHelper.getTowageCertificates();
//     setState(() => _certList = data);
//   }

//   void _addCertificate() async {
//     await dbHelper.insertTowageCertificate({
//       'title': _titleController.text,
//       'type': _typeController.text,
//       'createdAt': DateTime.now().toIso8601String(),
//     });
//     _titleController.clear();
//     _typeController.clear();
//     _loadCertificates();
//   }

//   void _delete(int id) async {
//     await dbHelper.deleteTowageCertificate(id);
//     _loadCertificates();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Offline Certificates')),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(12),
//             child: Column(
//               children: [
//                 TextField(
//                   controller: _titleController,
//                   decoration: const InputDecoration(labelText: 'Title'),
//                 ),
//                 TextField(
//                   controller: _typeController,
//                   decoration: const InputDecoration(labelText: 'Type'),
//                 ),
//                 ElevatedButton(
//                   onPressed: _addCertificate,
//                   child: const Text('Add'),
//                 ),
//               ],
//             ),
//           ),
//           const Divider(),
//           Expanded(
//             child: ListView.builder(
//               itemCount: _certList.length,
//               itemBuilder: (_, i) {
//                 final item = _certList[i];
//                 return ListTile(
//                   title: Text(item['title']),
//                   subtitle: Text(item['type']),
//                   trailing: IconButton(
//                     icon: const Icon(Icons.delete),
//                     onPressed: () => _delete(item['id']),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

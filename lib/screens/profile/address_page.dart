import 'package:flutter/material.dart';
import 'package:wastefood/services/firestore_service.dart';
import 'package:wastefood/models/address.dart';
import 'package:wastefood/screens/profile/add_address_page.dart';

class AddressPage extends StatefulWidget {
  const AddressPage({super.key});

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Address> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final addresses = await _firestoreService.getUserAddresses();
      if (mounted) {
        setState(() {
          _addresses = addresses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _addresses = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2E7D32); // hijau elegan (Colors.green[800])
    final lightGreen = Colors.green[50];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Alamat Saya",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: green))
              : _addresses.isEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Belum ada alamat tersimpan",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddAddressPage(),
                            ),
                          ).then((_) => _loadAddresses());
                        },
                        icon: const Icon(
                          Icons.add_location_alt,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "Tambah Alamat Baru",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : RefreshIndicator(
                color: green,
                onRefresh: _loadAddresses,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  itemCount: _addresses.length,
                  itemBuilder: (context, index) {
                    final address = _addresses[index];
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Card(
                        elevation: 4,
                        shadowColor: Colors.black.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: green.withValues(alpha: 0.1),
                            child: const Icon(Icons.home_rounded, color: green),
                          ),
                          title: Text(
                            address.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  address.streetAddress,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                Text(
                                  "${address.city}, ${address.province}, ${address.postalCode}",
                                  style: const TextStyle(fontSize: 13),
                                ),
                                Text(
                                  "📞 ${address.phoneNumber}",
                                  style: const TextStyle(fontSize: 13),
                                ),
                                if (address.isPrimary)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: lightGreen,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: green),
                                      ),
                                      child: const Text(
                                        "Alamat Utama",
                                        style: TextStyle(
                                          color: green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: green),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) =>
                                              AddAddressPage(address: address),
                                    ),
                                  ).then((_) => _loadAddresses());
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder:
                                        (ctx) => AlertDialog(
                                          title: const Text("Hapus Alamat"),
                                          content: const Text(
                                            "Yakin ingin menghapus alamat ini?",
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () =>
                                                      Navigator.pop(ctx, false),
                                              child: const Text("Batal"),
                                            ),
                                            ElevatedButton(
                                              onPressed:
                                                  () =>
                                                      Navigator.pop(ctx, true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.redAccent,
                                              ),
                                              child: const Text("Hapus"),
                                            ),
                                          ],
                                        ),
                                  );
                                  if (confirm == true) {
                                    await _firestoreService.deleteAddress(
                                      address,
                                    );
                                    _loadAddresses();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddAddressPage()),
          ).then((_) => _loadAddresses());
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Tambah Alamat",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: green,
        elevation: 6,
      ),
    );
  }
}

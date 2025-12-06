import 'package:flutter/material.dart';
import 'package:wastefood/models/address.dart';
import 'package:wastefood/services/firestore_service.dart';

class AddressSelectPage extends StatefulWidget {
  const AddressSelectPage({super.key});

  @override
  State<AddressSelectPage> createState() => _AddressSelectPageState();
}

class _AddressSelectPageState extends State<AddressSelectPage> {
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Select Delivery Address",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _addresses.isEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 72,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "No saved addresses found",
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
                          Navigator.pushNamed(context, '/address-add').then((
                            value,
                          ) {
                            if (value == true) {
                              _loadAddresses();
                            }
                          });
                        },
                        icon: const Icon(
                          Icons.add_location_alt,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "Add New Address",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
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
                            backgroundColor: Colors.green[100],
                            child: Icon(
                              Icons.location_on,
                              color: Colors.green[700],
                            ),
                          ),
                          title: Text(
                            address.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${address.streetAddress}, ${address.district}",
                                  style: const TextStyle(fontSize: 13),
                                ),
                                Text(
                                  "${address.city}, ${address.province}, ${address.postalCode}",
                                  style: const TextStyle(fontSize: 13),
                                ),
                                Text(
                                  "Phone: ${address.phoneNumber}",
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
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.green.shade400,
                                        ),
                                      ),
                                      child: const Text(
                                        "Primary Address",
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                          ),
                          onTap: () {
                            Navigator.pop(context, address);
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/address-add').then((value) {
            if (value == true) {
              _loadAddresses();
            }
          });
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Add Address",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green[700],
        elevation: 6,
      ),
    );
  }
}

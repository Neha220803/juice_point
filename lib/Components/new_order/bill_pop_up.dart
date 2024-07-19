// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:juice_point/Functions/calculate_item_cost.dart';
import 'package:juice_point/utils/constants.dart';

class BillPopUp extends StatefulWidget {
  final Map<String, int> itemCounts;
  final BuildContext context;
  const BillPopUp({super.key, required this.itemCounts, required this.context});

  @override
  State<BillPopUp> createState() => _BillPopUpState();
}

class _BillPopUpState extends State<BillPopUp> {
  String? _selectedItem2;
  final CollectionReference _history =
      FirebaseFirestore.instance.collection('history');
  int curNum = 0;
  int totalAmount = 0;
  final CollectionReference _menu =
      FirebaseFirestore.instance.collection('menu');
  //List<String> _selectedItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _updateTotalAmount();
  }

  Future<void> incOrderNo() async {
    QuerySnapshot snapshot = await _history.get();
    curNum = snapshot.docs.length;
    curNum++;
    print("Current order number: $curNum");
  }

  Future<int> calculateTotal(Map<String, int> itemCounts) async {
    int totalAmount = 0;
    for (String item in itemCounts.keys) {
      QuerySnapshot querySnapshot =
          await _menu.where('name', isEqualTo: item).limit(1).get();
      if (querySnapshot.docs.isNotEmpty) {
        var data = querySnapshot.docs.first.data() as Map<String, dynamic>;
        var cost = data['cost'];
        totalAmount += (cost is int)
            ? cost * itemCounts[item]!
            : (cost as double).toInt() * itemCounts[item]!.toInt();
      }
    }
    print("Total amount calculated: $totalAmount");
    return totalAmount;
  }

  Future<int> _updateTotalAmount() async {
    totalAmount = await calculateTotal(widget.itemCounts);
    if (mounted) {
      setState(() {
        totalAmount = totalAmount;
      });
    }
    return totalAmount;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        "Order Details",
        textAlign: TextAlign.center,
        style: TextStyle(
          color: primaryColor,
          fontSize: 24,
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(
              color: primaryColor,
            ),
            DataTable(
              columns: const [
                DataColumn(
                  label: Text("Item"),
                ),
                DataColumn(
                    label: Text(
                  "No.",
                )),
                DataColumn(label: Text("Cost")),
              ],
              rows: widget.itemCounts.entries.map((entry) {
                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        // color: Colors.amber,
                        width: 80,
                        child: Text(
                          entry.key,
                          textAlign: TextAlign.center,
                          maxLines: null, // Allow multiple lines
                        ),
                      ),
                    ),
                    DataCell(Text(entry.value.toString())),
                    DataCell(FutureBuilder<int>(
                      future: calculateItemCost(entry.key),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return const Text("Error");
                        } else {
                          return Text(
                              textAlign: TextAlign.center,
                              '₹ ${widget.itemCounts[entry.key]! * snapshot.data!.toInt()}\n(${entry.value.toString()}×${snapshot.data.toString()})');
                        }
                      },
                    )),
                  ],
                );
              }).toList(),
            ),
            const Divider(),
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: primaryColor, width: 2.5),
                // Example border color
              ),
              child: DropdownButton<String>(
                hint: const Text('Select a Payment Method'),
                value: _selectedItem2,
                onChanged: (String? newValue) async {
                  print("Selected payment method: $newValue");
                  int neww = await _updateTotalAmount();
                  setState(() {
                    _selectedItem2 = newValue;
                    totalAmount = neww;
                  });
                },
                items: <String>['G-Pay', 'Cash']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                underline: Container(),
              ),
            ),
            const Divider(),
            const Text(
              "Order Summary",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: black,
              ),
            ),
            Text(
              "Total Items: ${widget.itemCounts.values.reduce((sum, element) => sum + element)}",
              style: const TextStyle(
                fontSize: 16, // Adjust font size as needed
                color: black, // Set text color
              ),
            ),
            Text(
              "Total Amount to Pay: $totalAmount",
              style: const TextStyle(
                fontSize: 16, // Adjust font size as needed
                color: black, // Set text color
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                backgroundColor: secondaryColor,
                foregroundColor: black,
                fixedSize: const Size(340, 50),
              ),
              onPressed: _selectedItem2 == null || _isLoading
                  ? null
                  : () async {
                      setState(() {
                        _isLoading = true;
                      });
                      print("Submitting order...");
                      var now = DateTime.now();
                      await incOrderNo();

                      // Create a list to store the items and their counts
                      List<Map<String, dynamic>> itemsList = [];
                      widget.itemCounts.forEach((itemName, itemCount) {
                        itemsList.add({
                          'name': itemName,
                          'count': itemCount,
                        });
                      });

                      // Add order details to the history collection
                      await _history.add({
                        'amount': totalAmount,
                        'mode': _selectedItem2,
                        'order_no': curNum,
                        'time-stamp': now,
                        'items': itemsList,
                      });

                      // Close the dialog
                      if (mounted) {
                        Navigator.pop(context);
                      }
                      print("Order submitted successfully.");
                    },
              child: _isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(black),
                    )
                  : const Text('Submit',
                      style: TextStyle(
                        color: black,
                        fontSize: 20,
                        fontFamily: 'Open Sans',
                        fontWeight: FontWeight.w600,
                        height: 0,
                      )),
            ),
          ],
        ),
      ),
    );
  }
}

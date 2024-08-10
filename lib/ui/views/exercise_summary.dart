import 'dart:async';

import 'package:colour/colour.dart';
import 'package:flutter/material.dart';
import 'package:gainz_ai/ui/views/exerciseScreen.dart';

class ExerciseSummary extends StatelessWidget {
  final int reps;
  final String time;
  const ExerciseSummary({super.key, required this.reps, required this.time});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                "lib/Assets/jumping-jack.png",
                width: 150,
                height: 150,
              ),
              const Text(
                "Exercise Summary",
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20), // Add some space before the table
              Table(
                border: TableBorder.all(color: Colors.grey),
                // Optional: Add borders to the table
                children: [
                   TableRow(
                    decoration: const BoxDecoration(color: Colors.greenAccent),
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Total Reps',
                            style: TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text("$reps",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                  TableRow(
                    decoration: const BoxDecoration(color: Colors.white),
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Duration',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(time,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(
                height: 50,
              ),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ExerciseScreen()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                    ),
                    child: const Text(
                      "Start Again",
                      style: TextStyle(color: Colors.white),
                    ),
                  ))
            ],
          ),
        ),
      ),
    );
  }
}

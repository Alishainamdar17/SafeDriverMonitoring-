(Get-Content main.dart) -replace 'children: \[
                  FloatingActionButton\(
                    mini: true,
                    backgroundColor: Colors\.grey\[900\],
                    child: const Icon\(Icons\.history, color: Colors\.white\),
                    onPressed: \(\) \{
                      Navigator\.push\(
                        context,
                        MaterialPageRoute\(builder: \(context\) => const DriveListPage\(\)\),
                      \);
                    \},
                  \),', 'children: [
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.grey[900],
                    child: const Icon(Icons.analytics, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AnalyticsPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.grey[900],
                    child: const Icon(Icons.history, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DriveListPage()),
                      );
                    },
                  ),' | Set-Content main.dart

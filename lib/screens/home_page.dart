import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/scenario_service.dart';
import '../services/ml_prediction_service.dart';
import 'map_screen.dart';
import 'situation_screen.dart';
import 'checklist_screen.dart';
import 'handbook_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  bool _isCheckingScenario = true;
  bool _stormActive = false;

  final List<Widget> _screens = const [
    MapScreen(),
    SituationScreen(),
    ChecklistScreen(),
    HandbookScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Ensure _currentIndex is within valid range
    if (_currentIndex >= _screens.length) {
      _currentIndex = 0;
    }
    _checkForStormScenario();
  }

  Future<void> _checkForStormScenario() async {
    if (!mounted) return;
    
    setState(() => _isCheckingScenario = true);

    try {
      // Check if there's an active storm scenario on the server
      // This is optional - app works fine without the server
      final status = await ScenarioService.checkScenarioStatus();

      if (!mounted) return;

      if (status.active) {
        setState(() => _stormActive = true);

        // Initialize ML models when storm is detected
        print('🌪️ Storm scenario detected: ${status.scenario}');
        final mlInitialized = await MLPredictionService.initialize();

        if (mlInitialized && mounted) {
          // Show storm alert dialog after a short delay to ensure widget is built
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            _showStormAlert(status);
          }
        }
      } else {
        // No active storm - this is normal operation
        print('✅ No active storm scenario');
      }
    } catch (e) {
      print('Scenario check skipped: $e');
      // Silently continue - app works without scenario server
    } finally {
      if (mounted) {
        setState(() => _isCheckingScenario = false);
      }
    }
  }

  void _showStormAlert(ScenarioStatus status) {
    if (!mounted) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
        title: const Text('⚠️ Storm Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status.scenario ?? 'Severe Weather',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(status.message),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🤖 ML Models Activated',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Flood prediction models are now running to assess risk in your area.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('UNDERSTOOD'),
          ),
        ],
      ),
    );
    });
  }

  @override
  void dispose() {
    // Clean up ML models when leaving the app
    if (_stormActive) {
      MLPredictionService.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Clamp the current index to valid range
    final validIndex = _currentIndex.clamp(0, _screens.length - 1);
    
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: validIndex, children: _screens),
          
          // Show loading indicator while checking scenario
          if (_isCheckingScenario)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Checking for weather alerts...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Storm indicator badge
          if (_stormActive && !_isCheckingScenario)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'STORM ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BantayBottomNavBar(
        currentIndex: validIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

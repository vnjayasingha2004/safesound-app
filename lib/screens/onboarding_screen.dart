import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/monitor_settings.dart';
import 'main_navigation.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<String> _ageGroups = ['Under 18', '18-40', '41-60', '61+'];

  String _selectedAgeGroup = ageGroupNotifier.value;
  bool _usesHearingAid = usesHearingAidNotifier.value;
  bool _autoThreshold = true;

  Future<void> _finishOnboarding() async {
    ageGroupNotifier.value = _selectedAgeGroup;
    usesHearingAidNotifier.value = _usesHearingAid;
    autoThresholdNotifier.value = _autoThreshold;

    if (_autoThreshold) {
      applyPersonalizedThreshold();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
    );
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _skip() {
    _finishOnboarding();
  }

  Widget _buildDot(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 10,
      width: active ? 24 : 10,
      decoration: BoxDecoration(
        color: active ? Colors.blue : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextButton(onPressed: _skip, child: const Text('Skip')),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildWelcomePage(),
                  _buildAgeProfilePage(),
                  _buildHearingProfilePage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDot(_currentPage == 0),
                      _buildDot(_currentPage == 1),
                      _buildDot(_currentPage == 2),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _currentPage == 2 ? 'Finish Setup' : 'Continue',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hearing_rounded, size: 90, color: Colors.blue.shade700),
          const SizedBox(height: 24),
          const Text(
            'Welcome to SafeSound',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Text(
            'Monitor sound around you, get safer alerts, and build healthier listening habits over time.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 28),
          _buildFeatureTile(Icons.mic, 'Live microphone monitoring'),
          const SizedBox(height: 14),
          _buildFeatureTile(
            Icons.notifications_active,
            'Personalized exposure alerts',
          ),
          const SizedBox(height: 14),
          _buildFeatureTile(
            Icons.insights,
            'History, trends, and weekly insights',
          ),
        ],
      ),
    );
  }

  Widget _buildAgeProfilePage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 82, color: Colors.orange.shade700),
          const SizedBox(height: 22),
          const Text(
            'Set up your profile',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Your age group helps SafeSound recommend a safer alert threshold.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 28),
          DropdownButtonFormField<String>(
            value: _selectedAgeGroup,
            decoration: const InputDecoration(
              labelText: 'Age Group',
              border: OutlineInputBorder(),
            ),
            items: _ageGroups.map((group) {
              return DropdownMenuItem<String>(value: group, child: Text(group));
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedAgeGroup = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHearingProfilePage() {
    final recommendedThreshold = getRecommendedThreshold(
      ageGroup: _selectedAgeGroup,
      usesHearingAid: _usesHearingAid,
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.health_and_safety_outlined,
            size: 82,
            color: Colors.green.shade700,
          ),
          const SizedBox(height: 22),
          const Text(
            'Personalize your alerts',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose whether you use hearing aid support. SafeSound can automatically apply a safer threshold for you.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Uses Hearing Aid'),
                    subtitle: const Text(
                      'Used for earlier safety alerts and more protective guidance',
                    ),
                    value: _usesHearingAid,
                    onChanged: (value) {
                      setState(() {
                        _usesHearingAid = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Use Personalized Threshold Automatically',
                    ),
                    subtitle: const Text('Recommended for safer monitoring'),
                    value: _autoThreshold,
                    onChanged: (value) {
                      setState(() {
                        _autoThreshold = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recommended Threshold',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${recommendedThreshold.toInt()} dB',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  getThresholdReason(
                    ageGroup: _selectedAgeGroup,
                    usesHearingAid: _usesHearingAid,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile(IconData icon, String text) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: Colors.blue.shade50,
          child: Icon(icon, color: Colors.blue.shade700),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
      ],
    );
  }
}

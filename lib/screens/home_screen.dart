import 'package:flutter/material.dart';
import 'method_channel_screen.dart';
import 'event_channel_screen.dart';
import 'message_channel_screen.dart';
import 'advanced_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _lessons = [
    _LessonCard(
      number: '01',
      title: 'MethodChannel',
      subtitle: 'Call native methods and get return values',
      icon: Icons.call_made_rounded,
      color: Color(0xFF1565C0),
      screen: MethodChannelScreen(),
    ),
    _LessonCard(
      number: '02',
      title: 'EventChannel',
      subtitle: 'Stream continuous data from native to Dart',
      icon: Icons.stream_rounded,
      color: Color(0xFF2E7D32),
      screen: EventChannelScreen(),
    ),
    _LessonCard(
      number: '03',
      title: 'BasicMessageChannel',
      subtitle: 'Two-way message passing with codecs',
      icon: Icons.swap_horiz_rounded,
      color: Color(0xFF6A1B9A),
      screen: MessageChannelScreen(),
    ),
    _LessonCard(
      number: '04',
      title: 'Advanced Topics',
      subtitle: 'Error handling, data types, background threads',
      icon: Icons.settings_suggest_rounded,
      color: Color(0xFFBF360C),
      screen: AdvancedScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(
            title: Text('Native Channels\nCourse'),
            backgroundColor: Color(0xFF0553B1),
            foregroundColor: Colors.white,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == 0) return const _IntroCard();
                  final lesson = _lessons[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: lesson,
                  );
                },
                childCount: _lessons.length + 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBDEFB)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About this course',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          SizedBox(height: 8),
          Text(
            'Learn how Flutter communicates with native Android (Kotlin) and iOS (Swift) '
            'code through platform channels. Each lesson includes runnable Dart examples '
            'and matching native implementations.',
            style: TextStyle(color: Colors.black54, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.screen,
  });

  final String number;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget screen;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lesson $number',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

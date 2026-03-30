import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeIn;
  late final Animation<double> _fadeOut;
  late final String _quote;
  late final String _author;

  static const _quotes = [
    // James Clear
    ('Small steps every day build the life you want.', 'James Clear'),
    ('You don\'t rise to the level of your goals, you fall to the level of your systems.', 'James Clear'),
    ('Every action you take is a vote for the type of person you want to become.', 'James Clear'),
    ('The most practical way to change who you are is to change what you do.', 'James Clear'),
    ('You do not rise to the level of your goals. You fall to the level of your systems.', 'James Clear'),
    // Cal Newport
    ('One hour of focused work beats eight hours of distraction.', 'Cal Newport'),
    ('The quality of your attention determines the quality of your work.', 'Cal Newport'),
    ('Deep work is the superpower of the 21st century.', 'Cal Newport'),
    ('Clarity about what matters provides clarity about what does not.', 'Cal Newport'),
    ('Efforts to deepen your focus will struggle if you don\'t simultaneously wean your mind from a dependence on distraction.', 'Cal Newport'),
    // Stoics & Philosophers
    ('The man who moves a mountain begins by carrying away small stones.', 'Confucius'),
    ('We suffer more in imagination than in reality.', 'Seneca'),
    ('Waste no more time arguing about what a good person should be. Be one.', 'Marcus Aurelius'),
    ('It is not that we have little time, but that we waste a great deal of it.', 'Seneca'),
    ('Concentrate every minute on doing what\'s in front of you with precise attention.', 'Marcus Aurelius'),
    // Achievers & Leaders
    ('The secret of getting ahead is getting started.', 'Mark Twain'),
    ('It always seems impossible until it\'s done.', 'Nelson Mandela'),
    ('Don\'t count the days. Make the days count.', 'Muhammad Ali'),
    ('Start where you are. Use what you have. Do what you can.', 'Arthur Ashe'),
    ('Champions keep playing until they get it right.', 'Billie Jean King'),
    ('I fear not the man who has practiced 10,000 kicks once, but the man who has practiced one kick 10,000 times.', 'Bruce Lee'),
    ('Hard work beats talent when talent doesn\'t work hard.', 'Tim Notke'),
    ('Success is the sum of small efforts repeated day in and day out.', 'Robert Collier'),
    ('Discipline is choosing between what you want now and what you want most.', 'Abraham Lincoln'),
    ('Motivation gets you going, but discipline keeps you growing.', 'John C. Maxwell'),
    // Focus & Deep Work
    ('Focus on the process, not the outcome.', 'Unknown'),
    ('Energy flows where attention goes.', 'Unknown'),
    ('Progress, not perfection.', 'Unknown'),
    ('Win the morning, win the day.', 'Tim Ferriss'),
    ('Do the hard thing first. The rest becomes easy.', 'Brian Tracy'),
    ('Your future self is watching you through your memories.', 'Unknown'),
    ('What you do today shapes who you become tomorrow.', 'Unknown'),
    ('Momentum is built one session at a time.', 'Momentum'),
    ('The difference between who you are and who you want to be is what you do.', 'Unknown'),
    ('Be so good they can\'t ignore you.', 'Steve Martin'),
    // Growth & Habits
    ('We are what we repeatedly do. Excellence, then, is not an act, but a habit.', 'Aristotle'),
    ('Fall in love with the process and the results will come.', 'Eric Thomas'),
    ('A year from now you may wish you had started today.', 'Karen Lamb'),
    ('The only way to do great work is to love what you do.', 'Steve Jobs'),
    ('Don\'t wish it were easier. Wish you were better.', 'Jim Rohn'),
    ('You don\'t have to be great to start, but you have to start to be great.', 'Zig Ziglar'),
    ('An investment in yourself pays the best interest.', 'Benjamin Franklin'),
    ('The secret to success is to start before you are ready.', 'Marie Forleo'),
    ('Work hard in silence. Let success make the noise.', 'Frank Ocean'),
    ('Push yourself because no one else is going to do it for you.', 'Unknown'),
    ('The pain of discipline is far less than the pain of regret.', 'Sarah Bombell'),
    ('Little by little, a little becomes a lot.', 'Tanzanian Proverb'),
    ('Show up. Do the work. Repeat.', 'Momentum'),
    ('Your only limit is your mind.', 'Unknown'),
    ('One focused session can change everything.', 'Momentum'),
  ];

  @override
  void initState() {
    super.initState();

    final pick = _quotes[Random().nextInt(_quotes.length)];
    _quote = pick.$1;
    _author = pick.$2;

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    _fadeIn = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.22, curve: Curves.easeOut),
    );

    _fadeOut = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.82, 1.0, curve: Curves.easeIn),
    );

    _ctrl.forward().then((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, anim, secondary) => const HomeScreen(),
          transitionsBuilder: (context, anim, secondary, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final opacity = (_fadeIn.value - _fadeOut.value).clamp(0.0, 1.0);
          return Opacity(
            opacity: opacity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App logo / name
                  Text(
                    'M',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.accent,
                      height: 1,
                    ),
                  ),
                  Text(
                    'MOMENTUM',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white54,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 64),

                  // Quote
                  Text(
                    '"$_quote"',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Author
                  Text(
                    '— $_author',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.accent.withAlpha(200),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

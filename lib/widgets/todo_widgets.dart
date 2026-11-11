import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class TodoProgressBar extends StatelessWidget {
  final double completion;
  final BoxConstraints constraints;

  const TodoProgressBar({
    super.key,
    required this.completion,
    required this.constraints,
  });

  Color _getCompletionColor(double completion) {
    if (completion >= 90) return Colors.green;
    if (completion >= 70) return Colors.yellow;
    if (completion >= 30) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: constraints.maxHeight * 0.2,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green],
        ),
      ),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          ProgressRunner(
            completion: completion,
            constraints: constraints,
            completionColor: _getCompletionColor(completion),
          ),
          ProgressMarkers(constraints: constraints),
        ],
      ),
    );
  }
}

class ProgressRunner extends StatelessWidget {
  final double completion;
  final BoxConstraints constraints;
  final Color completionColor;

  const ProgressRunner({
    super.key,
    required this.completion,
    required this.constraints,
    required this.completionColor,
  });

  double _getRunnerPosition(BoxConstraints constraints) {
    final maxWidth = constraints.maxWidth * 0.9;
    final startPosition = constraints.maxWidth * 0.05;
    return startPosition + (completion / 100) * (maxWidth - 50);
  }

  String _getProgressImage() {
    if (completion < 20) {
      return 'assets/images/run.gif';
    } else if (completion < 55) {
      return 'assets/images/step_1.gif';
    } else if (completion < 85) {
      return 'assets/images/step_2.gif';
    } else {
      return 'assets/images/step_3.gif';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _getRunnerPosition(constraints).clamp(
        constraints.maxWidth * 0.05,
        constraints.maxWidth * 0.95 - 50,
      ),
      bottom: 30,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '${completion.toStringAsFixed(1)}%',
              style: TextStyle(
                color: completionColor,
                fontWeight: FontWeight.bold,
                fontSize: constraints.maxWidth * 0.04,
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: constraints.maxHeight * 0.1,
            child: Image.asset(
              _getProgressImage(),
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressMarkers extends StatelessWidget {
  final BoxConstraints constraints;

  const ProgressMarkers({
    super.key,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: constraints.maxWidth * 0.05,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: ['0%', '25%', '50%', '75%', '100%'].map((label) {
          return Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: constraints.maxWidth * 0.035,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  offset: const Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ChatBubbleWidget extends StatelessWidget {
  final String message;
  final VoidCallback onHeartTap;
  final Animation<double> messageAnimation;
  final Animation<double> heartAnimation;
  final BoxConstraints constraints;

  const ChatBubbleWidget({
    super.key,
    required this.message,
    required this.onHeartTap,
    required this.messageAnimation,
    required this.heartAnimation,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: constraints.maxWidth * 0.04,
        vertical: constraints.maxWidth * 0.02,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onHeartTap,
            child: ScaleTransition(
              scale: heartAnimation,
              child: CircleAvatar(
                backgroundColor: CupertinoColors.systemPink.withOpacity(0.8),
                radius: constraints.maxWidth * 0.03,
                child: Icon(
                  CupertinoIcons.heart_fill,
                  color: CupertinoColors.white,
                  size: constraints.maxWidth * 0.04,
                ),
              ),
            ),
          ),
          SizedBox(width: constraints.maxWidth * 0.02),
          Expanded(
            child: ScaleTransition(
              scale: messageAnimation,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.3,
                ),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemPink.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(constraints.maxWidth * 0.03),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '기부니~! 💖',
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.white
                                : CupertinoColors.systemPink,
                            fontWeight: FontWeight.bold,
                            fontSize: constraints.maxWidth * 0.035,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.white
                                : CupertinoColors.darkBackgroundGray,
                            fontSize: constraints.maxWidth * 0.035,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final double width;
  final BoxConstraints constraints;
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.width,
    required this.constraints,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textSize = constraints.maxWidth * 0.035;
    final isWideCard = width == constraints.maxWidth;

    return SizedBox(
      width: width,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3), width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.all(constraints.maxWidth * 0.03),
          child: isWideCard
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: color, size: textSize * 1.5),
                        SizedBox(width: constraints.maxWidth * 0.02),
                        Text(title, style: TextStyle(fontSize: textSize)),
                      ],
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: textSize * 1.5,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: color, size: textSize * 1.2),
                        SizedBox(width: constraints.maxWidth * 0.02),
                        Text(title, style: TextStyle(fontSize: textSize)),
                      ],
                    ),
                    SizedBox(height: constraints.maxHeight * 0.01),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: textSize * 1.5,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

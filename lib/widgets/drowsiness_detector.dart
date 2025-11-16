import 'package:flutter/material.dart';

class DrowsinessIndicatorWidget extends StatelessWidget {
  final double score;

  const DrowsinessIndicatorWidget({
    Key? key,
    required this.score,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color getColor() {
      if (score < 0.3) return Colors.green;
      if (score < 0.6) return Colors.orange;
      return Colors.red;
    }

    String getStatus() {
      if (score < 0.3) return 'ALERT';
      if (score < 0.6) return 'SLIGHTLY DROWSY';
      return 'VERY DROWSY';
    }

    String getDescription() {
      if (score < 0.3) return 'You are fully alert and focused';
      if (score < 0.6) return 'Showing signs of fatigue';
      return 'High drowsiness detected! Consider taking a break';
    }

    IconData getIcon() {
      if (score < 0.3) return Icons.sentiment_very_satisfied;
      if (score < 0.6) return Icons.sentiment_neutral;
      return Icons.sentiment_very_dissatisfied;
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: getColor().withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(getIcon(), color: getColor(), size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getStatus(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: getColor(),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      getDescription(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          LinearProgressIndicator(
            value: score,
            backgroundColor: Colors.grey[300],
            color: getColor(),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Drowsiness Score',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '${(score * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: getColor(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
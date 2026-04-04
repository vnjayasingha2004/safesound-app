class TrendPoint {
  final String label;
  final double value;

  const TrendPoint({required this.label, required this.value});
}

const List<TrendPoint> dailyTrendData = [
  TrendPoint(label: 'Mon', value: 62),
  TrendPoint(label: 'Tue', value: 75),
  TrendPoint(label: 'Wed', value: 68),
  TrendPoint(label: 'Thu', value: 82),
  TrendPoint(label: 'Fri', value: 79),
  TrendPoint(label: 'Sat', value: 58),
  TrendPoint(label: 'Sun', value: 64),
];

const List<TrendPoint> weeklyTrendData = [
  TrendPoint(label: 'W1', value: 66),
  TrendPoint(label: 'W2', value: 73),
  TrendPoint(label: 'W3', value: 78),
  TrendPoint(label: 'W4', value: 70),
];

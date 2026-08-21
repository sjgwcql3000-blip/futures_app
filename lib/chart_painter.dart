import 'package:flutter/material.dart';
import 'model_and_api.dart';

class SingleChartWidget extends StatelessWidget {
  final List<KLineData> data;
  final String periodName;

  const SingleChartWidget({Key? key, required this.data, required this.periodName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.grey.shade800, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 周期小标题
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2),
            child: Text(
              periodName,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
          Expanded(
            child: data.isEmpty
                ? const Center(child: Text("加载中...", style: TextStyle(color: Colors.grey, fontSize: 9)))
                : CustomPaint(
                    painter: ChartPainter(data: data),
                    size: Size.infinite,
                  ),
          ),
        ],
      ),
    );
  }
}

class ChartPainter extends CustomPainter {
  final List<KLineData> data;
  ChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // 上方主图占 70% 空间画 K线与7条均线，下方 30% 画 MACD
    final double mainHeight = size.height * 0.7;
    final double macdHeight = size.height * 0.3;

    // 计算价格极值
    double maxP = -double.maxFinite;
    double minP = double.maxFinite;
    for (var item in data) {
      if (item.high > maxP) maxP = item.high;
      if (item.low < minP) minP = item.low;
    }
    if (maxP == minP) {
      maxP += 1.0;
      minP -= 1.0;
    }

    // 计算 MACD 极值
    double maxDiff = 0.0001;
    for (var item in data) {
      if (item.diff != null && item.diff!.abs() > maxDiff) {
        maxDiff = item.diff!.abs();
      }
    }

    int count = data.length > 50 ? 50 : data.length; // 默认最多显示最近 50 根
    List<KLineData> subData = data.length > 50 ? data.sublist(data.length - 50) : data;
    double candleWidth = size.width / count;

    // 1. 绘制 7 条均线 (5, 10, 20, 30, 60, 120, 240)
    _drawMA(canvas, subData, size.width, mainHeight, maxP, minP, count);

    // 2. 绘制 K 线蜡烛
    for (int i = 0; i < subData.length; i++) {
      var item = subData[i];
      double x = i * candleWidth + candleWidth / 2;
      
      double openY = mainHeight - (item.open - minP) / (maxP - minP) * mainHeight;
      double closeY = mainHeight - (item.close - minP) / (maxP - minP) * mainHeight;
      double highY = mainHeight - (item.high - minP) / (maxP - minP) * mainHeight;
      double lowY = mainHeight - (item.low - minP) / (maxP - minP) * mainHeight;

      bool isUp = item.close >= item.open;
      Paint paint = Paint()
        ..color = isUp ? Colors.red : Colors.green
        ..strokeWidth = 1.0;

      // 画上下影线
      canvas.drawLine(Offset(x, highY), Offset(x, lowY), paint);
      // 画实体
      double topY = openY < closeY ? openY : closeY;
      double bodyH = (openY - closeY).abs();
      if (bodyH < 1) bodyH = 1;
      canvas.drawRect(Rect.fromLTWH(x - candleWidth * 0.35, topY, candleWidth * 0.7, bodyH), paint);
    }

    // 3. 绘制 MT4 风格单线 MACD 变色柱体 (下方区域)
    final double macdCenterY = mainHeight + macdHeight / 2;
    for (int i = 0; i < subData.length; i++) {
      var item = subData[i];
      if (item.diff == null) continue;

      double x = i * candleWidth + candleWidth / 2;
      double barH = (item.diff! / maxDiff) * (macdHeight * 0.45);
      
      Color barColor;
      if (item.macdColorType == 1) {
        barColor = Colors.red;    // 首次上涨红
      } else if (item.macdColorType == 2) {
        barColor = Colors.green;  // 首次下跌绿
      } else {
        barColor = Colors.blue;   // 默认蓝色
      }

      Paint macdPaint = Paint()
        ..color = barColor
        ..strokeWidth = candleWidth * 0.6;

      canvas.drawLine(
        Offset(x, macdCenterY),
        Offset(x, macdCenterY - barH),
        macdPaint,
      );
    }
  }

  void _drawMA(Canvas canvas, List<KLineData> subData, double width, double height, double maxP, double minP, int count) {
    List<Map<String, dynamic>> maConfigs = [
      {"key": "ma5", "color": Colors.white},
      {"key": "ma10", "color": Colors.yellow},
      {"key": "ma20", "color": Colors.purpleAccent},
      {"key": "ma30", "color": Colors.greenAccent},
      {"key": "ma60", "color": Colors.orange},
      {"key": "ma120", "color": Colors.cyan},
      {"key": "ma240", "color": Colors.pink},
    ];

    double candleWidth = width / count;

    for (var cfg in maConfigs) {
      String key = cfg["key"];
      Color color = cfg["color"];
      Path path = Path();
      bool started = false;

      for (int i = 0; i < subData.length; i++) {
        double? val = _getVal(subData[i], key);
        if (val != null) {
          double x = i * candleWidth + candleWidth / 2;
          double y = height - (val - minP) / (maxP - minP) * height;
          if (!started) {
            path.moveTo(x, y);
            started = true;
          } else {
            path.lineTo(x, y);
          }
        }
      }

      Paint paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      canvas.drawPath(path, paint);
    }
  }

  double? _getVal(KLineData item, String key) {
    switch (key) {
      case "ma5": return item.ma5;
      case "ma10": return item.ma10;
      case "ma20": return item.ma20;
      case "ma30": return item.ma30;
      case "ma60": return item.ma60;
      case "ma120": return item.ma120;
      case "ma240": return item.ma240;
      default: return null;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
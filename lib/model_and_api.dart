import 'dart:convert';
import 'package:http/http.dart' as http;

// 品种配置
class FuturesConfig {
  static const Map<String, String> symbols = {
    "rb2611": "螺纹钢2611",
    "fg2611": "玻璃2611",
    "ur2611": "尿素2611",
    "jd2611": "鸡蛋2611",
    "cs2611": "玉米淀粉2611",
    "ma2611": "甲醇2611",
    "v2611": "PVC2611",
    "l2611": "塑料2611",
  };
}

// K线基础数据结构
class KLineData {
  final String date;
  final double open;
  final double high;
  final double low;
  final double close;
  
  // 均线字段
  double? ma5;
  double? ma10;
  double? ma20;
  double? ma30;
  double? ma60;
  double? ma120;
  double? ma240;

  // MACD字段
  double? diff;
  int macdColorType = 0; // 0: 默认蓝色, 1: 首次上涨红, 2: 首次下跌绿

  KLineData({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });
}

class MarketDataApi {
  // 按照您提供的逻辑适配新浪接口
  static Future<List<KLineData>> fetchSinaData(String symbol, String period) async {
    String url;
    if (period == "60") {
      url = "https://stock2.finance.sina.com.cn/futures/api/jsonp.php/var_data=/InnerFuturesNewService.getFewMinLine?symbol=$symbol&type=60";
    } else if (period == "day") {
      url = "https://stock2.finance.sina.com.cn/futures/api/jsonp.php/var_data=/InnerFuturesNewService.getDailyKLine?symbol=$symbol";
    } else {
      // 年线/月线复用历史K线或按新浪周线/月线接口适配
      url = "https://stock2.finance.sina.com.cn/futures/api/jsonp.php/var_data=/InnerFuturesNewService.getDailyKLine?symbol=$symbol";
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        String text = response.body;
        int a = text.indexOf("(");
        int b = text.lastIndexOf(")");
        if (a >= 0 && b > a) {
          String jsonStr = text.substring(a + 1, b);
          List<dynamic> list = jsonDecode(jsonStr);
          List<KLineData> results = [];
          for (var item in list) {
            results.add(KLineData(
              date: item["d"] ?? "",
              open: double.tryParse(item["o"].toString()) ?? 0.0,
              high: double.tryParse(item["h"].toString()) ?? 0.0,
              low: double.tryParse(item["l"].toString()) ?? 0.0,
              close: double.tryParse(item["c"].toString()) ?? 0.0,
            ));
          }
          _calculateIndicators(results);
          return results;
        }
      }
    } catch (_) {}
    return [];
  }

  // 计算 7 条均线与 MT4 变色 MACD
  static void _calculateIndicators(List<KLineData> list) {
    if (list.isEmpty) return;

    // 1. 计算均线 (5, 10, 20, 30, 60, 120, 240)
    List<int> periods = [5, 10, 20, 30, 60, 120, 240];
    for (int p in periods) {
      for (int i = 0; i < list.length; i++) {
        if (i >= p - 1) {
          double sum = 0;
          for (int j = i - p + 1; j <= i; j++) {
            sum += list[j].close;
          }
          double maVal = sum / p;
          if (p == 5) list[i].ma5 = maVal;
          if (p == 10) list[i].ma10 = maVal;
          if (p == 20) list[i].ma20 = maVal;
          if (p == 30) list[i].ma30 = maVal;
          if (p == 60) list[i].ma60 = maVal;
          if (p == 120) list[i].ma120 = maVal;
          if (p == 240) list[i].ma240 = maVal;
        }
      }
    }

    // 2. 计算 MACD (EMA12 - EMA26)
    List<double> closes = list.map((e) => e.close).toList();
    List<double> e12 = _ema(closes, 12);
    List<double> e26 = _ema(closes, 26);
    List<double> diffs = [];
    for (int i = 0; i < closes.length; i++) {
      double d = e12[i] - e26[i];
      diffs.add(d);
      list[i].diff = d;
    }

    // 3. MT4 变色柱体逻辑：对比前三根柱体演变
    // d1(柱0/最新), d2(柱1), d3(柱2)
    for (int i = 2; i < list.length; i++) {
      double d1 = diffs[i];
      double d2 = diffs[i - 1];
      double d3 = diffs[i - 2];

      if (d1 > d2 && d2 < d3) {
        list[i].macdColorType = 1; // 首次上涨柱体 -> 红色
      } else if (d1 < d2 && d2 > d3) {
        list[i].macdColorType = 2; // 首次下跌柱体 -> 绿色
      } else {
        list[i].macdColorType = 0; // 默认蓝色
      }
    }
  }

  static List<double> _ema(List<double> values, int period) {
    double k = 2 / (period + 1);
    double e = values[0];
    List<double> result = [e];
    for (int i = 1; i < values.length; i++) {
      e = values[i] * k + e * (1 - k);
      result.add(e);
    }
    return result;
  }
}
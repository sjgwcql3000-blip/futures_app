import 'package:flutter/material.dart';
import 'model_and_api.dart';
import 'chart_painter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '期货MT4盯盘助手',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      home: const FuturesHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class FuturesHomePage extends StatefulWidget {
  const FuturesHomePage({Key? key}) : super(key: key);

  @override
  State<FuturesHomePage> createState() => _FuturesHomePageState();
}

class _FuturesHomePageState extends State<FuturesHomePage> {
  // 8个指定品种
  final List<String> symbols = [
    "rb2611", "fg2611", "ur2611", "jd2611",
    "cs2611", "v2611", "ma2611", "l2611"
  ];

  // 缓存各品种及周期的K线数据: { "rb2611_day": [KLineData, ...], ... }
  final Map<String, List<KLineData>> _cacheData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });

    List<String> periods = ["year", "month", "day", "60"];

    for (String symbol in symbols) {
      for (String p in periods) {
        // 请求新浪接口数据
        List<KLineData> data = await MarketDataApi.fetchSinaData(symbol, p);
        _cacheData["${symbol}_$p"] = data;
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 将 8 个品种平分为 2 页，每页 4 个品种
    List<String> page1Symbols = symbols.sublist(0, 4);
    List<String> page2Symbols = symbols.sublist(4, 8);

    return Scaffold(
      appBar: AppBar(
        title: const Text("期货多周期盯盘 (MT4风格MACD)", style: TextStyle(fontSize: 14)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _isLoading ? null : _loadAllData,
          )
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text("正在同步新浪行情及计算均线/MACD...", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
          : PageView(
              scrollDirection: Axis.vertical, // 上下滚动翻页
              children: [
                _buildPage(page1Symbols, "第 1 页 (1-4品种)"),
                _buildPage(page2Symbols, "第 2 页 (5-8品种)"),
              ],
            ),
    );
  }

  Widget _buildPage(List<String> pageSymbols, String pageTitle) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          color: Colors.grey.shade900,
          width: double.infinity,
          child: Text(
            "$pageTitle (上下滑动翻页)",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.amber, fontSize: 11),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: pageSymbols.length,
            itemBuilder: (context, index) {
              String sym = pageSymbols[index];
              String name = FuturesConfig.symbols[sym] ?? sym;
              return _buildSymbolRow(sym, name);
            },
          ),
        ),
      ],
    );
  }

  // 单个品种行：横向排列 4 个周期（年线、月线、日线、1小时线）
  Widget _buildSymbolRow(String symbol, String name) {
    // 年、月、日、1小时
    List<String> periods = ["year", "month", "day", "60"];
    List<String> periodNames = ["年线", "月线", "日线", "1小时"];

    return Container(
      height: 140, // 手机上单行高度
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 品种名称栏
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 2),
            child: Text(
              name,
              style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          // 4个周期的横向矩阵
          Expanded(
            child: Row(
              children: List.generate(4, (i) {
                String pKey = periods[i];
                String pName = periodNames[i];
                List<KLineData> chartData = _cacheData["${symbol}_$pKey"] ?? [];

                return Expanded(
                  child: SingleChartWidget(
                    data: chartData,
                    periodName: pName,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
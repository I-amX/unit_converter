import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UnitConverterApp());
}

class UnitConverterApp extends StatefulWidget {
  const UnitConverterApp({super.key});

  @override
  State<UnitConverterApp> createState() => _UnitConverterAppState();
}

class _UnitConverterAppState extends State<UnitConverterApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  void _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('themeMode') ?? 0;
    setState(() {
      _themeMode = ThemeMode.values[themeIndex.clamp(0, 2)];
    });
  }

  void _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unit Converter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        brightness: Brightness.light,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      themeMode: _themeMode,
      home: const UnitConverterHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ---------- History Entry Model ----------
class ConversionHistory {
  final double inputValue;
  final String fromUnit;
  final String toUnit;
  final String result;
  final DateTime timestamp;

  ConversionHistory({
    required this.inputValue,
    required this.fromUnit,
    required this.toUnit,
    required this.result,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'inputValue': inputValue,
    'fromUnit': fromUnit,
    'toUnit': toUnit,
    'result': result,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ConversionHistory.fromJson(Map<String, dynamic> json) {
    return ConversionHistory(
      inputValue: json['inputValue'] as double,
      fromUnit: json['fromUnit'] as String,
      toUnit: json['toUnit'] as String,
      result: json['result'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

// ---------- Main Converter Widget ----------
class UnitConverterHome extends StatefulWidget {
  const UnitConverterHome({super.key});

  @override
  State<UnitConverterHome> createState() => _UnitConverterHomeState();
}

class _UnitConverterHomeState extends State<UnitConverterHome> {
  final List<String> _categories = ['Length', 'Weight', 'Temperature'];
  String _selectedCategory = 'Length';

  final Map<String, List<String>> _unitsMap = {
    'Length': [
      'Meters (m)',
      'Kilometers (km)',
      'Centimeters (cm)',
      'Millimeters (mm)',
      'Inches (in)',
      'Feet (ft)',
      'Yards (yd)',
      'Miles (mi)'
    ],
    'Weight': [
      'Kilograms (kg)',
      'Grams (g)',
      'Metric tons (t)',
      'Pounds (lb)',
      'Ounces (oz)',
      'Stones (st)'
    ],
    'Temperature': ['Celsius (°C)', 'Fahrenheit (°F)', 'Kelvin (K)']
  };

  late List<String> _currentUnits;
  late String _fromUnit;
  late String _toUnit;

  final TextEditingController _inputController = TextEditingController();
  String _result = '0';
  String _errorMessage = '';
  List<ConversionHistory> _history = [];

  @override
  void initState() {
    super.initState();
    _currentUnits = _unitsMap[_selectedCategory]!;
    _setDefaultUnits();
    _inputController.addListener(_onInputChanged);
    _loadHistory();
  }

  void _setDefaultUnits() {
    switch (_selectedCategory) {
      case 'Length':
        _fromUnit = 'Meters (m)';
        _toUnit = 'Feet (ft)';
        break;
      case 'Weight':
        _fromUnit = 'Kilograms (kg)';
        _toUnit = 'Pounds (lb)';
        break;
      case 'Temperature':
        _fromUnit = 'Celsius (°C)';
        _toUnit = 'Fahrenheit (°F)';
        break;
    }
  }

  void _onInputChanged() {
    _convert();
  }

  void _convert() {
    setState(() {
      final inputText = _inputController.text.trim();
      if (inputText.isEmpty) {
        _result = '0';
        _errorMessage = '';
        return;
      }
      final double? value = double.tryParse(inputText);
      if (value == null) {
        _result = 'Invalid input';
        _errorMessage = 'Please enter a valid number';
        return;
      }
      _errorMessage = '';
      final converted = _performConversion(value, _fromUnit, _toUnit);
      _result = _formatDouble(converted);
      // Save to history only if the input is valid and result is not invalid
      if (_result != 'Invalid input') {
        _saveToHistory(value, _fromUnit, _toUnit, _result);
      }
    });
  }

  void _saveToHistory(double input, String from, String to, String result) async {
    final entry = ConversionHistory(
      inputValue: input,
      fromUnit: from,
      toUnit: to,
      result: result,
      timestamp: DateTime.now(),
    );
    _history.insert(0, entry); // newest first
    // Keep only last 20 entries to avoid cluttering
    if (_history.length > 20) _history.removeLast();
    final prefs = await SharedPreferences.getInstance();
    final List<String> encoded = _history.map((e) => e.toJson().toString()).toList();
    await prefs.setStringList('history', encoded);
  }

  void _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? encoded = prefs.getStringList('history');
    if (encoded != null) {
      setState(() {
        _history = encoded
            .map((e) => ConversionHistory.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList();
      });
    }
  }

  void _clearHistory() async {
    setState(() => _history.clear());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('history');
  }

  double _performConversion(double value, String from, String to) {
    switch (_selectedCategory) {
      case 'Length':
        return _convertLength(value, from, to);
      case 'Weight':
        return _convertWeight(value, from, to);
      case 'Temperature':
        return _convertTemperature(value, from, to);
      default:
        return value;
    }
  }

  // ---------- Conversion logic (unchanged from previous) ----------
  double _toMeters(String unit, double value) {
    switch (unit) {
      case 'Meters (m)': return value;
      case 'Kilometers (km)': return value * 1000;
      case 'Centimeters (cm)': return value * 0.01;
      case 'Millimeters (mm)': return value * 0.001;
      case 'Inches (in)': return value * 0.0254;
      case 'Feet (ft)': return value * 0.3048;
      case 'Yards (yd)': return value * 0.9144;
      case 'Miles (mi)': return value * 1609.344;
      default: return value;
    }
  }

  double _fromMeters(String unit, double meters) {
    switch (unit) {
      case 'Meters (m)': return meters;
      case 'Kilometers (km)': return meters / 1000;
      case 'Centimeters (cm)': return meters / 0.01;
      case 'Millimeters (mm)': return meters / 0.001;
      case 'Inches (in)': return meters / 0.0254;
      case 'Feet (ft)': return meters / 0.3048;
      case 'Yards (yd)': return meters / 0.9144;
      case 'Miles (mi)': return meters / 1609.344;
      default: return meters;
    }
  }

  double _convertLength(double value, String from, String to) {
    final meters = _toMeters(from, value);
    return _fromMeters(to, meters);
  }

  double _toKilograms(String unit, double value) {
    switch (unit) {
      case 'Kilograms (kg)': return value;
      case 'Grams (g)': return value * 0.001;
      case 'Metric tons (t)': return value * 1000;
      case 'Pounds (lb)': return value * 0.45359237;
      case 'Ounces (oz)': return value * 0.028349523125;
      case 'Stones (st)': return value * 6.35029318;
      default: return value;
    }
  }

  double _fromKilograms(String unit, double kg) {
    switch (unit) {
      case 'Kilograms (kg)': return kg;
      case 'Grams (g)': return kg / 0.001;
      case 'Metric tons (t)': return kg / 1000;
      case 'Pounds (lb)': return kg / 0.45359237;
      case 'Ounces (oz)': return kg / 0.028349523125;
      case 'Stones (st)': return kg / 6.35029318;
      default: return kg;
    }
  }

  double _convertWeight(double value, String from, String to) {
    final kg = _toKilograms(from, value);
    return _fromKilograms(to, kg);
  }

  double _toCelsius(String unit, double value) {
    switch (unit) {
      case 'Celsius (°C)': return value;
      case 'Fahrenheit (°F)': return (value - 32) * 5 / 9;
      case 'Kelvin (K)': return value - 273.15;
      default: return value;
    }
  }

  double _fromCelsius(String unit, double celsius) {
    switch (unit) {
      case 'Celsius (°C)': return celsius;
      case 'Fahrenheit (°F)': return celsius * 9 / 5 + 32;
      case 'Kelvin (K)': return celsius + 273.15;
      default: return celsius;
    }
  }

  double _convertTemperature(double value, String from, String to) {
    final celsius = _toCelsius(from, value);
    return _fromCelsius(to, celsius);
  }

  String _formatDouble(double value) {
    if (value.isNaN || value.isInfinite) return '0';
    String formatted = value.toStringAsFixed(6);
    formatted = formatted.replaceAll(RegExp(r'0+$'), '');
    if (formatted.endsWith('.')) formatted = formatted.substring(0, formatted.length - 1);
    return formatted;
  }

  void _swapUnits() {
    setState(() {
      final temp = _fromUnit;
      _fromUnit = _toUnit;
      _toUnit = temp;
      _convert();
    });
  }

  void _copyResult() {
    if (_result == 'Invalid input' || _result.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to copy – invalid result')),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: _result));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied: $_result'), duration: const Duration(seconds: 1)),
    );
  }

  void _onCategoryChanged(String? newCategory) {
    if (newCategory == null) return;
    setState(() {
      _selectedCategory = newCategory;
      _currentUnits = _unitsMap[_selectedCategory]!;
      _setDefaultUnits();
      _convert();
    });
  }

  void _onFromUnitChanged(String? newUnit) {
    if (newUnit == null) return;
    setState(() {
      _fromUnit = newUnit;
      _convert();
    });
  }

  void _onToUnitChanged(String? newUnit) {
    if (newUnit == null) return;
    setState(() {
      _toUnit = newUnit;
      _convert();
    });
  }

  void _showHistoryDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Conversion History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep),
                    onPressed: () {
                      _clearHistory();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('History cleared')),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _history.isEmpty
                  ? const Center(child: Text('No conversions yet'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _history.length,
                      itemBuilder: (ctx, index) {
                        final entry = _history[index];
                        return ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(
                            '${entry.inputValue} ${entry.fromUnit} → ${entry.result} ${entry.toUnit}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(DateFormat.yMMMd().add_jm().format(entry.timestamp)),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: entry.result));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Copied: ${entry.result}')),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unit Converter'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _showHistoryDialog,
            tooltip: 'History',
          ),
          PopupMenuButton<ThemeMode>(
            icon: const Icon(Icons.brightness_6),
            onSelected: (mode) {
              final appState = context.findAncestorStateOfType<_UnitConverterAppState>();
              appState?._setThemeMode(mode);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: ThemeMode.light, child: Text('Light Mode')),
              const PopupMenuItem(value: ThemeMode.dark, child: Text('Dark Mode')),
              const PopupMenuItem(value: ThemeMode.system, child: Text('System Default')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
              onChanged: _onCategoryChanged,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _fromUnit,
              items: _currentUnits.map((unit) => DropdownMenuItem(value: unit, child: Text(unit))).toList(),
              onChanged: _onFromUnitChanged,
              decoration: const InputDecoration(labelText: 'From'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _toUnit,
              items: _currentUnits.map((unit) => DropdownMenuItem(value: unit, child: Text(unit))).toList(),
              onChanged: _onToUnitChanged,
              decoration: const InputDecoration(labelText: 'To'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _inputController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Value',
                prefixIcon: Icon(Icons.edit),
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _swapUnits,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Swap'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _copyResult,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Result'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('Converted Value', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text(
                    _result,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
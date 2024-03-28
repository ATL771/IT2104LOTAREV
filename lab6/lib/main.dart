import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(MaterialApp(
    home: AreaCalculator(),
  ));
}

class AreaCalculator extends StatefulWidget {
  @override
  _AreaCalculatorState createState() => _AreaCalculatorState();
}

class _AreaCalculatorState extends State<AreaCalculator> {
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  String _result = '';
  String? _widthError;
  String? _heightError;

  void _calculateArea() {
    final double? width = double.tryParse(_widthController.text);
    final double? height = double.tryParse(_heightController.text);

    setState(() {
      _widthError = null;
      _heightError = null;
    });

    if (width == null || width <= 0) {
      setState(() {
        _widthError = 'Введите корректную ширину';
      });
      return;
    }

    if (height == null || height <= 0) {
      setState(() {
        _heightError = 'Введите корректную высоту';
      });
      return;
    }

    final area = width * height;
    setState(() {
      _result = 'S = $width * $height = ${area.toStringAsFixed(2)} (мм²)';
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Вычисление успешно!'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigoAccent,
        title: Text('Калькулятор площади'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(height: 20),
            Text('Ширина (мм):'),
            TextField(
              controller: _widthController,
              decoration: InputDecoration(
                hintText: 'Введите ширину',
                errorText: _widthError,
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              onChanged: (value) {
                setState(() {
                  _widthError = null;
                });
              },
            ),
            SizedBox(height: 20),
            Text('Высота (мм):'),
            TextField(
              controller: _heightController,
              decoration: InputDecoration(
                hintText: 'Введите высоту',
                errorText: _heightError,
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              onChanged: (value) {
                setState(() {
                  _heightError = null;
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _calculateArea,
              child: Text('Вычислить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
            ),
            SizedBox(height: 20),
            Text(
              _result,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
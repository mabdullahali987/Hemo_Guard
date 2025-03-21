/// Serializes parsed CBC values and a prediction result into CSV/JSON so a
/// scan can be exported or shared from the results screen.
class ResultExporter {
  static const List<String> csvHeader = ['field', 'value', 'unit'];

  final Map<String, double> values;
  final double probability;

  const ResultExporter({required this.values, required this.probability});

  String toCsv() {
    final buffer = StringBuffer('${csvHeader.join(',')}\n');
    values.forEach((k, v) => buffer.writeln('$k,$v,'));
    buffer.writeln('thalassemia_probability,$probability,');
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
        'values': values,
        'thalassemia_probability': probability,
      };
}

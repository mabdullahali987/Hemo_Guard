import 'dart:math';

/// On-device Thalassemia predictor: a pure-Dart re-implementation of XGBoost
/// binary-logistic inference over the trees in `assets/xgboast.json`.
///
/// No Flutter dependency, so it is unit-testable on the host. The controller is
/// responsible for loading + decoding the JSON and handing the tree list here.
class ThalassemiaResult {
  final double probability; // probability of class 1 (Thalassemia)
  final bool isThalassemia;
  final double rawScore;

  const ThalassemiaResult({
    required this.probability,
    required this.isThalassemia,
    required this.rawScore,
  });
}

class ThalassemiaPredictor {
  final List<BoosterTree> trees;
  const ThalassemiaPredictor(this.trees);

  factory ThalassemiaPredictor.fromJson(List<dynamic> json) {
    return ThalassemiaPredictor(
      json
          .map((t) => BoosterTree.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isLoaded => trees.isNotEmpty;

  /// [cbc] must contain the seven raw values keyed as below.
  ThalassemiaResult predict(Map<String, double> cbc) {
    final features = _features(cbc);
    var raw = 0.0;
    for (final tree in trees) {
      raw += _traverse(tree.root, features);
    }
    final p = 1 / (1 + exp(-raw));
    return ThalassemiaResult(
      probability: p,
      isThalassemia: p > 0.5,
      rawScore: raw,
    );
  }

  /// Derived discrimination indices — the exact feature set the model was
  /// trained on (names must match the `split` fields in the tree JSON).
  static Map<String, double> _features(Map<String, double> s) {
    final rbc = s['RBC Count']!;
    final hb = s['Hemoglobin Level']!;
    final hct = s['Hematocrit']!;
    final mcv = s['MCV']!;
    final mch = s['MCH']!;
    final mchc = s['MCHC']!;
    final rdwcv = s['RDW-CV']!;

    return {
      'Kandhro 1': (rbc / hct) + (0.5 * rdwcv),
      'GaK': (mcv * mcv * rdwcv) / (100 * hb),
      'MCHC': mchc,
      'EaF': mcv - rbc - (5 * hb),
      'RDW-CV': rdwcv,
      'MCH': mch,
      'MI': mcv / rbc,
      'EaF2': mcv - rbc - (5 * hb) - 3.4,
      'Bessman': rdwcv,
      'RBC Count': rbc,
      'Sirdah': mcv - rbc - (3 * hb),
      'MaC': (1.91 * rbc) + (0.44 * mchc),
      'Keikhaei': (hb * rdwcv * 100) / (rbc * rbc * mchc),
      'Hematocrit': hct,
      'Wongprachum': (mcv * rdwcv / rbc) - (10 * hb),
      'Hemoglobin Level': hb,
      'Srivastava': mch / rbc,
      'MCV': mcv,
    };
  }

  static double _traverse(TreeNode node, Map<String, double> input) {
    var current = node;
    while (current.leaf == null) {
      final value = input[current.split];
      final int nextId;
      if (value == null) {
        nextId = current.missing!;
      } else if (value < current.splitCondition!) {
        nextId = current.yes!;
      } else {
        nextId = current.no!;
      }
      final children = current.children;
      if (children == null) return 0.0;
      TreeNode? next;
      for (final c in children) {
        if (c.nodeId == nextId) {
          next = c;
          break;
        }
      }
      if (next == null) return 0.0;
      current = next;
    }
    return current.leaf!;
  }
}

class BoosterTree {
  final TreeNode root;
  const BoosterTree({required this.root});

  factory BoosterTree.fromJson(Map<String, dynamic> json) {
    return BoosterTree(root: TreeNode.fromJson(json['node'] as Map<String, dynamic>));
  }
}

class TreeNode {
  final int? nodeId;
  final String? split;
  final double? splitCondition;
  final double? leaf;
  final int? yes;
  final int? no;
  final int? missing;
  final List<TreeNode>? children;

  const TreeNode({
    this.nodeId,
    this.split,
    this.splitCondition,
    this.leaf,
    this.yes,
    this.no,
    this.missing,
    this.children,
  });

  factory TreeNode.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('leaf')) {
      return TreeNode(
        nodeId: json['nodeid'] as int?,
        leaf: (json['leaf'] as num).toDouble(),
      );
    }
    return TreeNode(
      nodeId: json['nodeid'] as int?,
      split: json['split'] as String?,
      splitCondition: json['split_condition'] != null
          ? (json['split_condition'] as num).toDouble()
          : 0.0,
      yes: json['yes'] as int?,
      no: json['no'] as int?,
      missing: json['missing'] as int?,
      children: (json['children'] as List<dynamic>?)
          ?.map((c) => TreeNode.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

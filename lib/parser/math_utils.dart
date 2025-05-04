import 'package:html/dom.dart' as dom;

class MathUtils {
  static final Map<String, String> _mathML2Tex = {
    "sin": r"\sin",
    "sinh": r"\sinh",
    "csc": r"\csc",
    "csch": r"csch",
    "cos": r"\cos",
    "cosh": r"\cosh",
    "sec": r"\sec",
    "sech": r"\sech",
    "tan": r"\tan",
    "tanh": r"\tanh",
    "cot": r"\cot",
    "coth": r"\coth",
    "log": r"\log",
    "ln": r"\ln",
    "{": r"\{",
    "}": r"\}",
  };
  static String parseMathRecursive(dom.Node node, [String parsed = ""]) {
    if (node.nodeType == dom.Node.TEXT_NODE) {
      return parsed + node.text!.trim();
    }

    if (node is dom.Element) {
      List<dom.Element> nodeList = node.nodes.whereType<dom.Element>().toList();
      if (node.localName == "semantics") {
        // Usually the first child is the one you want to render.
        final dom.Element? contentNode = node.children.firstWhere(
          (child) =>
              child.localName != "annotation" &&
              child.localName != "annotation-xml",
          orElse: () => node.children.first,
        );

        if (contentNode != null) {
          parsed = parseMathRecursive(contentNode, parsed);
        }
      }
      if (node.localName == "math" ||
          node.localName == "mrow" ||
          node.localName == "mtr") {
        if (node.localName == "math" && nodeList.isEmpty) {
          return parsed + node.text.trim();
        }
        for (var element in nodeList) {
          parsed = parseMathRecursive(element, parsed);
        }
      }
      // note: munder, mover, and munderover do not support placing braces and other
      // markings above/below elements, instead they are treated as super/subscripts for now.
      if ((node.localName == "msup" ||
              node.localName == "msub" ||
              node.localName == "munder" ||
              node.localName == "mover") &&
          nodeList.length == 2) {
        parsed = parseMathRecursive(nodeList[0], parsed);
        parsed =
            "${parseMathRecursive(nodeList[1], "$parsed${node.localName == "msup" || node.localName == "mover" ? "^" : "_"}{")}}";
      }
      if ((node.localName == "msubsup" || node.localName == "munderover") &&
          nodeList.length == 3) {
        parsed = parseMathRecursive(nodeList[0], parsed);
        parsed = "${parseMathRecursive(nodeList[1], "${parsed}_{")}}";
        parsed = "${parseMathRecursive(nodeList[2], "$parsed^{")}}";
      }
      if (node.localName == "mfrac" && nodeList.length == 2) {
        parsed = "${parseMathRecursive(nodeList[0], parsed + r"\frac{")}}";
        parsed = "${parseMathRecursive(nodeList[1], "$parsed{")}}";
      }
      // note: doesn't support answer & intermediate steps
      if (node.localName == "mlongdiv" && nodeList.length == 4) {
        parsed = parseMathRecursive(nodeList[0], parsed);
        parsed = "${parseMathRecursive(nodeList[2], parsed + r"\overline{)")}}";
      }
      if (node.localName == "msqrt") {
        parsed = parsed + r"\sqrt{";
        for (var element in nodeList) {
          parsed = parseMathRecursive(element, parsed);
        }
        parsed = "$parsed}";
      }
      if (node.localName == "mroot" && nodeList.length == 2) {
        parsed = "${parseMathRecursive(nodeList[1], parsed + r"\sqrt[")}]";
        parsed = "${parseMathRecursive(nodeList[0], "$parsed{")}}";
      }
      if (node.localName == "mfenced") {
        String inner =
            nodeList.map((e) => parseMathRecursive(e, '')).join(', ');
        parsed = "$parsed\\left($inner\\right)";
      }
      if (node.localName == "mi" ||
          node.localName == "mn" ||
          node.localName == "mo") {
        if (_mathML2Tex.keys.contains(node.text.trim())) {
          parsed = parsed + _mathML2Tex[node.text.trim()]!;
        } else if (node.text.startsWith("&") && node.text.endsWith(";")) {
          parsed = parsed +
              node.text
                  .trim()
                  .replaceFirst("&", r"\")
                  .substring(0, node.text.trim().length - 1);
        } else {
          parsed = parsed + node.text.trim();
        }
      }
      if (node.localName == 'mtable') {
        String inner =
            nodeList.map((e) => parseMathRecursive(e, '')).join(' \\\\');
        parsed = '$parsed\\begin{matrix}$inner\\end{matrix}';
      }
      if (node.localName == "mtd") {
        for (var element in nodeList) {
          parsed = parseMathRecursive(element, parsed);
        }
        parsed = '$parsed & ';
      }
      if (node.localName == "mmultiscripts") {
        String base = parseMathRecursive(nodeList[0], "");
        String preSubScripts = "";
        String preSuperScripts = "";
        String postSubScripts = "";
        String postSuperScripts = "";
        bool isPostScripts = true;
        bool isSubScripts = true;
        for (var element in nodeList.skip(1)) {
          if (element.localName == "mprescripts") {
            isPostScripts = false;
            isSubScripts = true;
            continue;
          }

          if (isPostScripts) {
            if (isSubScripts) {
              postSubScripts = parseMathRecursive(element, postSubScripts);
            } else {
              postSuperScripts = parseMathRecursive(element, postSuperScripts);
            }
          } else {
            if (isSubScripts) {
              preSubScripts = parseMathRecursive(element, preSubScripts);
            } else {
              preSuperScripts = parseMathRecursive(element, preSuperScripts);
            }
          }
          isSubScripts = !isSubScripts;
        }
        if (preSubScripts.isNotEmpty) {
          preSubScripts = "_$preSubScripts";
        }
        if (preSuperScripts.isNotEmpty) {
          preSuperScripts = "^$preSuperScripts";
        }
        if (postSubScripts.isNotEmpty) {
          postSubScripts = "_$postSubScripts";
        }
        if (postSuperScripts.isNotEmpty) {
          postSuperScripts = "^$postSuperScripts";
        }
        parsed =
            "$parsed{}$preSubScripts$preSuperScripts $base$postSubScripts$postSuperScripts ";
      }
    }
    return parsed;
  }
}

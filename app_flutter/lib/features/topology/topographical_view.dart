import 'package:flutter/material.dart';
import 'package:app_flutter/features/layout/breadcrumbs.dart';
import 'package:app_flutter/features/topology/topology_map.dart';
import 'package:app_flutter/features/layout/split_workspace.dart';
import 'package:app_flutter/features/tree/tree_node.dart';

/// The top-level topology view: breadcrumb header + split workspace
/// (topology map + detail child) or standalone topology map.
///
/// If [child] is non-null, the view uses [SplitWorkspace] to show the
/// topology map alongside a detail pane (e.g. property grid). When [child]
/// is null, the topology map takes the full area below the header.
///
/// The split pane behaviour can be tuned via [splitDirection],
/// [splitMinFirstPaneSize], [splitInitialRatio], and [splitterKey] — see
/// each field's documentation for details.
///
/// Edge cases: empty [treeData] produces no breadcrumbs; unknown
/// [currentView] IDs still render the header label as-is. When total
/// available size is less than [splitMinFirstPaneSize], the first pane
/// takes its minimum and the trailing pane fills the remainder (which
/// may be smaller than [splitMinFirstPaneSize]).
class TopographicalView extends StatelessWidget {
  final String currentView;
  final ValueChanged<String> onViewSelected;
  final Widget? child;
  final TopologyData topologyData;
  final List<TreeNode> treeData;
  /// The axis along which the split panes are laid out.
  ///
  /// [Axis.vertical] stacks panes vertically (top = map, bottom = child);
  /// [Axis.horizontal] places them side-by-side.
  ///
  /// Defaults to [Axis.vertical].
  final Axis splitDirection;

  /// The minimum size, in logical pixels, of the first (leading) pane.
  ///
  /// The pane is clamped between this value and
  /// (`totalSize - [splitMinFirstPaneSize]`). When the total available
  /// size is smaller than this value, the first pane still takes
  /// [splitMinFirstPaneSize] pixels and the trailing pane receives
  /// whatever remains (may be zero or negative in overflow scenarios).
  ///
  /// Defaults to `150.0`.
  final double splitMinFirstPaneSize;

  /// The initial fraction of total size assigned to the first pane.
  ///
  /// Applied once during the first layout pass when available size > 0.
  /// After initialization the user can resize the splitter, and the ratio
  /// is clamped by [splitMinFirstPaneSize].
  ///
  /// Must be in the range 0.0–1.0; values outside are silently
  /// constrained by the subsequent clamp.
  ///
  /// Defaults to `0.4`.
  final double splitInitialRatio;

  /// The [Key] used to identify the draggable splitter [GestureDetector].
  ///
  /// Useful for widget testing — pass a unique [ValueKey] or similar so
  /// the splitter can be found with `find.byKey()`.
  ///
  /// Defaults to `Key('topo_splitter')`.
  final Key splitterKey;

  const TopographicalView({
    super.key,
    required this.currentView,
    required this.onViewSelected,
    this.child,
    required this.topologyData,
    this.treeData = const [],
    this.splitDirection = Axis.vertical,
    this.splitMinFirstPaneSize = 150.0,
    this.splitInitialRatio = 0.4,
    this.splitterKey = const Key('topo_splitter'),
  });

  @override
  Widget build(BuildContext context) {
    final body = child != null
        ? SplitWorkspace(
            leading: TopologyMap(
              activeFocusedNode: currentView,
              onNodeSelect: onViewSelected,
              data: topologyData,
            ),
            trailing: child!,
            direction: splitDirection,
            minFirstPaneSize: splitMinFirstPaneSize,
            initialRatio: splitInitialRatio,
            splitterKey: splitterKey,
          )
        : TopologyMap(
            activeFocusedNode: currentView,
            onNodeSelect: onViewSelected,
            data: topologyData,
          );

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Active View Title & Breadcrumbs Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active View: $currentView',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: NavigationBreadcrumbs(
                      items: getBreadcrumbsItems(currentView, treeData, onSelectView: onViewSelected),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:app_flutter/features/layout/breadcrumbs.dart';
import 'package:app_flutter/features/topology/topology_map.dart';
import 'package:app_flutter/features/layout/split_workspace.dart';
import 'package:app_flutter/features/tree/tree_node.dart';
import 'package:app_flutter/features/topology/scene_3d_viewport.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';

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
class TopographicalView extends StatefulWidget {
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
  State<TopographicalView> createState() => _TopographicalViewState();
}

class _TopographicalViewState extends State<TopographicalView> {
  bool _is3d = true;

  @override
  Widget build(BuildContext context) {
    double latitude;
    double longitude;

    TopologyNode? activeNode;
    for (final node in widget.topologyData.nodes) {
      if (node.id == widget.currentView) {
        activeNode = node;
        break;
      }
    }

    if (activeNode != null) {
      final double latVal = activeNode.resolveCoordinate('y', widget.topologyData.coordinateMapping);
      final double lngVal = activeNode.resolveCoordinate('x', widget.topologyData.coordinateMapping);
      if (latVal == 0.0 && lngVal == 0.0) {
        latitude = 35.6074;
        longitude = 140.1063;
      } else {
        latitude = latVal;
        longitude = lngVal;
      }
    } else {
      latitude = 35.6074;
      longitude = 140.1063;
    }

    latitude = latitude.clamp(-90.0, 90.0);
    longitude = longitude.clamp(-180.0, 180.0);

    final camera = VirtualCamera(
      latitude: latitude,
      longitude: longitude,
      altitude: 500.0,
      heading: 0.0,
      pitch: -45.0,
      roll: 0.0,
    );

    final Widget leadingWidget = _is3d
        ? Scene3DViewport(camera: camera)
        : TopologyMap(
            activeFocusedNode: widget.currentView,
            onNodeSelect: widget.onViewSelected,
            data: widget.topologyData,
          );

    final body = widget.child != null
        ? SplitWorkspace(
            leading: leadingWidget,
            trailing: widget.child!,
            direction: widget.splitDirection,
            minFirstPaneSize: widget.splitMinFirstPaneSize,
            initialRatio: widget.splitInitialRatio,
            splitterKey: widget.splitterKey,
          )
        : leadingWidget;

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
                Flexible(
                  child: Text(
                    'Active View: ${widget.currentView}',
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      key: const Key('toggle_2d'),
                      onPressed: () => setState(() => _is3d = false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !_is3d ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                        foregroundColor: !_is3d ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                      ),
                      child: const Text('2D Map'),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton(
                      key: const Key('toggle_3d'),
                      onPressed: () => setState(() => _is3d = true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _is3d ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                        foregroundColor: _is3d ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                      ),
                      child: const Text('3D Globe'),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: NavigationBreadcrumbs(
                      items: getBreadcrumbsItems(widget.currentView, widget.treeData, onSelectView: widget.onViewSelected),
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

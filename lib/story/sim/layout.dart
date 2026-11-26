import '../../sim/vec.dart';

/// Round screen layout: a 390 x 844 logical canvas, origin top left, scaled
/// to fit and letterboxed. Enemies come down the fairway, the build zone sits
/// in front of the golfer, and the golfer and ball are near the bottom.
abstract final class StoryLayout {
  static const double width = 390;
  static const double height = 844;

  /// HUD: flags, health, coins, wave, Fore! meter, pause.
  static const Box hud = Box(0, 0, width, 80);

  /// Enemies, hazards and balls.
  static const Box fairway = Box(0, 80, width, 550);

  /// Enemies enter no lower than this fraction of the way down the fairway.
  static const double spawnDepth = 1 / 3;

  /// Lowest y an enemy may spawn at: at least 2/3 of the way up the fairway.
  static double get spawnMaxY => fairway.top + fairway.height * spawnDepth;

  static const int plotCols = 6;

  /// Rows 1-2 are always open; row 0 (the front row, closest to the fairway)
  /// opens one plot per Grounds Crew upgrade.
  static const int plotRows = 3;
  static const double plotSize = 56;

  /// The order the front-row plots open in: centre outward.
  static const List<int> expansionOrder = [2, 3, 1, 4, 0, 5];

  /// The build zone (all 3 rows), in front of the ball.
  static const Box teeBox = Box(27, 560, 27 + plotCols * plotSize, 560 + plotRows * plotSize);

  /// Swing origin and the ball enemies attack.
  static const V2 golfer = V2(195, 768);

  /// Enemies standing within this of the ball attack it.
  static const double ballReach = 14;

  /// 3 club buttons, Fore! and the caddie button.
  static const Box clubBar = Box(0, 794, width, height);

  /// Enemies spawn on the top edge or the upper side edges.
  static const double spawnTop = 80;

  /// Bottom of the area enemies can walk in.
  static const double fieldBottom = 790;

  /// Radius of a tower on its plot.
  static const double towerRadius = plotSize * 0.36;

  /// Plots that exist with [extra] front-row plots opened (6 x 2 to start).
  static bool plotOpen(int col, int row, int extra) {
    if (col < 0 || col >= plotCols || row < 0 || row >= plotRows) return false;
    return row >= 1 || expansionOrder.take(extra).contains(col);
  }

  /// The front-most open row of a column (where front-row-only towers go).
  static int frontRow(int col, int extra) => plotOpen(col, 0, extra) ? 0 : 1;

  static int plotCount(int extra) => plotCols * (plotRows - 1) + extra.clamp(0, plotCols);

  static Box plot(int col, int row) =>
      Box(teeBox.left + col * plotSize, teeBox.top + row * plotSize, teeBox.left + (col + 1) * plotSize, teeBox.top + (row + 1) * plotSize);

  static V2 plotCenter(int col, int row) => plot(col, row).center;

  /// The plot under [p], or null. Row 0 is the front row (nearest the fairway).
  static (int, int)? plotAt(V2 p) {
    if (!teeBox.contains(p)) return null;
    final col = ((p.x - teeBox.left) / plotSize).floor().clamp(0, plotCols - 1);
    final row = ((p.y - teeBox.top) / plotSize).floor().clamp(0, plotRows - 1);
    return (col, row);
  }

  /// Distance from [p] to the build zone (0 inside it).
  static double distanceToTeeBox(V2 p) => teeBox.clamp(p).distanceTo(p);
}

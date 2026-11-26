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
  static const Box fairway = Box(0, 80, width, 500);

  static const int plotCols = 4;
  static const int plotRows = 4;
  static const double plotSize = 56;

  /// The build zone: a 4x4 grid of plots in front of the ball.
  static const Box teeBox = Box(83, 510, 83 + plotCols * plotSize, 510 + plotRows * plotSize);

  /// Swing origin and the ball enemies attack.
  static const V2 golfer = V2(195, 768);

  /// Enemies standing within this of the ball attack it.
  static const double ballReach = 14;

  /// 3 club buttons, Fore! and the caddie button.
  static const Box clubBar = Box(0, 794, width, height);

  /// Enemies spawn on the top edge or the side edges.
  static const double spawnTop = 80;

  /// Bottom of the area enemies can walk in.
  static const double fieldBottom = 790;

  /// Radius of a tower on its plot.
  static const double towerRadius = plotSize * 0.36;

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

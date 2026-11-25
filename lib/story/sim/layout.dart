import '../../sim/vec.dart';

/// Story Mode screen layout (6a.3): a 390 x 844 logical canvas, origin top left,
/// scaled to fit and letterboxed.
abstract final class StoryLayout {
  static const double width = 390;
  static const double height = 844;

  /// HUD: flags, health, coins, wave, Fore! meter, pause.
  static const Box hud = Box(0, 0, width, 80);

  /// Enemies, hazards and balls.
  static const Box fairway = Box(0, 80, width, 540);

  /// Swing origin.
  static const V2 golfer = V2(195, 548);

  /// Enemies attack the tee box: any point at this y.
  static const double teeLine = 570;

  static const int plotCols = 4;
  static const int plotRows = 4;
  static const double plotSize = 56;
  static const Box teeBox = Box(83, 570, 83 + plotCols * plotSize, 570 + plotRows * plotSize);

  /// 3 club buttons, Fore! and the caddie button.
  static const Box clubBar = Box(0, 794, width, height);

  /// Enemies spawn on the top edge or the side edges between these y values.
  static const double spawnTop = 80;

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

  /// Distance from [p] to the tee box (0 inside it).
  static double distanceToTeeBox(V2 p) => teeBox.clamp(p).distanceTo(p);
}

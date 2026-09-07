/// Optional interface a session can implement to expose a reading-direction
/// toggle (RTL comics). UI shows the toggle via type check rather than a
/// format-string branch.
abstract interface class ReaderDirectionTogglable {
  Future<void> toggleDirection();
}

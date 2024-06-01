import XCTest
import Appearance

final class AppearanceTests: XCTestCase {
 func test() async throws {
  // using the `command` interface allows xcode to ask for permissions where
  // using `event` will tests to crash, unlike running in a normal app
  try await Appearance.Mode.toggle(with: .command)
  try await Appearance.Mode.toggle(with: .event)
 }
}

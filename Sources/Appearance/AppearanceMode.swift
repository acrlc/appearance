public extension Appearance {
 struct Mode:
  RawRepresentable,
  CustomStringConvertible,
  CaseIterable,
  Hashable,
  Equatable,
  Identifiable,
  ExpressibleByNilLiteral {
  public var id: Self { self }
  public var rawValue: String = "auto"

  public init(rawValue: String) {
   assert(
    ["auto", "light", "dark"].contains(rawValue),
    "invalid mode for the current system"
   )
   self.rawValue = rawValue
  }

  @_disfavoredOverload
  public init() { self = .auto }
  public init(nilLiteral: ()) { self = .auto }

  public var inverted: Self {
   self == .dark
    ? .light
    : self == .light ? .dark : .auto
  }

  public var description: String { rawValue }

  public static let auto = Self(rawValue: "auto")
  public static let light = Self(rawValue: "light")
  public static let dark = Self(rawValue: "dark")

  public static var allCases: [Self] = [.auto, .light, .dark]
 }
}

public typealias Mode = Appearance.Mode

#if os(macOS)
import Foundation

public extension Appearance.Mode {
 // The current appearance mode
 static var defaultValue: Self { .current() }

 /// The current theme which is either light or dark
 @MainActor(unsafe)
 static func current() -> Self {
  switch UserDefaults.standard.interfaceStyle?.lowercased() {
  case .some(let string): Self(rawValue: string)
  case .none: .light
  }
 }

 struct AppearanceModeError: LocalizedError, CustomStringConvertible {
  let message: String

  public init(message: String) {
   self.message = message
  }

  public var description: String {
   "\(Self.self): \(message)"
  }

  public var errorDescription: String? {
   description
  }
 }

 enum SetMethod: Equatable {
  case event, command
 }

 /// A script for toggling using apple events
 static func script(with mode: Appearance.Mode) -> String {
  #if DEBUG
  let usageDescription = (
   Bundle.main.infoDictionary?["NSAppleEventsUsageDescription"] as? String
  )
  if usageDescription == nil || usageDescription!.isEmpty {
   print(
    """
    The app's Info.plist must contain an “NSAppleEventsUsageDescription” key \
    with a string value explaining to the user why
    """
   )
  }
  #endif

  let setter: String =
   mode == dark
    ? true.description
    : mode == .auto ? "not dark mode" : false.description
  return
   """
   tell app \"System Events\" to tell appearance preferences to set dark mode \
   to \(setter)
   """
 }

 static func set(to mode: Self, with method: SetMethod) async throws {
  try await MainActor.run {
   if method == .command {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script(with: mode)]
    try process.run()
    process.waitUntilExit()
   } else if method == .event {
    let source = script(with: mode)
    guard
     let appScript = NSAppleScript(source: source) else {
     fatalError("invalid source for script '\(source)'")
    }
    var dictionary: NSDictionary?
    try withUnsafeMutablePointer(to: &dictionary) {
     let ptr = AutoreleasingUnsafeMutablePointer<NSDictionary?>($0)
     appScript.executeAndReturnError(ptr)
     if let dictionary = $0.pointee {
      throw AppearanceModeError(
       message:
       dictionary["NSAppleScriptErrorMessage"] as! String
      )
     }
     $0.pointee = nil
    }
   }
  }
 }

 /// Toggles the current system appearance mode
 @discardableResult
 static func toggle(with method: SetMethod) async throws -> Self {
  try await current().toggle(with: method)
 }

 /// Toggles the current system appearance mode
 /// Does nothing if set to auto mode
 @discardableResult
 func toggle(with method: SetMethod) async throws -> Self {
  switch self {
  case .dark:
   try await Self.set(to: .light, with: method)
   return .light
  case .light:
   try await Self.set(to: .dark, with: method)
   return .dark
  default: return self
  }
 }
}

public extension UserDefaults {
 @objc
 dynamic var interfaceStyle: String? {
  string(forKey: "AppleInterfaceStyle")
 }
}

extension NSDictionary: @unchecked Sendable {}
#endif

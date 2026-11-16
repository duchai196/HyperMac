import Foundation

public enum AppConfig {
    public static let version: String = "1.9.4"
}

@MainActor
public class DonateManager: ObservableObject {
    public static let shared = DonateManager()

    @Published public var showDonateModal: Bool = false

    private init() {}
}


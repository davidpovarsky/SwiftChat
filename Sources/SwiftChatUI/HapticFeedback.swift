#if canImport(UIKit)
import UIKit

enum HapticFeedback {
    enum FeedbackType {
        case error
        case success
    }

    static func trigger(_ type: FeedbackType) {
        let enabled = UserDefaults.standard.object(
            forKey: "hapticFeedbackEnabled"
        ) as? Bool ?? true
        guard enabled else { return }

        let generator = UINotificationFeedbackGenerator()
        switch type {
        case .error:
            generator.notificationOccurred(.error)
        case .success:
            generator.notificationOccurred(.success)
        }
    }
}
#endif

import UIKit

class HapticManager {
    static let shared = HapticManager()

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        notificationGenerator.prepare()
    }

    func lightImpact()  { lightGenerator.impactOccurred() }
    func mediumImpact() { mediumGenerator.impactOccurred() }
    func heavyImpact()  { heavyGenerator.impactOccurred() }
    func success()      { notificationGenerator.notificationOccurred(.success) }
    func error()        { notificationGenerator.notificationOccurred(.error) }
}

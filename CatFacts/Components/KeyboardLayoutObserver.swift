import UIKit

@MainActor
final class KeyboardLayoutObserver: NSObject {
    var bottomInset: CGFloat {
        guard let view else { return 0 }
        return max(0, overlap - view.safeAreaInsets.bottom)
    }

    private weak var view: UIView?
    private var overlap: CGFloat = 0

    init(view: UIView) {
        self.view = view
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardFrameDidChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func keyboardFrameDidChange(_ notification: Notification) {
        guard let view, view.window != nil,
              let userInfo = notification.userInfo,
              let frame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let keyboardFrame = view.convert(frame, from: nil)
        overlap = keyboardFrame.maxY >= view.bounds.maxY
            ? max(0, view.bounds.maxY - keyboardFrame.minY)
            : 0
        view.setNeedsLayout()
        if UIAccessibility.isReduceMotionEnabled {
            UIView.performWithoutAnimation {
                view.layoutIfNeeded()
            }
            return
        }
        let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0
        let options = UIView.AnimationOptions(rawValue: curve << 16).union(.beginFromCurrentState)
        UIView.animate(withDuration: duration, delay: 0, options: options) {
            view.layoutIfNeeded()
        }
    }
}

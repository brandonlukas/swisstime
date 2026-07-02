import UIKit

/// Hiding the default back button (for our custom arrow) also disables the
/// system edge-swipe back gesture; this hands the recognizer a delegate that
/// re-enables it whenever there is somewhere to pop back to.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}

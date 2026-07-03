import SwiftUI
import UIKit

/// Pull the page down to leave — for full-screen covers presented over a
/// clear backdrop (player, pond). The paper lifts with the finger and the
/// screen behind shows through; past the threshold (or on a committed
/// flick) it dismisses, otherwise it springs back. Vertical pulls only,
/// so horizontal drags stay with whatever is underneath.
///
/// The shadow hangs on the flattened opaque paper alone — shadowing the
/// whole hierarchy would make every sublayer cast one, darkening the
/// entire screen.
struct PullToDismiss: ViewModifier {
    @Binding var offset: CGFloat
    /// Checked per drag event, so callers can gate on live state
    /// (the player allows the pull only once the workout is finished).
    var isEnabled = true
    /// How far the finger must travel before the pull engages — raise it
    /// when the page has gestures of its own to protect.
    var minimumDistance: CGFloat = 20
    /// Simultaneous recognition lets an underlying pager or scroll view
    /// keep its own drags (the pond's month pages).
    var simultaneous = false
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        let lifted = content
            .background(
                PaperBackground()
                    .compositingGroup()
                    .shadow(color: .black.opacity(offset > 0 ? 0.18 : 0), radius: 24, y: -8)
            )
            .offset(y: offset)
            .presentationBackground(.clear)
        if simultaneous {
            lifted.simultaneousGesture(drag)
        } else {
            lifted.gesture(drag)
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: minimumDistance)
            .onChanged { value in
                guard isEnabled,
                      value.translation.height > abs(value.translation.width) else { return }
                offset = max(0, value.translation.height)
            }
            .onEnded { value in
                guard offset > 0 else { return }
                if offset > 120 || value.predictedEndTranslation.height > 300 {
                    onDismiss()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        offset = 0
                    }
                }
            }
    }
}

extension View {
    func pullToDismiss(offset: Binding<CGFloat>, isEnabled: Bool = true,
                       minimumDistance: CGFloat = 20, simultaneous: Bool = false,
                       onDismiss: @escaping () -> Void) -> some View {
        modifier(PullToDismiss(offset: offset, isEnabled: isEnabled,
                               minimumDistance: minimumDistance,
                               simultaneous: simultaneous, onDismiss: onDismiss))
    }
}

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

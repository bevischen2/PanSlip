import UIKit

public protocol PanSlipBehavior: AnyObject {
    var percentThreshold: CGFloat? { get }
}

extension PanSlipBehavior {
    var percentThreshold: CGFloat? {
        return nil
    }
}

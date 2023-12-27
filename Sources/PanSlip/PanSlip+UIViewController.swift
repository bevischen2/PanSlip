import UIKit

private var slipDirectionContext: UInt8 = 0
private var slipCompletionContext: UInt8 = 0

private var panSlipViewControllerProxyContext: UInt8 = 0

extension PanSlip where Base: UIViewController {
    
    // MARK: - Properties
    
    private(set) var slipDirection: PanSlipDirection? {
        get {
            return objc_getAssociatedObject(base, &slipDirectionContext, defaultValue: nil)
        }
        set {
            objc_setAssociatedObject(base, &slipDirectionContext, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    private(set) var slipCompletion: (() -> Void)? {
        get {
            return objc_getAssociatedObject(base, &slipCompletionContext, defaultValue: nil)
        }
        set {
            objc_setAssociatedObject(base, &slipCompletionContext, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private var viewControllerProxy: PanSlipViewControllerProxy? {
        get {
            return objc_getAssociatedObject(base, &panSlipViewControllerProxyContext, defaultValue: nil)
        }
        set {
            objc_setAssociatedObject(base, &panSlipViewControllerProxyContext, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // MARK: - Public methods
    
    public func enable(slipDirection: PanSlipDirection, slipCompletion: (() -> Void)? = nil) {
        self.slipDirection = slipDirection
        self.slipCompletion = slipCompletion
        
        if viewControllerProxy == nil {
            viewControllerProxy = PanSlipViewControllerProxy(viewController: base,
                                                             slipDirection: slipDirection,
                                                             slipCompletion: slipCompletion)
            viewControllerProxy?.configure()
        }
    }
    
    /// Enable edge pan slip with the specified configuration.
    /// - Parameters:
    ///   - slipDirection: The direction in which the pan slip should occur.
    ///   - slipCompletion: A closure to be executed upon completion of the pan slip.
    public func enableEdge(slipDirection: PanSlipDirection, slipCompletion: (() -> Void)? = nil) {
        self.slipDirection = slipDirection
        self.slipCompletion = slipCompletion
        
        if viewControllerProxy == nil {
            viewControllerProxy = PanSlipViewControllerProxy(viewController: base,
                                                             useEdgePanGesture: true,
                                                             slipDirection: slipDirection,
                                                             slipCompletion: slipCompletion)
            viewControllerProxy?.configure()
        }
    }
    
    public func disable() {
        slipDirection = nil
        slipCompletion = nil
        
        viewControllerProxy = nil
    }
    
    public func slip(animated: Bool) {
        defer {
            viewControllerProxy?.unconfigure()
            slipCompletion?()
        }
        
        viewControllerProxy?.interactiveTransition.hasStarted = true
        base.dismiss(animated: true, completion: nil)
        
        viewControllerProxy?.interactiveTransition.shouldFinish = true
        viewControllerProxy?.interactiveTransition.hasStarted = false
        viewControllerProxy?.interactiveTransition.finish()
    }
    
    /// Call this method in your view controller containing a scroll view to configure pan gestures and determine which pan gesture will be enabled.
    /// - Parameters:
    ///   - gesture: The pan gesture recognizer to configure.
    ///   - shouldBeginHandler: A closure that returns a Boolean indicating whether the gesture should begin.
    public func disableSlipConflicts(with gesture: UIPanGestureRecognizer, shouldBeginHandler handler: (()->Bool)?) {
        guard let viewControllerProxy else { return }
        viewControllerProxy.disablePanGestureConflicts(with: gesture, shouldBeginHandler: handler)
    }

}

// MARK: - PanSlipViewControllerProxy

private class PanSlipViewControllerProxy: NSObject {
    
    // MARK: - Properties
    
    let interactiveTransition = InteractiveTransition()
    
    private unowned let viewController: UIViewController
    private var slipDirection: PanSlipDirection?
    private var useEdgePanGesture: Bool = false
    private var slipCompletion: (() -> Void)?
    private var slipShouldBeginHandler: (() -> Bool)?
    
    var panGesture: UIPanGestureRecognizer { _panGesture }
    private lazy var _panGesture: UIPanGestureRecognizer = {
        guard useEdgePanGesture, let slipDirection else {
            return UIPanGestureRecognizer(target: self, action: #selector(panGesture(_:)))
        }
        
        var panGesture: UIScreenEdgePanGestureRecognizer = .init(target: self, action: #selector(panGesture(_:)))
        
        switch slipDirection {
        case .leftToRight:
            panGesture.edges = .left
        case .rightToLeft:
            panGesture.edges = .right
        case .topToBottom:
            panGesture.edges = .top
        case .bottomToTop:
            panGesture.edges = .bottom
        }
        
        return panGesture
    }()
    
    
    // MARK: - Con(De)structor
    
    init(viewController: UIViewController, slipDirection: PanSlipDirection, slipCompletion: (() -> Void)?) {
        self.viewController = viewController
        super.init()
        
        self.slipDirection = slipDirection
        self.slipCompletion = slipCompletion
        viewController.transitioningDelegate = self
    }
    
    /// Convenience initializer to create a PanSlipViewController with additional configuration options.
    /// - Parameters:
    ///   - viewController: The main view controller to be embedded.
    ///   - useEdgePanGesture: A flag indicating whether to use UIScreenEdgePanGestureRecognizer.
    ///   - slipDirection: The direction in which the pan slip should occur.
    ///   - slipCompletion: A closure to be executed upon completion of the pan slip.
    convenience init(viewController: UIViewController, useEdgePanGesture: Bool, slipDirection: PanSlipDirection, slipCompletion: (() -> Void)?) {
        self.init(viewController: viewController, slipDirection: slipDirection, slipCompletion: slipCompletion)
        self.useEdgePanGesture = useEdgePanGesture
    }
    
    // MARK: - Internal methods
    
    func configure() {
        viewController.view.addGestureRecognizer(panGesture)
    }
    
    func unconfigure() {
        viewController.transitioningDelegate = nil
        viewController.view.removeGestureRecognizer(panGesture)
    }
    
    /// Configure pan gestures to avoid conflicts and set a handler to determine if the slip should begin.
    /// - Parameters:
    ///   - gesture: The pan gesture recognizer to configure.
    ///   - shouldBeginHandler: A closure that returns a Boolean indicating whether the slip should begin.
    func disablePanGestureConflicts(with gesture: UIPanGestureRecognizer, shouldBeginHandler handler: (()->Bool)?) {
        panGesture.delegate = self
        gesture.require(toFail: panGesture)
        slipShouldBeginHandler = handler
    }
    
    // MARK: - Private selector
    
    @objc private func panGesture(_ sender: UIPanGestureRecognizer) {
        guard let slipDirection = slipDirection else { return }
        
        let translation = sender.translation(in: viewController.view)
        let size = viewController.view.bounds
        var movementPercent: CGFloat?
        switch slipDirection {
        case .leftToRight:
            movementPercent = translation.x / size.width
        case .rightToLeft:
            movementPercent = -(translation.x / size.width)
        case .topToBottom:
            movementPercent = translation.y / size.height
        case .bottomToTop:
            movementPercent = -(translation.y / size.height)
        }
        
        guard let movement = movementPercent else {return}
        let downwardMovementPercent = fminf(fmaxf(Float(movement), 0.0), 1.0)
        let progress = CGFloat(fminf(downwardMovementPercent, 1.0))
        switch sender.state {
        case .began:
            interactiveTransition.hasStarted = true
            viewController.dismiss(animated: true, completion: nil)
        case .changed:
            let percentThreshold: CGFloat = (viewController as? PanSlipBehavior)?.percentThreshold ?? 0.3
            interactiveTransition.shouldFinish = progress > percentThreshold
            interactiveTransition.update(progress)
        case .cancelled:
            interactiveTransition.hasStarted = false
            interactiveTransition.cancel()
        case .ended:
            interactiveTransition.hasStarted = false
            interactiveTransition.shouldFinish ? interactiveTransition.finish() : interactiveTransition.cancel()
            if interactiveTransition.shouldFinish {
                unconfigure()
                slipCompletion?()
            }
        default:
            break
        }
    }
    
}

// MARK: - UIViewControllerTransitioningDelegate

extension PanSlipViewControllerProxy: UIViewControllerTransitioningDelegate {
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        guard let slipDirection = slipDirection, interactiveTransition.hasStarted == true else {return nil}
        return PanSlipAnimator(direction: slipDirection)
    }
    
    public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactiveTransition.hasStarted ? interactiveTransition : nil
    }
    
}

// MARK: - UIGestureRecognizerDelegate

extension PanSlipViewControllerProxy: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        (slipShouldBeginHandler != nil) ? slipShouldBeginHandler!() : false
    }
}

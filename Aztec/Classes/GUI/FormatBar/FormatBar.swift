import Foundation
import UIKit


// MARK: - FormatBar
//
open class FormatBar: UIView {

    /// Format Bar's Delegate
    ///
    open weak var formatter: FormatBarDelegate?


    /// Container StackView
    ///
    fileprivate let stackView = UIStackView()


    /// Container ScrollView
    ///
    fileprivate let scrollView = UIScrollView()


    /// StackView embedded within the ScrollView
    ///
    fileprivate let scrollableStackView = UIStackView()


    /// FormatBarItems to be displayed when the bar is in its default collapsed state
    ///
    open var defaultItems = [FormatBarItem]() {
        willSet {
            scrollableStackView.removeArrangedSubviews(defaultItems)
        }
        didSet {
            configure(items: defaultItems)
            scrollableStackView.addArrangedSubviews(defaultItems)
            configureConstraints(for: defaultItems, in: scrollableStackView)
        }
    }


    /// Extra FormatBarItems to be displayed when the bar is in its expanded state
    ///
    open var overflowItems = [FormatBarItem]() {
        didSet {
            configure(items: overflowItems)

            let hasOverflowItems = !overflowItems.isEmpty
            setOverflowToggleItemVisible(hasOverflowItems)
        }
    }


    /// FormatBarItem used to toggle the bar's expanded state
    ///
    fileprivate lazy var overflowToggleItem: FormatBarItem = {
        let item = FormatBarItem(image: UIImage(), identifier: nil)
        self.configureStylesFor(item)

        item.addTarget(self, action: #selector(handleToggleButtonAction), for: .touchUpInside)

        return item
    }()


    /// The icon to show on the overflow toggle button
    ///
    open var overflowToggleIcon: UIImage? {
        set {
            overflowToggleItem.setImage(newValue, for: .normal)
        }
        get {
            return overflowToggleItem.image(for: .normal)
        }
    }


    /// Returns the collection of all of the FormatBarItem's (Scrollable + Fixed)
    ///
    private var items: [FormatBarItem] {
        return defaultItems + overflowItems
    }

    
    /// Tint Color
    ///
    override open var tintColor: UIColor? {
        didSet {
            for item in items {
                item.normalTintColor = tintColor
            }
        }
    }


    /// Tint Color to be applied over Selected Items
    ///
    open var selectedTintColor: UIColor? {
        didSet {
            for item in items {
                item.selectedTintColor = selectedTintColor
            }
        }
    }


    /// Tint Color to be applied over Highlighted Items
    ///
    open var highlightedTintColor: UIColor? {
        didSet {
            for item in items {
                item.highlightedTintColor = highlightedTintColor
            }
        }
    }


    /// Tint Color to be applied over Disabled Items
    ///
    open var disabledTintColor: UIColor? {
        didSet {
            for item in items {
                item.disabledTintColor = disabledTintColor
            }
        }
    }


    /// Enables or disables all of the Format Bar Items
    ///
    open var enabled = true {
        didSet {
            for item in items {
                item.isEnabled = enabled
            }
        }
    }


    /// Top Border's Separator Color
    ///
    open var topBorderColor = UIColor.darkGray


    /// Bounds Change Observer
    ///
    override open var bounds: CGRect {
        didSet {
            // Note: Under certain conditions, frame.didSet might get called instead of bounds.didSet.
            // We're observing both for that reason!
            refreshScrollingLock()
        }
    }


    /// Bounds Change Observer
    ///
    override open var frame: CGRect {
        didSet {
            // Note: Under certain conditions, frame.didSet might get called instead of bounds.didSet.
            // We're observing both for that reason!
            refreshScrollingLock()
        }
    }


    // MARK: - Initializers


    public init() {
        super.init(frame: .zero)

        // Make sure we getre-drawn whenever the bounds change!
        layer.needsDisplayOnBoundsChange = true

        configure(scrollView: scrollView)
        configureScrollableStackView()
        configureContainerStackview()

        stackView.addArrangedSubview(scrollView)
        addSubview(stackView)

        scrollView.addSubview(scrollableStackView)

        configureConstraints()
    }


    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        fatalError("init(coder:) has not been implemented")
    }



    // MARK: - Drawing!

    open override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        // Setup the Context
        let lineWidthInPoints = Constants.topBorderHeightInPixels / UIScreen.main.scale

        context.clear(rect)
        context.setLineWidth(lineWidthInPoints)

        // Background
        let bgColor = backgroundColor ?? .white
        bgColor.setFill()
        context.fill(rect)

        // Top Separator
        topBorderColor.setStroke()

        context.setShouldAntialias(false)
        context.move(to: CGPoint(x: 0, y: lineWidthInPoints))
        context.addLine(to: CGPoint(x: bounds.maxX, y: lineWidthInPoints))
        context.strokePath()
    }

    override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshStackViewSpacing()
    }


    // MARK: - Styles

    /// Selects all of the FormatBarItems matching a collection of Identifiers
    ///
    open func selectItemsMatchingIdentifiers(_ identifiers: [FormattingIdentifier]) {
        for item in items {
            if let identifier = item.identifier {
                item.isSelected = identifiers.contains(identifier)
            }
        }
    }

    // MARK: - Actions

    @IBAction func handleButtonAction(_ sender: FormatBarItem) {
        guard let identifier = sender.identifier else { return }

        formatter?.handleActionForIdentifier(identifier)
    }

    @IBAction func handleToggleButtonAction(_ sender: FormatBarItem) {
        // We're currently collapsed if the toggle button belongs to the outer stackview
        let shouldExpand = (sender.superview == stackView)

        if shouldExpand {
            animateOverflowToggleOffscreen(completion: {
                self.rotateOverflowToggleItem(.vertical, animated: false)
            })

            setOverflowItemsVisible(true)

            scrollableStackView.addArrangedSubview(overflowToggleItem)

        } else {
            overflowToggleItem.removeFromSuperview()

            setOverflowItemsVisible(false)
            stackView.addArrangedSubview(overflowToggleItem)

            rotateOverflowToggleItem(.horizontal, animated: true)
        }

        refreshScrollingLock()
    }

    private func setOverflowItemsVisible(_ visible: Bool) {
        if visible {
            scrollableStackView.addArrangedSubviews(overflowItems)

            configureConstraints(for: overflowItems, in: stackView)

            for (index, item) in overflowItems.enumerated() {
                animate(item: item, visible: true, withDelay: Double(index) * Animations.itemPop.interItemAnimationDelay)
            }
        } else {
            UIView.animate(withDuration: Animations.durationLong, animations: {
                self.scrollView.setContentOffset(.zero, animated: false)
            }, completion: { (complete) in
                self.overflowItems.forEach({ item in
                    item.removeFromSuperview()
                    item.removeConstraints(item.constraints)
                })
            })
        }
    }

    private func setOverflowToggleItemVisible(_ visible: Bool) {
        overflowToggleItem.removeFromSuperview()

        if visible {
            stackView.addArrangedSubview(overflowToggleItem)
            configureConstraints(for: [overflowToggleItem], in: stackView)
        }
    }
}



// MARK: - Configuration Helpers
//
private extension FormatBar {

    /// Detaches a given collection of FormatBarItem's
    ///
    func detach(items: [FormatBarItem]) {
        for item in items {
            item.removeFromSuperview()
        }
    }


    /// Sets up a given collection of FormatBarItem's1
    ///
    func configure(items: [FormatBarItem]) {
        for item in items {
            configure(item: item)
        }
    }


    /// Sets up a given FormatBarItem
    ///
    func configure(item: FormatBarItem) {
        configureStylesFor(item)

        item.addTarget(self, action: #selector(handleButtonAction), for: .touchUpInside)
    }

    func configureStylesFor(_ item: FormatBarItem) {
        item.tintColor = tintColor
        item.selectedTintColor = selectedTintColor
        item.highlightedTintColor = highlightedTintColor
        item.disabledTintColor = disabledTintColor
    }

    /// Sets up the container StackView
    ///
    func configureContainerStackview() {
        stackView.axis = .horizontal
        stackView.spacing = Constants.stackViewRegularSpacing
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
    }


    /// Sets up the scrollable StackView
    ///
    func configureScrollableStackView() {
        scrollableStackView.axis = .horizontal
        scrollableStackView.spacing = Constants.stackViewCompactSpacing
        scrollableStackView.alignment = .center
        scrollableStackView.distribution = .equalCentering
        scrollableStackView.translatesAutoresizingMaskIntoConstraints = false
    }


    /// Sets up the ScrollView
    ///
    func configure(scrollView: UIScrollView) {
        scrollView.isScrollEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
    }


    /// Sets up the Constraints
    ///
    func configureConstraints() {
        let insets = Constants.scrollableStackViewInsets

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -1 * insets.right),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])

        NSLayoutConstraint.activate([
            scrollableStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            scrollableStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            scrollableStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            scrollableStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            scrollableStackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            ])
    }


    /// Sets up the Constraints for a given FormatBarItem, within the specified Container
    ///
    func configureConstraints(for items: [FormatBarItem], in container: UIView) {
        let constraints = items.flatMap { item in
            return [
                item.widthAnchor.constraint(equalToConstant: Constants.stackButtonWidth),
                item.heightAnchor.constraint(equalTo: item.widthAnchor)
            ]
        }

        NSLayoutConstraint.activate(constraints)
    }


    /// Refreshes the Stack View's Spacing, according to the Horizontal Size Class
    ///
    func refreshStackViewSpacing() {
        let horizontallyCompact = traitCollection.horizontalSizeClass == .compact
        let stackViewSpacing = horizontallyCompact ? Constants.stackViewCompactSpacing : Constants.stackViewRegularSpacing

        scrollableStackView.spacing = stackViewSpacing
    }


    /// Disables scrolling whenever there's no actual overflow
    ///
    func refreshScrollingLock() {
        layoutIfNeeded()

        scrollView.isScrollEnabled = scrollView.contentSize.width > scrollView.frame.width
    }
}



// MARK: - Animation Helpers
//
extension FormatBar {

    private var scrollableContentSize: CGSize {
        return scrollView.contentSize
    }

    private var scrollableVisibleSize: CGSize {
        return scrollView.frame.size
    }

    open func animateSlightPeekWhenOverflows() {
        guard scrollableContentSize.width > scrollableVisibleSize.width else {
            return
        }

        let originalRect = CGRect(origin: .zero, size: scrollableVisibleSize)
        let peekOrigin = CGPoint(x: scrollableContentSize.width * Animations.peekWidthRatio, y: 0)
        let peekRect = CGRect(origin: peekOrigin, size: scrollableVisibleSize)

        UIView.animate(withDuration: Animations.durationLong, delay: Animations.delayZero, options: .curveEaseInOut, animations: {
            self.scrollView.scrollRectToVisible(peekRect, animated: false)
        }, completion: { _ in
            UIView.animate(withDuration: Animations.durationShort, delay: Animations.delayZero, options: .curveEaseInOut, animations: {
                self.scrollView.scrollRectToVisible(originalRect, animated: false)
            }, completion: nil)
        })
    }

    func animate(item: FormatBarItem, visible: Bool, withDelay delay: TimeInterval) {
        let hide = {
            item.transform = Animations.itemPop.initialTransform
            item.alpha = 0
        }

        let unhide = {
            item.transform = CGAffineTransform.identity
            item.alpha = 1.0
        }

        if visible {
            hide()
        } else {
            unhide()
        }

        UIView.animate(withDuration: Animations.itemPop.duration,
                       delay: delay,
                       usingSpringWithDamping: Animations.itemPop.springDamping,
                       initialSpringVelocity: Animations.itemPop.springInitialVelocity,
                       options: [],
                       animations: (visible) ? unhide : hide,
                       completion: nil)
    }

    fileprivate enum OverflowToggleAnimationDirection {
        case horizontal
        case vertical

        var transform: CGAffineTransform {
            switch self {
            case .horizontal:
                return .identity
            case .vertical:
                return CGAffineTransform(rotationAngle: (.pi / 2))
            }
        }
    }

    fileprivate func rotateOverflowToggleItem(_ direction: OverflowToggleAnimationDirection, animated: Bool, completion: ((Bool) -> Void)? = nil) {
        let transform = {
            self.overflowToggleItem.transform = direction.transform
        }

        if (animated) {
            UIView.animate(withDuration: Animations.toggleItem.duration,
                           delay: 0,
                           usingSpringWithDamping: Animations.toggleItem.springDamping,
                           initialSpringVelocity: Animations.toggleItem.springInitialVelocity,
                           options: [],
                           animations: transform,
                           completion: completion)
        } else {
            transform()
            completion?(true)
        }
    }

    fileprivate func animateOverflowToggleOffscreen(completion: (() -> Void)? = nil) {
        defer {
            overflowToggleItem.removeFromSuperview()
        }

        // Replace toggle with a snapshot
        guard let snapshot = overflowToggleItem.snapshotView(afterScreenUpdates: false) else { return }

        addSubview(snapshot)
        snapshot.frame = convert(overflowToggleItem.frame, from: stackView)

        UIView.animate(withDuration: Animations.durationLong,
                       animations: {
                        snapshot.transform = CGAffineTransform(translationX: Constants.stackButtonWidth, y: 0)
        }, completion: { _ in
            snapshot.removeFromSuperview()
            completion?()
        })
    }
}



// MARK: - Private Constants
//
private extension FormatBar {

    struct Animations {
        static let durationLong = TimeInterval(0.3)
        static let durationShort = TimeInterval(0.15)
        static let delayZero = TimeInterval(0)
        static let peekWidthRatio = CGFloat(0.05)

        struct toggleItem {
            static let duration = TimeInterval(0.6)
            static let springDamping = CGFloat(0.5)
            static let springInitialVelocity = CGFloat(0.1)
        }

        struct itemPop {
            static let interItemAnimationDelay = TimeInterval(0.1)
            static let initialTransform = CGAffineTransform(scaleX: 0.01, y: 0.01)
            static let duration = TimeInterval(0.65)
            static let springDamping = CGFloat(0.4)
            static let springInitialVelocity = CGFloat(1.0)
        }
    }

    struct Constants {
        static let fixedSeparatorMidPointPaddingX = CGFloat(5)
        static let fixedStackViewInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        static let scrollableStackViewInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        static let stackViewCompactSpacing = CGFloat(0)
        static let stackViewRegularSpacing = CGFloat(0)
        static let stackButtonWidth = CGFloat(44)
        static let topBorderHeightInPixels = CGFloat(1)
    }
}

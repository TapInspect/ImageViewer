//
//  GalleryViewController.swift
//  ImageViewer
//
//  Created by Kristian Angyal on 01/07/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//

import UIKit
import AVFoundation

/// Must be presented inside a `UINavigationController`; the navigation bar and toolbar are the gallery's decoration views.
/// Use `presentImageGallery(_:)` which wraps it for you. Callers can set `navigationItem.title`/`titleView` and `toolbarItems`
/// before presenting; built-in bar items are added alongside them.
open class GalleryViewController: UIPageViewController, ItemControllerDelegate {

    // UI
    fileprivate let overlayView = BlurView()
    fileprivate var closeButton: UIBarButtonItem? = UIBarButtonItem(title: "Close", style: .plain, target: nil, action: nil)
    fileprivate var thumbnailsButton: UIBarButtonItem? = UIBarButtonItem(title: "See All", style: .plain, target: nil, action: nil)
    fileprivate var deleteButton: UIBarButtonItem? = UIBarButtonItem(barButtonSystemItem: .trash, target: nil, action: nil)
    fileprivate let scrubber = VideoScrubber()

    fileprivate weak var initialItemController: ItemController?

    // LOCAL STATE
    // represents the current page index, updated when the root view of the view controller representing the page stops animating inside visible bounds and stays on screen.
    public var currentIndex: Int
    // Picks up the initial value from configuration, if provided. Subsequently also works as local state for the setting.
    fileprivate var decorationViewsHidden = false
    fileprivate var isAnimating = false
    fileprivate var initialPresentationDone = false

    // DATASOURCE/DELEGATE
    fileprivate let itemsDelegate: GalleryItemsDelegate?
    fileprivate let itemsDataSource: GalleryItemsDataSource
    fileprivate let pagingDataSource: GalleryPagingDataSource

    // CONFIGURATION
    fileprivate var spineDividerWidth:         Float = 10
    fileprivate var galleryPagingMode = GalleryPagingMode.standard
    fileprivate var statusBarHidden = true
    fileprivate var overlayAccelerationFactor: CGFloat = 1
    fileprivate let swipeToDismissFadeOutAccelerationFactor: CGFloat = 6
    fileprivate var decorationViewsFadeDuration = 0.15

    /// COMPLETION BLOCKS
    /// If set, the block is executed right after the initial launch animations finish.
    open var launchedCompletion: (() -> Void)?
    /// If set, called every time ANY animation stops in the page controller stops and the viewer passes a page index of the page that is currently on screen
    open var landedPageAtIndexCompletion: ((Int) -> Void)?
    /// If set, launched after all animations finish when the close button is pressed.
    open var closedCompletion:                 (() -> Void)?
    /// If set, launched after all animations finish when the close() method is invoked via public API.
    open var programmaticallyClosedCompletion: (() -> Void)?
    /// If set, launched after all animations finish when the swipe-to-dismiss (applies to all directions and cases) gesture is used.
    open var swipedToDismissCompletion:        (() -> Void)?

    @available(*, unavailable)
    required public init?(coder: NSCoder) { fatalError() }

    public init(startIndex: Int, itemsDataSource: GalleryItemsDataSource, itemsDelegate: GalleryItemsDelegate? = nil, displacedViewsDataSource: GalleryDisplacedViewsDataSource? = nil, configuration: GalleryConfiguration = []) {

        self.currentIndex = startIndex
        self.itemsDelegate = itemsDelegate
        self.itemsDataSource = itemsDataSource
        var continueNextVideoOnFinish: Bool = false

        ///Only those options relevant to the paging GalleryViewController are explicitly handled here, the rest is handled by ItemViewControllers
        for item in configuration {

            switch item {

            case .imageDividerWidth(let width):                 spineDividerWidth = Float(width)
            case .pagingMode(let mode):                         galleryPagingMode = mode
            case .statusBarHidden(let hidden):                  statusBarHidden = hidden
            case .hideDecorationViewsOnLaunch(let hidden):      decorationViewsHidden = hidden
            case .decorationViewsFadeDuration(let duration):    decorationViewsFadeDuration = duration
            case .overlayColor(let color):                      overlayView.overlayColor = color
            case .overlayBlurStyle(let style):                  overlayView.blurringView.effect = UIBlurEffect(style: style)
            case .overlayBlurOpacity(let opacity):              overlayView.blurTargetOpacity = opacity
            case .overlayColorOpacity(let opacity):             overlayView.colorTargetOpacity = opacity
            case .blurPresentDuration(let duration):            overlayView.blurPresentDuration = duration
            case .blurPresentDelay(let delay):                  overlayView.blurPresentDelay = delay
            case .colorPresentDuration(let duration):           overlayView.colorPresentDuration = duration
            case .colorPresentDelay(let delay):                 overlayView.colorPresentDelay = delay
            case .blurDismissDuration(let duration):            overlayView.blurDismissDuration = duration
            case .blurDismissDelay(let delay):                  overlayView.blurDismissDelay = delay
            case .colorDismissDuration(let duration):           overlayView.colorDismissDuration = duration
            case .colorDismissDelay(let delay):                 overlayView.colorDismissDelay = delay
            case .continuePlayVideoOnEnd(let enabled):          continueNextVideoOnFinish = enabled
            case .videoControlsColor(let color):                scrubber.tintColor = color
            case .closeButtonMode(let buttonMode):

                switch buttonMode {

                case .none:                 closeButton = nil
                case .custom(let button):   closeButton = button
                case .builtIn:              break
                }

            case .thumbnailsButtonMode(let buttonMode):

                switch buttonMode {

                case .none:                 thumbnailsButton = nil
                case .custom(let button):   thumbnailsButton = button
                case .builtIn:              break
                }

            case .deleteButtonMode(let buttonMode):

                switch buttonMode {

                case .none:                 deleteButton = nil
                case .custom(let button):   deleteButton = button
                case .builtIn:              break
                }

                default: break
            }
        }

        pagingDataSource = GalleryPagingDataSource(itemsDataSource: itemsDataSource, displacedViewsDataSource: displacedViewsDataSource, scrubber: scrubber, configuration: configuration)

        super.init(transitionStyle: UIPageViewController.TransitionStyle.scroll,
                   navigationOrientation: UIPageViewController.NavigationOrientation.horizontal,
                   options: [UIPageViewController.OptionsKey.interPageSpacing : NSNumber(value: spineDividerWidth as Float)])

        pagingDataSource.itemControllerDelegate = self

        ///This feels out of place, one would expect even the first presented(paged) item controller to be provided by the paging dataSource but there is nothing we can do as Apple requires the first controller to be set via this "setViewControllers" method.
        let initialController = pagingDataSource.createItemController(startIndex, isInitial: true)
        self.setViewControllers([initialController], direction: UIPageViewController.NavigationDirection.forward, animated: false, completion: nil)

        if let controller = initialController as? ItemController {

            initialItemController = controller
        }

        self.dataSource = pagingDataSource

        UIApplication.applicationWindow.windowLevel = (statusBarHidden) ? UIWindow.Level.statusBar + 1 : UIWindow.Level.normal

        if continueNextVideoOnFinish {
            NotificationCenter.default.addObserver(self, selector: #selector(didEndPlaying), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        }
    }

    deinit {

        NotificationCenter.default.removeObserver(self)
    }

    @objc func didEndPlaying() {
        page(toIndex: currentIndex+1)
    }

    /// The navigation bar and toolbar. Faded rather than hidden so the safe area, and with it the item layout, never moves.
    fileprivate var decorationViews: [UIView] {

        return [navigationController?.navigationBar, navigationController?.toolbar].compactMap { $0 }
    }

    fileprivate func configureOverlayView() {

        overlayView.translatesAutoresizingMaskIntoConstraints = false
        self.view.insertSubview(overlayView, at: 0)

        NSLayoutConstraint.activate([
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    fileprivate func configureBars() {

        closeButton?.target = self
        closeButton?.action = #selector(GalleryViewController.closeInteractively)
        thumbnailsButton?.target = self
        thumbnailsButton?.action = #selector(GalleryViewController.showThumbnails)
        deleteButton?.target = self
        deleteButton?.action = #selector(GalleryViewController.deleteItem)

        navigationItem.leftBarButtonItem = thumbnailsButton
        navigationItem.rightBarButtonItem = closeButton

        if let deleteButton = deleteButton {
            toolbarItems = (toolbarItems ?? []) + [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), deleteButton]
        }

        guard let navigationController = navigationController else { return }

        navigationController.isToolbarHidden = toolbarItems?.isEmpty ?? true

        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithOpaqueBackground()
        navigationBarAppearance.backgroundColor = .black
        navigationBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController.navigationBar.standardAppearance = navigationBarAppearance
        navigationController.navigationBar.compactAppearance = navigationBarAppearance
        navigationController.navigationBar.scrollEdgeAppearance = navigationBarAppearance
        navigationController.navigationBar.tintColor = .white

        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithOpaqueBackground()
        toolbarAppearance.backgroundColor = .black
        navigationController.toolbar.standardAppearance = toolbarAppearance
        navigationController.toolbar.compactAppearance = toolbarAppearance
        if #available(iOS 15.0, *) {
            navigationController.toolbar.scrollEdgeAppearance = toolbarAppearance
        }
        navigationController.toolbar.tintColor = .white

        decorationViews.forEach { $0.alpha = 0 }
    }

    fileprivate func configureScrubber() {

        scrubber.alpha = 0
        scrubber.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(scrubber)

        NSLayoutConstraint.activate([
            scrubber.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrubber.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrubber.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scrubber.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        configureBars()
        configureScrubber()
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard initialPresentationDone == false else { return }

        ///We have to call this here (not sooner), because it adds the overlay view to the presenting controller and the presentingController property is set only at this moment in the VC lifecycle.
        configureOverlayView()

        ///The initial presentation animations and transitions
        presentInitially()

        initialPresentationDone = true
    }

    fileprivate func presentInitially() {

        isAnimating = true

        ///Animates decoration views to the initial state if they are set to be visible on launch. We do not need to do anything if they are set to be hidden because they are already set up as hidden by default. Unhiding them for the launch is part of chosen UX.
        initialItemController?.presentItem(alongsideAnimation: { [weak self] in

            self?.overlayView.present()

            }, completion: { [weak self] in

                if let strongSelf = self {

                    if strongSelf.decorationViewsHidden == false {

                        strongSelf.animateDecorationViews(visible: true)
                    }

                    strongSelf.isAnimating = false

                    strongSelf.launchedCompletion?()
                }
            })
    }

    @objc public func deleteItem() {

        deleteButton?.isEnabled = false
        view.isUserInteractionEnabled = false

        itemsDelegate?.removeGalleryItem(at: currentIndex)
        removePage(atIndex: currentIndex) {

            [weak self] in
            self?.deleteButton?.isEnabled = true
            self?.view.isUserInteractionEnabled = true
        }
    }

    //ThumbnailsimageBlock

    @objc fileprivate func showThumbnails() {

        let thumbnailsController = ThumbnailsViewController(itemsDataSource: self.itemsDataSource)

        thumbnailsController.onItemSelected = { [weak self] index in

            self?.page(toIndex: index)
        }

        let navigationController = UINavigationController(rootViewController: thumbnailsController)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true, completion: nil)
    }

    open func page(toIndex index: Int) {

        guard currentIndex != index && index >= 0 && index < self.itemsDataSource.itemCount() else { return }

        let imageViewController = self.pagingDataSource.createItemController(index)
        let direction: UIPageViewController.NavigationDirection = index > currentIndex ? .forward : .reverse

        // workaround to make UIPageViewController happy
        if direction == .forward {
            let previousVC = self.pagingDataSource.createItemController(index - 1)
            setViewControllers([previousVC], direction: direction, animated: true, completion: { finished in
                DispatchQueue.main.async(execute: { [weak self] in
                    self?.setViewControllers([imageViewController], direction: direction, animated: false, completion: nil)
                    })
            })
        } else {
            let nextVC = self.pagingDataSource.createItemController(index + 1)
            setViewControllers([nextVC], direction: direction, animated: true, completion: { finished in
                DispatchQueue.main.async(execute: { [weak self] in
                    self?.setViewControllers([imageViewController], direction: direction, animated: false, completion: nil)
                    })
            })
        }
    }

    func removePage(atIndex index: Int, completion: @escaping () -> Void) {

        // If removing last item, go back, otherwise, go forward

        let direction: UIPageViewController.NavigationDirection = index < self.itemsDataSource.itemCount() ? .forward : .reverse

        let newIndex = direction == .forward ? index : index - 1

        if newIndex < 0 { close(); return }

        let vc = self.pagingDataSource.createItemController(newIndex)
        setViewControllers([vc], direction: direction, animated: true) { _ in completion() }
    }

    open func reload(atIndex index: Int) {

        guard index >= 0 && index < self.itemsDataSource.itemCount() else { return }

        guard let firstVC = viewControllers?.first, let itemController = firstVC as? ItemController else { return }

        itemController.fetchImage()
    }

    // MARK: - Animations

    /// Invoked when closed programmatically
    open func close() {

        closeDecorationViews(programmaticallyClosedCompletion)
    }

    /// Invoked when closed via close button
    @objc fileprivate func closeInteractively() {

        closeDecorationViews(closedCompletion)
    }

    fileprivate func closeDecorationViews(_ completion: (() -> Void)?) {

        guard isAnimating == false else { return }
        isAnimating = true

        if let itemController = self.viewControllers?.first as? ItemController {

            itemController.closeDecorationViews(decorationViewsFadeDuration)
        }

        UIView.animate(withDuration: decorationViewsFadeDuration, animations: { [weak self] in

            self?.decorationViews.forEach { $0.alpha = 0 }
            self?.scrubber.alpha = 0.0

            }, completion: { [weak self] done in

                if let strongSelf = self,
                    let itemController = strongSelf.viewControllers?.first as? ItemController {

                    itemController.dismissItem(alongsideAnimation: {

                        strongSelf.overlayView.dismiss()

                        }, completion: { [weak self] in

                            self?.isAnimating = true
                            self?.closeGallery(false, completion: completion)
                    })
                }
            })
    }

    func closeGallery(_ animated: Bool, completion: (() -> Void)?) {

        self.overlayView.removeFromSuperview()

        self.dismiss(animated: animated) {

            UIApplication.applicationWindow.windowLevel = UIWindow.Level.normal
            completion?()
        }
    }

    fileprivate func animateDecorationViews(visible: Bool) {

        let targetAlpha: CGFloat = (visible) ? 1 : 0

        UIView.animate(withDuration: decorationViewsFadeDuration, animations: { [weak self] in

            self?.decorationViews.forEach { $0.alpha = targetAlpha }

            if let _ = self?.viewControllers?.first as? VideoViewController {

                UIView.animate(withDuration: 0.3, animations: { [weak self] in

                    self?.scrubber.alpha = targetAlpha
                })
            }
        })
    }

    public func itemControllerWillAppear(_ controller: ItemController) {

        if let videoController = controller as? VideoViewController {

            scrubber.player = videoController.player
        }
    }

    public func itemControllerWillDisappear(_ controller: ItemController) {

        if let _ = controller as? VideoViewController {

            scrubber.player = nil

            UIView.animate(withDuration: 0.3, animations: { [weak self] in

                self?.scrubber.alpha = 0
            })
        }
    }

    public func itemControllerDidAppear(_ controller: ItemController) {

        self.currentIndex = controller.index
        self.landedPageAtIndexCompletion?(self.currentIndex)

        if let videoController = controller as? VideoViewController {
            scrubber.player = videoController.player
            if scrubber.alpha == 0 && decorationViewsHidden == false {

                UIView.animate(withDuration: 0.3, animations: { [weak self] in

                    self?.scrubber.alpha = 1
                })
            }
        }
    }

    open func itemControllerDidSingleTap(_ controller: ItemController) {

        self.decorationViewsHidden.flip()
        animateDecorationViews(visible: !self.decorationViewsHidden)
    }

    open func itemControllerDidLongPress(_ controller: ItemController, in item: ItemView) {
        switch (controller, item) {

        case (_ as ImageViewController, let item as UIImageView):
            guard let image = item.image else { return }
            let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            self.present(activityVC, animated: true)

        case (_ as VideoViewController, let item as VideoView):
            guard let videoUrl = ((item.player?.currentItem?.asset) as? AVURLAsset)?.url else { return }
            let activityVC = UIActivityViewController(activityItems: [videoUrl], applicationActivities: nil)
            self.present(activityVC, animated: true)

        default:  return
        }
    }

    public func itemController(_ controller: ItemController, didSwipeToDismissWithDistanceToEdge distance: CGFloat) {

        if decorationViewsHidden == false {

            let alpha = 1 - distance * swipeToDismissFadeOutAccelerationFactor

            decorationViews.forEach { $0.alpha = alpha }

            if controller is VideoViewController {
                scrubber.alpha = alpha
            }
        }

        self.overlayView.blurringView.alpha = 1 - distance
        self.overlayView.colorView.alpha = 1 - distance
    }

    public func itemControllerDidFinishSwipeToDismissSuccessfully() {

        self.swipedToDismissCompletion?()
        self.overlayView.removeFromSuperview()
        self.dismiss(animated: false, completion: nil)
    }
}

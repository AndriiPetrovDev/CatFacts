import UIKit
import SnapKit

@available(iOS 26.0, *)
final class FactsListViewController: UIViewController {
    private let viewModel: FactsListViewModel
    private lazy var collectionController = FactsListCollectionViewController(viewModel: viewModel)
    private var isSearchPanelHidden = false
    private var keyboardOverlap: CGFloat = 0
    private var searchPanelBottomConstraint: Constraint?
    private var searchPanelBottomInset: CGFloat = 8
    private var searchToolbarBottomInset: CGFloat = 8
    private var previousToolbarHidden: Bool?

    private var usesSearchToolbar: Bool {
        traitCollection.userInterfaceIdiom == .phone
    }

    private lazy var searchController: UISearchController = {
        let controller = UISearchController(searchResultsController: nil)
        controller.delegate = self
        controller.obscuresBackgroundDuringPresentation = false
        controller.hidesNavigationBarDuringPresentation = false
        controller.searchBar.delegate = self
        controller.searchBar.placeholder = viewModel.localization[.searchPlaceholder]
        controller.searchBar.searchTextField.accessibilityIdentifier = "facts.search"
        controller.searchBar.text = viewModel.searchQuery
        controller.searchBar.autocapitalizationType = .none
        controller.searchBar.autocorrectionType = .no
        controller.searchBar.sizeToFit()
        return controller
    }()

    private lazy var filterButtons = [
        makeFilterButton(title: viewModel.localization[.verified], filter: .verified),
        makeFilterButton(title: viewModel.localization[.new], filter: .new)
    ]

    private lazy var filterBar: UIStackView = {
        let stack = UIStackView(arrangedSubviews: filterButtons)
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()

    private lazy var searchPanel: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [filterBar])
        if !usesSearchToolbar {
            stack.addArrangedSubview(searchController.searchBar)
        }
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        return stack
    }()

    init(viewModel: FactsListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.localization[.factsTitle]
        navigationItem.largeTitleDisplayMode = .always
        definesPresentationContext = true
        view.backgroundColor = .systemGroupedBackground
        if usesSearchToolbar {
            navigationItem.searchController = searchController
            navigationItem.preferredSearchBarPlacement = .integrated
            navigationItem.searchBarPlacementAllowsToolbarIntegration = true
            toolbarItems = [navigationItem.searchBarPlacementBarButtonItem]
        }
        collectionController.onScrollDirectionChange = { [weak self] direction in
            self?.setSearchPanelHidden(direction == .down)
        }
        collectionController.shouldUpdateAccessibilityFocus = { [weak self] in
            self?.searchController.searchBar.searchTextField.isFirstResponder == false
        }
        addChild(collectionController)
        view.addSubview(collectionController.view)
        view.addSubview(searchPanel)
        updateFilterButtons()
        setupConstraints()
        collectionController.onSearchAvailabilityChange = { [weak self] canSearch in
            self?.setSearchPanelHidden(!canSearch)
        }
        setSearchPanelHidden(!viewModel.canSearch)
        collectionController.didMove(toParent: self)
        setContentScrollView(collectionController.scrollView, for: .top)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardFrameDidChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let keyboardInset = max(0, keyboardOverlap - view.safeAreaInsets.bottom)
        var panelBottomInset = 8 + keyboardInset
        if usesSearchToolbar, !isSearchPanelHidden,
           let window = view.window,
           searchController.searchBar.window === window {
            let searchFrame = searchController.searchBar.convert(searchController.searchBar.bounds, to: view)
            searchToolbarBottomInset = max(8, view.safeAreaLayoutGuide.layoutFrame.maxY - searchFrame.minY + 8 - keyboardInset)
        }
        if usesSearchToolbar, !isSearchPanelHidden {
            panelBottomInset = searchToolbarBottomInset + keyboardInset
        }
        if abs(searchPanelBottomInset - panelBottomInset) > 0.5 {
            searchPanelBottomInset = panelBottomInset
            searchPanelBottomConstraint?.update(offset: -panelBottomInset)
        }
        let bottomInset = isSearchPanelHidden ? keyboardInset : searchPanel.bounds.height + panelBottomInset + 8
        collectionController.updateContentInsets(bottom: bottomInset)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if usesSearchToolbar, previousToolbarHidden == nil, let navigationController {
            previousToolbarHidden = navigationController.isToolbarHidden
        }
        updateSearchToolbar(animated: animated && !UIAccessibility.isReduceMotionEnabled)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || navigationController?.topViewController !== self {
            searchController.searchBar.resignFirstResponder()
        }
        if usesSearchToolbar,
           let navigationController,
           navigationController.topViewController !== self,
           let previousToolbarHidden {
            navigationController.setToolbarHidden(previousToolbarHidden, animated: animated && !UIAccessibility.isReduceMotionEnabled)
            self.previousToolbarHidden = nil
        }
    }

    private func setupConstraints() {
        collectionController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        searchPanel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(16)
            searchPanelBottomConstraint = make.bottom.equalTo(view.safeAreaLayoutGuide).inset(8).constraint
        }

        filterBar.snp.makeConstraints { make in
            make.width.lessThanOrEqualTo(searchPanel)
        }

        if !usesSearchToolbar {
            searchController.searchBar.snp.makeConstraints { make in
                make.width.equalTo(searchPanel)
            }
        }
    }

    private func makeFilterButton(title: String, filter: FactsListViewModel.SearchFilter) -> UIButton {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = filter == .verified ? "facts.filter.verified" : "facts.filter.new"
        button.tag = filter.rawValue
        button.setTitle(title, for: .normal)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.configuration = .tinted()
        button.configurationUpdateHandler = { button in
            var configuration: UIButton.Configuration = button.isSelected ? .prominentGlass() : .glass()
            configuration.cornerStyle = .capsule
            configuration.title = title
            configuration.buttonSize = .medium
            button.configuration = configuration
        }

        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.viewModel.toggleSearchFilter(filter)
            self.updateFilterButtons()
        }, for: .touchUpInside)
        return button
    }

    private func updateFilterButtons() {
        for button in filterButtons {
            guard let filter = FactsListViewModel.SearchFilter(rawValue: button.tag) else { continue }
            button.isSelected = viewModel.searchFilters.contains(filter)
            button.accessibilityTraits = button.isSelected ? [.button, .selected] : [.button]
            button.setNeedsUpdateConfiguration()
        }
    }

    private func setSearchPanelHidden(_ hidden: Bool) {
        let hidden = hidden || !viewModel.canSearch
        guard isSearchPanelHidden != hidden else { return }
        isSearchPanelHidden = hidden
        searchPanel.isUserInteractionEnabled = !hidden
        searchPanel.accessibilityElementsHidden = hidden
        if hidden {
            searchController.searchBar.resignFirstResponder()
            searchController.isActive = false
        } else {
            searchController.searchBar.text = viewModel.searchQuery
        }

        let animated = view.window != nil && !UIAccessibility.isReduceMotionEnabled
        updateSearchToolbar(animated: animated)
        let updateVisibility = {
            self.searchPanel.alpha = hidden ? 0 : 1
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }

        if !animated {
            UIView.performWithoutAnimation(updateVisibility)
            return
        }

        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut],
            animations: updateVisibility
        )
    }

    private func updateSearchToolbar(animated: Bool) {
        guard usesSearchToolbar else { return }
        navigationItem.searchController = isSearchPanelHidden ? nil : searchController
        if previousToolbarHidden != nil, navigationController?.topViewController === self {
            navigationController?.setToolbarHidden(isSearchPanelHidden, animated: animated)
        }
    }

    @objc private func keyboardFrameDidChange(_ notification: Notification) {
        guard view.window != nil,
              let userInfo = notification.userInfo,
              let frame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let keyboardFrame = view.convert(frame, from: nil)
        keyboardOverlap = keyboardFrame.maxY >= view.bounds.maxY
            ? max(0, view.bounds.maxY - keyboardFrame.minY)
            : 0
        view.setNeedsLayout()
        if UIAccessibility.isReduceMotionEnabled {
            UIView.performWithoutAnimation {
                self.view.layoutIfNeeded()
            }
            return
        }
        let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0
        let options = UIView.AnimationOptions(rawValue: curve << 16).union(.beginFromCurrentState)
        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.view.layoutIfNeeded()
        }
    }
}

@available(iOS 26.0, *)
extension FactsListViewController: UISearchControllerDelegate {
    func willPresentSearchController(_ searchController: UISearchController) {
        setSearchPanelHidden(false)
    }
}

@available(iOS 26.0, *)
extension FactsListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard !isSearchPanelHidden else { return }
        viewModel.updateSearchQuery(searchText)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        viewModel.updateSearchQuery("")
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

#if DEBUG
    import SwiftUI

    @available(iOS 26.0, *)
    @MainActor
    private func makeFactsListViewControllerPreview(
        factsService: FactsServiceStub = FactsServiceStub(fetchFactsResponse: .success(CatFactFixtures.list)),
        style: UIUserInterfaceStyle = .light,
        contentSize: UIContentSizeCategory = .large,
        localization: Localization = Localization()
    ) -> UINavigationController {
        let viewModel = FactsListViewModel(factsService: factsService, localization: localization)
        let controller = FactsListViewController(viewModel: viewModel)
        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.navigationBar.prefersLargeTitles = true
        navigationController.traitOverrides.userInterfaceStyle = style
        navigationController.traitOverrides.preferredContentSizeCategory = contentSize
        return navigationController
    }

    @available(iOS 26.0, *)
    #Preview("Loaded · Light · Default") {
        makeFactsListViewControllerPreview()
    }

    @available(iOS 26.0, *)
    #Preview("Duplicate IDs") {
        makeFactsListViewControllerPreview(factsService: FactsServiceStub(fetchFactsResponse: .success(CatFactFixtures.listWithDuplicateIDs)))
    }

    @available(iOS 26.0, *)
    #Preview("Error · Server") {
        makeFactsListViewControllerPreview(factsService: FactsServiceStub(fetchFactsResponse: .failure(.httpStatus(503))))
    }

    @available(iOS 26.0, *)
    #Preview("Error · Offline") {
        makeFactsListViewControllerPreview(factsService: FactsServiceStub(fetchFactsResponse: .failure(.transport(.notConnectedToInternet))))
    }

    @available(iOS 26.0, *)
    #Preview("Error · Timeout") {
        makeFactsListViewControllerPreview(factsService: FactsServiceStub(fetchFactsResponse: .failure(.transport(.timedOut))))
    }

    @available(iOS 26.0, *)
    #Preview("Error · Generic") {
        makeFactsListViewControllerPreview(factsService: FactsServiceStub(fetchFactsResponse: .failure(.invalidResponse)))
    }

    @available(iOS 26.0, *)
    #Preview("Languages · List") {
        LocalizedPreview { localization in
            makeFactsListViewControllerPreview(localization: localization)
        }
    }

    @available(iOS 26.0, *)
    #Preview("Languages · Offline") {
        LocalizedPreview { localization in
            makeFactsListViewControllerPreview(
                factsService: FactsServiceStub(fetchFactsResponse: .failure(.transport(.notConnectedToInternet))),
                localization: localization
            )
        }
    }

    @available(iOS 26.0, *)
    #Preview("Empty") {
        makeFactsListViewControllerPreview(factsService: FactsServiceStub(fetchFactsResponse: .success([])))
    }

    @available(iOS 26.0, *)
    #Preview("Loading") {
        makeFactsListViewControllerPreview(factsService: FactsServiceStub(fetchFactsResponse: .loading))
    }

    @available(iOS 26.0, *)
    #Preview("Slow Internet · 2s") {
        makeFactsListViewControllerPreview(factsService: FactsServiceStub(fetchFactsResponse: .slowInternet(CatFactFixtures.list)))
    }

    @available(iOS 26.0, *)
    #Preview("Loaded · Light · XXXL") {
        makeFactsListViewControllerPreview(contentSize: .extraExtraExtraLarge)
    }

    @available(iOS 26.0, *)
    #Preview("Loaded · Light · Accessibility XXXL") {
        makeFactsListViewControllerPreview(contentSize: .accessibilityExtraExtraExtraLarge)
    }

    @available(iOS 26.0, *)
    #Preview("Loaded · Dark · Default") {
        makeFactsListViewControllerPreview(style: .dark)
    }
#endif

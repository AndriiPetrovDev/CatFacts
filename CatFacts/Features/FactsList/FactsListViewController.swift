import UIKit
import SnapKit

final class FactsListViewController: UIViewController {
    private enum Section {
        case main
    }

    private let viewModel: FactsListViewModel
    private var loadTask: Task<Void, Never>?
    private var isScreenVisible = false
    private var isSearchPanelHidden = false
    private var lastPanTranslation: CGFloat = 0
    private var scrollDirectionDistance: CGFloat = 0
    private var keyboardOverlap: CGFloat = 0
    private var searchPanelBottomConstraint: Constraint?
    private var searchPanelBottomInset: CGFloat = 8
    private var searchToolbarBottomInset: CGFloat = 8
    private var previousToolbarHidden: Bool?
    private weak var searchToolbarContentView: UIView?

    private var usesSearchToolbar: Bool {
        if #available(iOS 26.0, *) {
            return traitCollection.userInterfaceIdiom == .phone
        }
        return false
    }

    private lazy var dataSource: UICollectionViewDiffableDataSource<Section, CatFact.ID> = {
        let viewModel = viewModel
        let registration = UICollectionView.CellRegistration<FactCell, CatFact> { cell, _, fact in
            cell.configure(
                text: fact.text,
                isVerified: fact.isVerified,
                isNew: fact.isNew,
                searchQuery: viewModel.searchQuery
            )
        }

        return UICollectionViewDiffableDataSource<Section, CatFact.ID>(collectionView: collectionView) { collectionView, indexPath, id in
            guard let fact = viewModel.fact(withID: id) else { return nil }
            return collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: fact)
        }
    }()

    // MARK: - UI

    private lazy var searchController: UISearchController = {
        let controller = UISearchController(searchResultsController: nil)
        controller.searchResultsUpdater = self
        controller.delegate = self
        controller.obscuresBackgroundDuringPresentation = false
        controller.hidesNavigationBarDuringPresentation = false
        controller.searchBar.delegate = self
        controller.searchBar.placeholder = "Search facts"
        controller.searchBar.text = viewModel.searchQuery
        controller.searchBar.autocapitalizationType = .none
        controller.searchBar.autocorrectionType = .no
        controller.searchBar.sizeToFit()
        return controller
    }()

    private lazy var filterButtons = [
        makeFilterButton(title: "Verified", filter: .verified),
        makeFilterButton(title: "New", filter: .new)
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

    private lazy var collectionView: UICollectionView = {
        let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        let layout = UICollectionViewCompositionalLayout.list(using: configuration)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .onDrag
        collectionView.delegate = self
        return collectionView
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.isAccessibilityElement = false
        return indicator
    }()

    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private lazy var retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Try Again", for: .normal)
        button.accessibilityHint = "Loads cat facts again"
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.addAction(UIAction { [weak self] _ in
            self?.loadFacts()
        }, for: .touchUpInside)
        return button
    }()

    private lazy var statusStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [activityIndicator, messageLabel, retryButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.isHidden = true
        return stack
    }()

    // MARK: - Lifecycle

    init(viewModel: FactsListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        loadTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupConstraints()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardFrameDidChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        bindViewModel()
        render(viewModel.state)
        loadFacts()
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
        if usesSearchToolbar {
            panelBottomInset = searchToolbarBottomInset + keyboardInset
        }
        if abs(searchPanelBottomInset - panelBottomInset) > 0.5 {
            searchPanelBottomInset = panelBottomInset
            searchPanelBottomConstraint?.update(offset: -panelBottomInset)
        }
        let bottomInset = searchPanel.bounds.height + panelBottomInset + 8
        if abs(collectionView.contentInset.bottom - bottomInset) > 0.5 {
            collectionView.contentInset.bottom = bottomInset
            collectionView.verticalScrollIndicatorInsets.bottom = bottomInset
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        searchController.searchBar.isUserInteractionEnabled = !isSearchPanelHidden
        searchController.searchBar.accessibilityElementsHidden = isSearchPanelHidden
        if usesSearchToolbar, let navigationController {
            if previousToolbarHidden == nil {
                previousToolbarHidden = navigationController.isToolbarHidden
            }
            navigationController.setToolbarHidden(false, animated: animated)
            navigationController.toolbar.alpha = 1
            navigationController.toolbar.isUserInteractionEnabled = !isSearchPanelHidden
            navigationController.toolbar.accessibilityElementsHidden = isSearchPanelHidden
        }
        setSearchPanelAlpha(isSearchPanelHidden ? 0 : 1)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setSearchPanelAlpha(isSearchPanelHidden ? 0 : 1)
        isScreenVisible = true
        if !statusStack.isHidden {
            updateAccessibilityFocus()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isScreenVisible = false
        if isMovingFromParent || navigationController?.topViewController !== self {
            searchController.searchBar.resignFirstResponder()
        }
        if usesSearchToolbar,
           let navigationController,
           navigationController.topViewController !== self,
           let previousToolbarHidden {
            searchToolbarContentView?.alpha = 1
            searchToolbarContentView = nil
            navigationController.toolbar.alpha = 1
            navigationController.toolbar.isUserInteractionEnabled = true
            navigationController.toolbar.accessibilityElementsHidden = false
            navigationController.setToolbarHidden(previousToolbarHidden, animated: animated)
            self.previousToolbarHidden = nil
        }
    }

    // MARK: - Setup

    private func setupView() {
        title = "Cat Facts"
        navigationItem.largeTitleDisplayMode = .always
        definesPresentationContext = true
        if #available(iOS 26.0, *), usesSearchToolbar {
            navigationItem.searchController = searchController
            navigationItem.preferredSearchBarPlacement = .integrated
            navigationItem.searchBarPlacementAllowsToolbarIntegration = true
            toolbarItems = [navigationItem.searchBarPlacementBarButtonItem]
        }
        updateFilterButtons()
        view.backgroundColor = .systemGroupedBackground
        view.addSubview(collectionView)
        view.addSubview(statusStack)
        view.addSubview(searchPanel)
        if #available(iOS 15.0, *) {
            setContentScrollView(collectionView, for: .top)
        }
    }

    private func setupConstraints() {
        collectionView.snp.makeConstraints { make in
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

        statusStack.snp.makeConstraints { make in
            make.centerY.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(24)
        }

        messageLabel.snp.makeConstraints { make in
            make.width.equalToSuperview()
        }

        retryButton.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(44).priority(.high)
        }
    }

    private func makeFilterButton(title: String, filter: FactsListViewModel.SearchFilter) -> UIButton {
        let button = UIButton(type: .system)
        button.tag = filter.rawValue
        button.setTitle(title, for: .normal)
        button.titleLabel?.adjustsFontForContentSizeCategory = true

        if #available(iOS 15.0, *) {
            button.configuration = .tinted()
            button.configurationUpdateHandler = { button in
                var configuration: UIButton.Configuration
                if #available(iOS 26.0, *) {
                    configuration = button.isSelected ? .prominentGlass() : .glass()
                } else {
                    configuration = button.isSelected ? .filled() : .tinted()
                }
                configuration.title = title
                configuration.cornerStyle = .capsule
                configuration.buttonSize = .medium
                button.configuration = configuration
            }
        } else {
            button.titleLabel?.font = .preferredFont(forTextStyle: .body)
            button.setImage(UIImage(systemName: "checkmark"), for: .selected)
            button.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(textStyle: .body), forImageIn: .selected)
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
            if #available(iOS 15.0, *) {
                button.setNeedsUpdateConfiguration()
            }
        }
    }

    private func setSearchPanelHidden(_ hidden: Bool) {
        guard isSearchPanelHidden != hidden else { return }
        isSearchPanelHidden = hidden
        searchPanel.isUserInteractionEnabled = !hidden
        searchPanel.accessibilityElementsHidden = hidden
        let searchBar = searchController.searchBar
        searchBar.isUserInteractionEnabled = !hidden
        searchBar.accessibilityElementsHidden = hidden
        let toolbar = usesSearchToolbar ? navigationController?.toolbar : nil
        toolbar?.isUserInteractionEnabled = !hidden
        toolbar?.accessibilityElementsHidden = hidden
        if hidden {
            searchBar.resignFirstResponder()
        }

        if UIAccessibility.isReduceMotionEnabled {
            setSearchPanelAlpha(hidden ? 0 : 1)
            return
        }

        UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut]) {
            self.setSearchPanelAlpha(hidden ? 0 : 1)
        }
    }

    private func setSearchPanelAlpha(_ alpha: CGFloat) {
        searchPanel.alpha = alpha
        if usesSearchToolbar {
            let container = searchToolbarContainer()
            if searchToolbarContentView !== container {
                searchToolbarContentView?.alpha = 1
                searchToolbarContentView = container
            }
            container.alpha = alpha
        }
    }

    private func searchToolbarContainer() -> UIView {
        var container: UIView = searchController.searchBar.searchTextField
        // Integrated search renders its field and glass in a separate UIKit container.
        while let parent = container.superview,
              !(parent is UIWindow),
              parent !== view,
              !view.isDescendant(of: parent),
              navigationController?.navigationBar.isDescendant(of: parent) != true {
            container = parent
        }
        return container
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
        let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0
        let options = UIView.AnimationOptions(rawValue: curve << 16).union(.beginFromCurrentState)
        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Data

    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
    }

    private func loadFacts() {
        guard loadTask == nil else { return }
        let viewModel = viewModel
        loadTask = Task { [weak self] in
            await viewModel.loadFacts()
            self?.loadTask = nil
        }
    }

    // MARK: - Rendering

    private func render(_ state: FactsListViewModel.State) {
        switch state {
        case .idle:
            showStatus(isLoading: false, message: nil)

        case .loading:
            showStatus(isLoading: true, message: "Loading facts…")

        case .loaded:
            let emptyMessage = viewModel.hasActiveFilters ? "No facts found." : "No facts yet."
            showStatus(isLoading: false, message: viewModel.items.isEmpty ? emptyMessage : nil)
            applySnapshot()

        case .failed(let message):
            showStatus(isLoading: false, message: message, canRetry: true)
        }

        if state != .loaded {
            updateAccessibilityFocus()
        }
    }

    private func showStatus(isLoading: Bool, message: String?, canRetry: Bool = false) {
        if isLoading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
        activityIndicator.isHidden = !isLoading
        messageLabel.text = message
        messageLabel.isHidden = message == nil
        retryButton.isHidden = !canRetry
        let statusElements: [UIView] = [messageLabel, retryButton]
        statusStack.accessibilityElements = statusElements.filter { !$0.isHidden }
        statusStack.isHidden = !isLoading && message == nil
        collectionView.isHidden = !statusStack.isHidden
        if !statusStack.isHidden {
            setSearchPanelHidden(false)
        }
    }

    private func applySnapshot() {
        let existingIDs = Set(dataSource.snapshot().itemIdentifiers)
        var snapshot = NSDiffableDataSourceSnapshot<Section, CatFact.ID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModel.items.map(\.id))
        snapshot.reloadItems(snapshot.itemIdentifiers.filter { existingIDs.contains($0) })
        dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
            guard let self, self.viewModel.state == .loaded else { return }
            self.updateAccessibilityFocus()
        }
    }

    private func updateAccessibilityFocus() {
        guard isScreenVisible, UIAccessibility.isVoiceOverRunning,
              !searchController.searchBar.searchTextField.isFirstResponder else { return }
        view.layoutIfNeeded()

        let element: UIView?
        if !statusStack.isHidden {
            element = messageLabel
        } else {
            element = collectionView.cellForItem(at: IndexPath(item: 0, section: 0))
        }

        guard let element else { return }
        UIAccessibility.post(notification: .layoutChanged, argument: element)
    }
}

extension FactsListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.updateSearchQuery(searchController.searchBar.text ?? "")
    }
}

extension FactsListViewController: UISearchControllerDelegate {
    func willPresentSearchController(_ searchController: UISearchController) {
        setSearchPanelHidden(false)
    }
}

extension FactsListViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension FactsListViewController: UICollectionViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        lastPanTranslation = scrollView.panGestureRecognizer.translation(in: view).y
        scrollDirectionDistance = 0
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.isDragging else { return }
        let translation = scrollView.panGestureRecognizer.translation(in: view).y
        let delta = translation - lastPanTranslation
        lastPanTranslation = translation
        guard delta != 0 else { return }

        if delta * scrollDirectionDistance < 0 {
            scrollDirectionDistance = 0
        }
        scrollDirectionDistance += delta
        guard abs(scrollDirectionDistance) >= 12 else { return }
        setSearchPanelHidden(scrollDirectionDistance < 0)
        scrollDirectionDistance = 0
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let id = dataSource.itemIdentifier(for: indexPath) else { return }
        viewModel.selectFact(withID: id)
    }
}

#if DEBUG
    @available(iOS 17.0, *)
    @MainActor
    private func makeFactsListViewControllerPreview(
        factsService: FactsServiceStub = FactsServiceStub(fetchFactsResponse: .success(CatFactFixtures.list)),
        style: UIUserInterfaceStyle = .light,
        contentSize: UIContentSizeCategory = .large
    ) -> UINavigationController {
        let dependencies = PreviewAppDependencies(factsService: factsService)
        let viewModel = FactsListViewModel(factsService: dependencies.factsService)
        let controller = FactsListViewController(viewModel: viewModel)
        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.navigationBar.prefersLargeTitles = true
        navigationController.traitOverrides.userInterfaceStyle = style
        navigationController.traitOverrides.preferredContentSizeCategory = contentSize
        return navigationController
    }

    @available(iOS 17.0, *)
    #Preview("Loaded · Light · Default") {
        makeFactsListViewControllerPreview()
    }

    @available(iOS 17.0, *)
    #Preview("Failed") {
        makeFactsListViewControllerPreview(factsService: FactsServiceStub(fetchFactsResponse: .failure(.httpStatus(503))))
    }

    @available(iOS 17.0, *)
    #Preview("Empty") {
        makeFactsListViewControllerPreview(factsService: FactsServiceStub(fetchFactsResponse: .success([])))
    }

    @available(iOS 17.0, *)
    #Preview("Loading") {
        makeFactsListViewControllerPreview(factsService: FactsServiceStub(fetchFactsResponse: .loading))
    }

    @available(iOS 17.0, *)
    #Preview("Loaded · Light · XXXL") {
        makeFactsListViewControllerPreview(contentSize: .extraExtraExtraLarge)
    }

    @available(iOS 17.0, *)
    #Preview("Loaded · Light · Accessibility XXXL") {
        makeFactsListViewControllerPreview(contentSize: .accessibilityExtraExtraExtraLarge)
    }

    @available(iOS 17.0, *)
    #Preview("Loaded · Dark · Default") {
        makeFactsListViewControllerPreview(style: .dark)
    }
#endif

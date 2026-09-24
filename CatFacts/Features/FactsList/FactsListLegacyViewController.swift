import UIKit
import SnapKit

final class FactsListLegacyViewController: UIViewController {
    private let viewModel: FactsListViewModel
    private lazy var collectionController = FactsListCollectionViewController(viewModel: viewModel)
    private var isScreenVisible = false
    private var isSearchPanelHidden = false
    private var isTopSearchExpanding = false
    private var topSearchTransitionID = 0
    private var keyboardOverlap: CGFloat = 0
    private var searchPanelTopConstraint: NSLayoutConstraint?

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
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.backgroundColor = .systemGroupedBackground
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
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
        title = "Cat Facts"
        navigationItem.largeTitleDisplayMode = .always
        definesPresentationContext = true
        view.backgroundColor = .systemGroupedBackground
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        if #available(iOS 16.0, *) {
            navigationItem.preferredSearchBarPlacement = .stacked
        }
        collectionController.onScroll = { [weak self] in
            self?.updateTopSearchVisibility()
        }
        collectionController.onScrollDirectionChange = { [weak self] direction in
            self?.setTopSearchCollapsed(direction == .down)
        }
        collectionController.onShowStatus = { [weak self] in
            self?.setTopSearchCollapsed(false)
            self?.updateTopSearchVisibility()
        }
        collectionController.shouldUpdateAccessibilityFocus = { [weak self] in
            self?.searchController.searchBar.searchTextField.isFirstResponder == false
        }
        addChild(collectionController)
        view.addSubview(collectionController.view)
        view.addSubview(searchPanel)
        updateFilterButtons()
        setupConstraints()
        collectionController.didMove(toParent: self)
        if #available(iOS 15.0, *) {
            setContentScrollView(collectionController.scrollView, for: .top)
        }
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
        updateSearchPanelTopConstraint()
        collectionController.updateContentInsets(top: searchPanel.bounds.height, bottom: keyboardInset)
        updateTopSearchVisibility()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let searchInput = searchController.searchBar.searchTextField
        searchInput.isUserInteractionEnabled = !isSearchPanelHidden
        searchInput.accessibilityElementsHidden = isSearchPanelHidden
        setSearchPanelAlpha(isSearchPanelHidden ? 0 : 1)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setSearchPanelAlpha(isSearchPanelHidden ? 0 : 1)
        isScreenVisible = true
        updateTopSearchVisibility()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isScreenVisible = false
        searchPanelTopConstraint?.isActive = false
        if isMovingFromParent || navigationController?.topViewController !== self {
            searchController.searchBar.resignFirstResponder()
        }
    }

    private func setupConstraints() {
        collectionController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        searchPanel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            make.top.equalTo(view.safeAreaLayoutGuide).priority(.low)
        }

        filterBar.snp.makeConstraints { make in
            make.width.lessThanOrEqualTo(searchPanel.layoutMarginsGuide)
        }
    }

    private func updateSearchPanelTopConstraint() {
        let searchBar = searchController.searchBar
        guard navigationItem.searchController === searchController,
              navigationController?.topViewController === self,
              let window = view.window,
              searchBar.window === window else {
            searchPanelTopConstraint?.isActive = false
            return
        }

        // UIKit attaches the search bar to the navigation hierarchy after viewDidLoad.
        if searchPanelTopConstraint == nil {
            searchPanelTopConstraint = searchPanel.topAnchor.constraint(equalTo: searchBar.bottomAnchor)
        }
        searchPanelTopConstraint?.isActive = true
    }

    private func updateTopSearchVisibility() {
        guard isScreenVisible else { return }
        let searchBar = searchController.searchBar
        guard let window = view.window,
              searchBar.window === window,
              !searchBar.bounds.isEmpty else {
            setSearchPanelHidden(true)
            return
        }

        let searchFrame = searchBar.convert(searchBar.bounds, to: window)
        let field = searchBar.searchTextField
        let fullFrame = searchFrame.union(field.convert(field.bounds, to: window))
        var visibleFrame = fullFrame.intersection(searchFrame).intersection(window.bounds)
        var ancestor = searchBar.superview
        while let parent = ancestor {
            if parent.clipsToBounds || parent === navigationController?.navigationBar {
                visibleFrame = visibleFrame.intersection(parent.convert(parent.bounds, to: window))
            }
            ancestor = parent.superview
        }

        let tolerance = 1 / window.screen.scale
        let isFullyExpanded = !isTopSearchExpanding
            && !visibleFrame.isNull
            && visibleFrame.height >= fullFrame.height - tolerance
            && visibleFrame.width >= fullFrame.width - tolerance
        setSearchPanelHidden(!isFullyExpanded)
    }

    private func setTopSearchCollapsed(_ collapsed: Bool) {
        guard navigationItem.hidesSearchBarWhenScrolling != collapsed else { return }
        topSearchTransitionID += 1
        let transitionID = topSearchTransitionID
        isTopSearchExpanding = !collapsed && isSearchPanelHidden
        if collapsed {
            searchController.searchBar.resignFirstResponder()
            searchController.isActive = false
        }

        let updateLayout = {
            self.navigationItem.hidesSearchBarWhenScrolling = collapsed
            self.navigationController?.view.layoutIfNeeded()
        }
        let finishTransition = { [weak self] in
            guard let self, self.topSearchTransitionID == transitionID else { return }
            self.isTopSearchExpanding = false
            self.updateTopSearchVisibility()
        }
        if UIAccessibility.isReduceMotionEnabled {
            UIView.performWithoutAnimation(updateLayout)
            finishTransition()
        } else {
            UIView.animate(
                withDuration: 0.25,
                delay: 0,
                options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut],
                animations: updateLayout
            ) { _ in
                finishTransition()
            }
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
                var configuration = UIButton.Configuration.filled()
                configuration.baseBackgroundColor = button.isSelected ? button.tintColor : .systemGray5
                configuration.baseForegroundColor = button.isSelected ? .white : .label
                configuration.cornerStyle = .medium
                configuration.title = title
                configuration.buttonSize = .medium
                button.configuration = configuration
            }
        } else {
            button.titleLabel?.font = .preferredFont(forTextStyle: .body)
            button.backgroundColor = .systemGray5
            button.layer.cornerRadius = 8
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
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
            } else {
                button.backgroundColor = button.isSelected ? .systemBlue : .systemGray5
                button.tintColor = button.isSelected ? .white : .label
            }
        }
    }

    private func setSearchPanelHidden(_ hidden: Bool) {
        guard isSearchPanelHidden != hidden else { return }
        isSearchPanelHidden = hidden
        searchPanel.isUserInteractionEnabled = !hidden
        searchPanel.accessibilityElementsHidden = hidden
        let searchInput = searchController.searchBar.searchTextField
        searchInput.isUserInteractionEnabled = !hidden
        searchInput.accessibilityElementsHidden = hidden

        let updateVisibility = {
            self.setSearchPanelAlpha(hidden ? 0 : 1)
        }

        if UIAccessibility.isReduceMotionEnabled {
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

    private func setSearchPanelAlpha(_ alpha: CGFloat) {
        searchPanel.alpha = alpha
        searchController.searchBar.searchTextField.alpha = alpha
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
}

extension FactsListLegacyViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.updateSearchQuery(searchController.searchBar.text ?? "")
    }
}

extension FactsListLegacyViewController: UISearchControllerDelegate {
    func willPresentSearchController(_ searchController: UISearchController) {
        setTopSearchCollapsed(false)
    }
}

extension FactsListLegacyViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

#if DEBUG
    @available(iOS 17.0, *)
    @MainActor
    private func makeFactsListLegacyViewControllerPreview(
        factsService: FactsServiceStub = FactsServiceStub(fetchFactsResponse: .success(CatFactFixtures.list)),
        style: UIUserInterfaceStyle = .light,
        contentSize: UIContentSizeCategory = .large
    ) -> UINavigationController {
        let viewModel = FactsListViewModel(factsService: factsService)
        let controller = FactsListLegacyViewController(viewModel: viewModel)
        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.navigationBar.prefersLargeTitles = true
        navigationController.traitOverrides.userInterfaceStyle = style
        navigationController.traitOverrides.preferredContentSizeCategory = contentSize
        return navigationController
    }

    @available(iOS 17.0, *)
    #Preview("Loaded · Light · Default") {
        makeFactsListLegacyViewControllerPreview()
    }

    @available(iOS 17.0, *)
    #Preview("Failed") {
        makeFactsListLegacyViewControllerPreview(factsService: FactsServiceStub(fetchFactsResponse: .failure(.httpStatus(503))))
    }

    @available(iOS 17.0, *)
    #Preview("Empty") {
        makeFactsListLegacyViewControllerPreview(factsService: FactsServiceStub(fetchFactsResponse: .success([])))
    }

    @available(iOS 17.0, *)
    #Preview("Loading") {
        makeFactsListLegacyViewControllerPreview(factsService: FactsServiceStub(fetchFactsResponse: .loading))
    }

    @available(iOS 17.0, *)
    #Preview("Loaded · Light · XXXL") {
        makeFactsListLegacyViewControllerPreview(contentSize: .extraExtraExtraLarge)
    }

    @available(iOS 17.0, *)
    #Preview("Loaded · Light · Accessibility XXXL") {
        makeFactsListLegacyViewControllerPreview(contentSize: .accessibilityExtraExtraExtraLarge)
    }

    @available(iOS 17.0, *)
    #Preview("Loaded · Dark · Default") {
        makeFactsListLegacyViewControllerPreview(style: .dark)
    }
#endif

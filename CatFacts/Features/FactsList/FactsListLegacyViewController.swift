import UIKit
import SnapKit

final class FactsListLegacyViewController: UIViewController {
    private let viewModel: FactsListViewModel
    private lazy var collectionController = FactsListCollectionViewController(
        viewModel: viewModel,
        onScroll: { [weak self] in
            self?.updateSearchPanelStretch()
        },
        onScrollDirectionChange: { [weak self] direction in
            self?.setSearchPanelCollapsed(direction == .down)
        },
        onSearchAvailabilityChange: { [weak self] canSearch in
            self?.setSearchPanelCollapsed(!canSearch)
        },
        shouldUpdateAccessibilityFocus: { [weak self] in
            self?.searchBar.searchTextField.isFirstResponder == false
        }
    )
    private var keyboardOverlap: CGFloat = 0
    private var isSearchPanelCollapsed = false
    private var searchPanelHeight: CGFloat = 0
    private var searchBarHeight: CGFloat = 0
    private var searchPanelHeightConstraint: Constraint?
    private var searchBarHeightConstraint: Constraint?

    private lazy var searchBar: UISearchBar = {
        let bar = UISearchBar()
        bar.delegate = self
        bar.placeholder = String(localized: "search.placeholder")
        bar.searchTextField.accessibilityIdentifier = "facts.search"
        bar.text = viewModel.searchQuery
        bar.autocapitalizationType = .none
        bar.autocorrectionType = .no
        bar.backgroundImage = UIImage()
        return bar
    }()

    private lazy var filterButtons = [
        makeFilterButton(title: String(localized: "status.verified"), filter: .verified),
        makeFilterButton(title: String(localized: "status.new"), filter: .new)
    ]

    private lazy var filterBar: UIStackView = {
        let stack = UIStackView(arrangedSubviews: filterButtons)
        stack.axis = .horizontal
        stack.spacing = AppLayout.spacing
        stack.alignment = .center
        return stack
    }()

    private lazy var filterContainer: UIView = {
        let container = UIView()
        container.addSubview(filterBar)
        return container
    }()

    private lazy var searchContent: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [searchBar, filterContainer])
        stack.axis = .vertical
        stack.isLayoutMarginsRelativeArrangement = true
        stack.insetsLayoutMarginsFromSafeArea = false
        let inset = AppLayout.horizontalInset - AppLayout.spacing
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: inset,
            bottom: AppLayout.sectionSpacing,
            trailing: inset
        )
        return stack
    }()

    private lazy var searchPanel: UIView = {
        let panel = UIView()
        panel.backgroundColor = .systemGroupedBackground
        panel.clipsToBounds = true
        panel.addSubview(searchContent)
        return panel
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
        title = String(localized: "facts.title")
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .systemGroupedBackground

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemGroupedBackground
        appearance.shadowColor = .clear
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
        if #available(iOS 15.0, *) {
            navigationItem.compactScrollEdgeAppearance = appearance
        }

        addChild(collectionController)
        view.addSubview(collectionController.view)
        view.addSubview(searchPanel)
        updateFilterButtons()
        setupConstraints()
        setSearchPanelCollapsed(!viewModel.canSearch)
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
        updateSearchPanelLayout()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || navigationController?.topViewController !== self {
            searchBar.resignFirstResponder()
        }
    }

    private func setupConstraints() {
        searchBarHeight = max(44, searchBar.sizeThatFits(view.bounds.size).height)
        searchPanelHeight = searchBarHeight
            + filterBar.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
            + AppLayout.sectionSpacing

        collectionController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        searchPanel.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            searchPanelHeightConstraint = make.height.equalTo(searchPanelHeight).constraint
        }

        searchContent.snp.makeConstraints { make in
            make.bottom.leading.trailing.equalToSuperview()
        }

        searchBar.snp.makeConstraints { make in
            searchBarHeightConstraint = make.height.equalTo(searchBarHeight).constraint
        }

        filterBar.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview().offset(AppLayout.spacing)
            make.trailing.lessThanOrEqualToSuperview().inset(AppLayout.spacing)
        }
    }

    private func updateSearchPanelLayout() {
        let width = view.safeAreaLayoutGuide.layoutFrame.width
        guard width > 0 else { return }

        let margins = searchContent.directionalLayoutMargins
        let barWidth = max(0, width - margins.leading - margins.trailing)
        let barHeight = max(44, searchBar.sizeThatFits(CGSize(width: barWidth, height: .greatestFiniteMagnitude)).height)
        if abs(searchBarHeight - barHeight) > 0.5 {
            searchBarHeight = barHeight
            searchBarHeightConstraint?.update(offset: barHeight)
        }

        let contentHeight = searchContent.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        .height
        let height = isSearchPanelCollapsed ? 0 : ceil(contentHeight)
        if abs(searchPanelHeight - height) > 0.5 {
            searchPanelHeight = height
            searchPanelHeightConstraint?.update(offset: height)
        }
        let keyboardInset = max(0, keyboardOverlap - view.safeAreaInsets.bottom)
        collectionController.updateContentInsets(top: height, bottom: keyboardInset)
        updateSearchPanelStretch()
    }

    private func updateSearchPanelStretch() {
        let scrollView = collectionController.scrollView
        let overscroll = max(0, -scrollView.contentOffset.y - scrollView.adjustedContentInset.top)
        let offset = isSearchPanelCollapsed ? 0 : overscroll
        searchPanel.transform = CGAffineTransform(translationX: 0, y: offset)
    }

    private func setSearchPanelCollapsed(_ collapsed: Bool) {
        let collapsed = collapsed || !viewModel.canSearch
        guard isSearchPanelCollapsed != collapsed else { return }
        view.layoutIfNeeded()
        isSearchPanelCollapsed = collapsed
        searchPanel.isUserInteractionEnabled = !collapsed
        searchPanel.accessibilityElementsHidden = collapsed
        if collapsed {
            searchBar.resignFirstResponder()
        }

        let updateLayout = {
            self.updateSearchPanelLayout()
            self.view.layoutIfNeeded()
        }
        if view.window == nil || UIAccessibility.isReduceMotionEnabled {
            UIView.performWithoutAnimation(updateLayout)
        } else {
            UIView.animate(
                withDuration: 0.25,
                delay: 0,
                options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut],
                animations: updateLayout
            )
        }
    }

    private func makeFilterButton(title: String, filter: FactsListViewModel.SearchFilter) -> UIButton {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = filter == .verified ? "facts.filter.verified" : "facts.filter.new"
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
            button.contentEdgeInsets = UIEdgeInsets(top: AppLayout.spacing, left: 12, bottom: AppLayout.spacing, right: 12)
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

extension FactsListLegacyViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        viewModel.updateSearchQuery(searchText)
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        setSearchPanelCollapsed(false)
        searchBar.setShowsCancelButton(true, animated: !UIAccessibility.isReduceMotionEnabled)
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(false, animated: !isSearchPanelCollapsed && !UIAccessibility.isReduceMotionEnabled)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        viewModel.updateSearchQuery("")
        searchBar.resignFirstResponder()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

#if DEBUG
    import SwiftUI

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
    #Preview("Duplicate IDs") {
        makeFactsListLegacyViewControllerPreview(factsService: FactsServiceStub(fetchFactsResponse: .success(CatFactFixtures.listWithDuplicateIDs)))
    }

    @available(iOS 17.0, *)
    #Preview("Error · Server") {
        makeFactsListLegacyViewControllerPreview(factsService: FactsServiceStub(fetchFactsResponse: .failure(.httpStatus(503))))
    }

    @available(iOS 17.0, *)
    #Preview("Error · Offline") {
        makeFactsListLegacyViewControllerPreview(factsService: FactsServiceStub(fetchFactsResponse: .failure(.transport(.notConnectedToInternet))))
    }

    @available(iOS 17.0, *)
    #Preview("Error · Timeout") {
        makeFactsListLegacyViewControllerPreview(factsService: FactsServiceStub(fetchFactsResponse: .failure(.transport(.timedOut))))
    }

    @available(iOS 17.0, *)
    #Preview("Error · Generic") {
        makeFactsListLegacyViewControllerPreview(factsService: FactsServiceStub(fetchFactsResponse: .failure(.invalidResponse)))
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
    #Preview("Slow Internet · 2s") {
        makeFactsListLegacyViewControllerPreview(factsService: FactsServiceStub(fetchFactsResponse: .slowInternet(CatFactFixtures.list)))
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

import UIKit
import SnapKit

final class FactsListCollectionViewController: UIViewController {
    enum ScrollDirection {
        case up
        case down
    }

    private enum Section {
        case main
    }

    var scrollView: UIScrollView { collectionView }

    private let viewModel: FactsListViewModel
    private let onScroll: (() -> Void)?
    private let onScrollDirectionChange: ((ScrollDirection) -> Void)?
    private let onSearchAvailabilityChange: ((Bool) -> Void)?
    private let shouldUpdateAccessibilityFocus: (() -> Bool)?
    private var loadTask: Task<Void, Never>?
    private var isScreenVisible = false
    private var lastPanTranslation: CGFloat = 0
    private var scrollDirectionDistance: CGFloat = 0

    private lazy var dataSource: UICollectionViewDiffableDataSource<Section, CatFact.ID> = {
        let viewModel = viewModel
        let registration = UICollectionView.CellRegistration<FactCell, CatFact> { cell, _, fact in
            cell.accessibilityIdentifier = "facts.item.\(fact.id)"
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

    private lazy var collectionView: UICollectionView = {
        let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        let layout = UICollectionViewCompositionalLayout.list(using: configuration)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.accessibilityIdentifier = "facts.list"
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .onDrag
        collectionView.delegate = self
        return collectionView
    }()

    init(
        viewModel: FactsListViewModel,
        onScroll: (() -> Void)? = nil,
        onScrollDirectionChange: ((ScrollDirection) -> Void)? = nil,
        onSearchAvailabilityChange: ((Bool) -> Void)? = nil,
        shouldUpdateAccessibilityFocus: (() -> Bool)? = nil
    ) {
        self.viewModel = viewModel
        self.onScroll = onScroll
        self.onScrollDirectionChange = onScrollDirectionChange
        self.onSearchAvailabilityChange = onSearchAvailabilityChange
        self.shouldUpdateAccessibilityFocus = shouldUpdateAccessibilityFocus
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        loadTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        bindViewModel()
        render(viewModel.state)
        loadFacts()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isScreenVisible = true
        if contentUnavailableConfiguration != nil {
            updateAccessibilityFocus()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isScreenVisible = false
    }

    func updateContentInsets(top: CGFloat = 0, bottom: CGFloat) {
        if abs(collectionView.contentInset.top - top) > 0.5 {
            let wasAtTop = collectionView.contentOffset.y <= -collectionView.adjustedContentInset.top + 1
            collectionView.contentInset.top = top
            collectionView.verticalScrollIndicatorInsets.top = top
            if wasAtTop {
                collectionView.contentOffset.y = -collectionView.adjustedContentInset.top
            }
        }
        if abs(collectionView.contentInset.bottom - bottom) > 0.5 {
            collectionView.contentInset.bottom = bottom
            collectionView.verticalScrollIndicatorInsets.bottom = bottom
        }
    }

    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            guard let self else { return }
            self.onSearchAvailabilityChange?(self.viewModel.canSearch)
            self.render(state)
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

    private func render(_ state: FactsListViewModel.State) {
        switch state {
        case .idle:
            showStatus(message: nil)

        case .loading:
            showStatus(message: String(localized: "facts.loading"), isLoading: true)

        case .loaded:
            let items = viewModel.items
            let emptyMessage = viewModel.hasActiveFilters
                ? String(localized: "search.empty")
                : String(localized: "facts.empty")
            showStatus(message: items.isEmpty ? emptyMessage : nil)
            applySnapshot(items: items)

        case .failed(let message):
            showStatus(message: message, canRetry: true)
        }

        if state != .loaded {
            updateAccessibilityFocus()
        }
    }

    private func showStatus(message: String?, isLoading: Bool = false, canRetry: Bool = false) {
        collectionView.isHidden = message != nil
        guard let message else {
            contentUnavailableConfiguration = nil
            return
        }

        var configuration = isLoading ? UIContentUnavailableConfiguration.loading() : .empty()
        configuration.text = message
        configuration.textProperties.font = .preferredFont(forTextStyle: .body)
        configuration.textProperties.color = .secondaryLabel
        if canRetry {
            configuration.button.title = String(localized: "action.retry")
            configuration.buttonProperties.primaryAction = UIAction { [weak self] _ in
                self?.loadFacts()
            }
        }
        contentUnavailableConfiguration = configuration
    }

    private func applySnapshot(items: [CatFact]) {
        let existingIDs = Set(dataSource.snapshot().itemIdentifiers)
        var snapshot = NSDiffableDataSourceSnapshot<Section, CatFact.ID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(items.map(\.id))
        snapshot.reconfigureItems(snapshot.itemIdentifiers.filter { existingIDs.contains($0) })
        dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
            guard let self, self.viewModel.state == .loaded else { return }
            self.updateAccessibilityFocus()
        }
    }

    private func updateAccessibilityFocus() {
        guard isScreenVisible, UIAccessibility.isVoiceOverRunning,
              shouldUpdateAccessibilityFocus?() != false else { return }
        view.layoutIfNeeded()

        if let configuration = contentUnavailableConfiguration as? UIContentUnavailableConfiguration {
            UIAccessibility.post(notification: .announcement, argument: configuration.text)
            return
        }

        guard let element = collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) else { return }
        UIAccessibility.post(notification: .layoutChanged, argument: element)
    }
}

extension FactsListCollectionViewController: UICollectionViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        lastPanTranslation = scrollView.panGestureRecognizer.translation(in: view).y
        scrollDirectionDistance = 0
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onScroll?()
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
        onScrollDirectionChange?(scrollDirectionDistance < 0 ? .down : .up)
        scrollDirectionDistance = 0
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            onScroll?()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        onScroll?()
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let id = dataSource.itemIdentifier(for: indexPath) else { return }
        viewModel.selectFact(withID: id)
    }
}

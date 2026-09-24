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

    var onScroll: (() -> Void)?
    var onScrollDirectionChange: ((ScrollDirection) -> Void)?
    var onSearchAvailabilityChange: ((Bool) -> Void)?
    var shouldUpdateAccessibilityFocus: (() -> Bool)?

    var scrollView: UIScrollView { collectionView }

    private let viewModel: FactsListViewModel
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

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.isAccessibilityElement = false
        return indicator
    }()

    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.accessibilityIdentifier = "facts.message"
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private lazy var retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = "facts.retry"
        button.setTitle(String(localized: "action.retry"), for: .normal)
        button.accessibilityHint = String(localized: "accessibility.retry")
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

    init(viewModel: FactsListViewModel) {
        self.viewModel = viewModel
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
        view.addSubview(statusStack)
        setupConstraints()
        bindViewModel()
        render(viewModel.state)
        loadFacts()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isScreenVisible = true
        if !statusStack.isHidden {
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

    private func setupConstraints() {
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
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

    private func render(_ state: FactsListViewModel.State) {
        onSearchAvailabilityChange?(viewModel.canSearch)

        switch state {
        case .idle:
            showStatus(isLoading: false, message: nil)

        case .loading:
            showStatus(isLoading: true, message: String(localized: "facts.loading"))

        case .loaded:
            let emptyMessage = viewModel.hasActiveFilters
                ? String(localized: "search.empty")
                : String(localized: "facts.empty")
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
              shouldUpdateAccessibilityFocus?() != false else { return }
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

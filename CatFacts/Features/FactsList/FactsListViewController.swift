import UIKit
import SnapKit

final class FactsListViewController: UIViewController {
    private enum Section {
        case main
    }

    private let viewModel: FactsListViewModel
    private var loadTask: Task<Void, Never>?
    private var isScreenVisible = false

    private lazy var dataSource: UICollectionViewDiffableDataSource<Section, CatFact.ID> = {
        let registration = UICollectionView.CellRegistration<FactCell, CatFact> { cell, _, fact in
            cell.configure(text: fact.text, isVerified: fact.isVerified, isNew: fact.isNew)
        }

        let viewModel = viewModel
        return UICollectionViewDiffableDataSource<Section, CatFact.ID>(collectionView: collectionView) { collectionView, indexPath, id in
            guard let fact = viewModel.fact(withID: id) else { return nil }
            return collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: fact)
        }
    }()

    // MARK: - UI

    private lazy var collectionView: UICollectionView = {
        let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        let layout = UICollectionViewCompositionalLayout.list(using: configuration)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.alwaysBounceVertical = true
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
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
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

    // MARK: - Setup

    private func setupView() {
        title = "Cat Facts"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .systemGroupedBackground
        view.addSubview(collectionView)
        view.addSubview(statusStack)
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
            showStatus(isLoading: false, message: viewModel.items.isEmpty ? "No facts yet." : nil)
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
        guard isScreenVisible, UIAccessibility.isVoiceOverRunning else { return }
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

extension FactsListViewController: UICollectionViewDelegate {
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

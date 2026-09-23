import UIKit

final class FactsListViewController: UIViewController {
    private enum Section {
        case main
    }

    private let viewModel: FactsListViewModel
    private var loadTask: Task<Void, Never>?

    private lazy var contentView: FactsListView = {
        let view = FactsListView()
        view.collectionView.delegate = self
        view.retryButton.addTarget(self, action: #selector(loadFacts), for: .touchUpInside)
        return view
    }()

    private lazy var dataSource: UICollectionViewDiffableDataSource<Section, CatFact.ID> = {
        let registration = UICollectionView.CellRegistration<FactCell, CatFact> { cell, _, fact in
            cell.configure(text: fact.text, isVerified: fact.isVerified, isNew: fact.isNew)
        }

        let viewModel = viewModel
        return UICollectionViewDiffableDataSource<Section, CatFact.ID>(collectionView: contentView.collectionView) { collectionView, indexPath, id in
            guard let fact = viewModel.fact(withID: id) else { return nil }
            return collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: fact)
        }
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

    override func loadView() {
        view = contentView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Cat Facts"
        navigationItem.largeTitleDisplayMode = .always

        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
        render(viewModel.state)
        loadFacts()
    }

    @objc private func loadFacts() {
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
            contentView.showStatus(isLoading: false, message: nil)

        case .loading:
            contentView.showStatus(isLoading: true, message: "Loading facts…")

        case .loaded:
            applySnapshot()
            contentView.showStatus(isLoading: false, message: viewModel.items.isEmpty ? "No facts yet." : nil)

        case .failed(let message):
            contentView.showStatus(isLoading: false, message: message, canRetry: true)
        }
    }

    private func applySnapshot() {
        let existingIDs = Set(dataSource.snapshot().itemIdentifiers)
        var snapshot = NSDiffableDataSourceSnapshot<Section, CatFact.ID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModel.items.map(\.id))
        snapshot.reloadItems(snapshot.itemIdentifiers.filter { existingIDs.contains($0) })
        dataSource.apply(snapshot, animatingDifferences: false)
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
    private final class PreviewFactsService: FactsServiceProtocol {
        func fetchFacts() async throws -> [CatFact] {
            [
                CatFact(
                    id: "preview-1",
                    text: "Cats spend much of their day sleeping and grooming their fur.",
                    createdAt: Date(),
                    isVerified: true
                ),
                CatFact(
                    id: "preview-2",
                    text: "A cat's whiskers help it sense nearby objects and navigate narrow spaces, even in the dark.",
                    createdAt: Date(timeIntervalSince1970: 0),
                    isVerified: false
                )
            ]
        }
    }

    @available(iOS 17.0, *)
    @MainActor
    private func makeFactsListViewControllerPreview(style: UIUserInterfaceStyle, contentSize: UIContentSizeCategory) -> UINavigationController {
        let viewModel = FactsListViewModel(factsService: PreviewFactsService())
        let controller = FactsListViewController(viewModel: viewModel)
        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.navigationBar.prefersLargeTitles = true
        navigationController.traitOverrides.userInterfaceStyle = style
        navigationController.traitOverrides.preferredContentSizeCategory = contentSize
        return navigationController
    }

    @available(iOS 17.0, *)
    #Preview("Light · Default") {
        makeFactsListViewControllerPreview(style: .light, contentSize: .large)
    }

    @available(iOS 17.0, *)
    #Preview("Dark · Default") {
        makeFactsListViewControllerPreview(style: .dark, contentSize: .large)
    }

    @available(iOS 17.0, *)
    #Preview("Light · XXXL") {
        makeFactsListViewControllerPreview(style: .light, contentSize: .extraExtraExtraLarge)
    }

    @available(iOS 17.0, *)
    #Preview("Dark · XXXL") {
        makeFactsListViewControllerPreview(style: .dark, contentSize: .extraExtraExtraLarge)
    }

    @available(iOS 17.0, *)
    #Preview("Light · Accessibility XXXL") {
        makeFactsListViewControllerPreview(style: .light, contentSize: .accessibilityExtraExtraExtraLarge)
    }

    @available(iOS 17.0, *)
    #Preview("Dark · Accessibility XXXL") {
        makeFactsListViewControllerPreview(style: .dark, contentSize: .accessibilityExtraExtraExtraLarge)
    }
#endif

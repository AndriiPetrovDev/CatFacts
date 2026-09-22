import UIKit

final class FactsListViewController: UIViewController {
    private enum Section {
        case main
    }

    private let viewModel: FactsListViewModel
    private let contentView = FactsListView()
    private var dataSource: UICollectionViewDiffableDataSource<Section, CatFact.ID>?
    private var loadTask: Task<Void, Never>?

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
        contentView.collectionView.delegate = self
        configureDataSource()

        contentView.retryButton.addTarget(self, action: #selector(loadFacts), for: .touchUpInside)
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
        render(viewModel.state)
        loadFacts()
    }

    private func configureDataSource() {
        let registration = UICollectionView.CellRegistration<FactCell, CatFact> { cell, _, fact in
            cell.configure(text: fact.text)
        }

        let viewModel = viewModel
        dataSource = UICollectionViewDiffableDataSource<Section, CatFact.ID>(collectionView: contentView.collectionView) { collectionView, indexPath, id in
            guard let fact = viewModel.fact(withID: id) else { return nil }
            return collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: fact)
        }
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
        guard let dataSource else { return }
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
        guard let id = dataSource?.itemIdentifier(for: indexPath) else { return }
        viewModel.selectFact(withID: id)
    }
}

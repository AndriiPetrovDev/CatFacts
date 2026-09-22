import UIKit

final class FactsListViewController: UIViewController {
    private enum Section {
        case main
    }

    private let viewModel: FactsListViewModel
    private let contentView = FactsListView()
    private var dataSource: UICollectionViewDiffableDataSource<Section, String>?

    init(viewModel: FactsListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
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
    }

    private func configureDataSource() {
        let registration = UICollectionView.CellRegistration<FactCell, String> { cell, _, title in
            cell.configure(title: title)
        }

        let dataSource = UICollectionViewDiffableDataSource<Section, String>(collectionView: contentView.collectionView) { collectionView, indexPath, title in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: title)
        }
        self.dataSource = dataSource

        var snapshot = NSDiffableDataSourceSnapshot<Section, String>()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModel.items)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

extension FactsListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let title = dataSource?.itemIdentifier(for: indexPath) else { return }
        viewModel.selectFact(title)
    }
}

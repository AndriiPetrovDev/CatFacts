import UIKit
import SnapKit

final class FactsListView: UIView {
    let collectionView: UICollectionView
    let retryButton = UIButton(type: .system)

    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let messageLabel = UILabel()
    private let statusStack = UIStackView()

    override init(frame: CGRect) {
        let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        let layout = UICollectionViewCompositionalLayout.list(using: configuration)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(frame: frame)
        backgroundColor = .systemGroupedBackground
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.alwaysBounceVertical = true

        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center

        retryButton.setTitle("Try Again", for: .normal)
        retryButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        retryButton.titleLabel?.adjustsFontForContentSizeCategory = true

        statusStack.axis = .vertical
        statusStack.alignment = .center
        statusStack.spacing = 16
        statusStack.addArrangedSubview(activityIndicator)
        statusStack.addArrangedSubview(messageLabel)
        statusStack.addArrangedSubview(retryButton)
        statusStack.isHidden = true

        addSubview(statusStack)
        statusStack.snp.makeConstraints { make in
            make.centerY.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalTo(safeAreaLayoutGuide).inset(24)
        }

        messageLabel.snp.makeConstraints { make in
            make.width.equalToSuperview()
        }

        retryButton.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(44).priority(.high)
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    func showStatus(isLoading: Bool, message: String?, canRetry: Bool = false) {
        if isLoading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
        activityIndicator.isHidden = !isLoading
        messageLabel.text = message
        messageLabel.isHidden = message == nil
        retryButton.isHidden = !canRetry
        statusStack.isHidden = !isLoading && message == nil
        collectionView.isHidden = !statusStack.isHidden
    }
}

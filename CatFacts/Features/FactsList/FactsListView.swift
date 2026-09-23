import UIKit
import SnapKit

final class FactsListView: UIView {
    private(set) lazy var collectionView: UICollectionView = {
        let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        let layout = UICollectionViewCompositionalLayout.list(using: configuration)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.alwaysBounceVertical = true
        return collectionView
    }()

    private(set) lazy var retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Try Again", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        return button
    }()

    private lazy var activityIndicator = UIActivityIndicatorView(style: .medium)

    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private lazy var statusStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [activityIndicator, messageLabel, retryButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.isHidden = true
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemGroupedBackground

        addSubview(collectionView)
        addSubview(statusStack)

        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

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


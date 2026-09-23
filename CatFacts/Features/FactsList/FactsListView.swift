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

#if DEBUG
    @available(iOS 17.0, *)
    @MainActor
    private func makeFactsListViewPreview(style: UIUserInterfaceStyle, contentSize: UIContentSizeCategory) -> FactsListView {
        let view = FactsListView()
        view.traitOverrides.userInterfaceStyle = style
        view.traitOverrides.preferredContentSizeCategory = contentSize
        view.showStatus(
            isLoading: false,
            message: "You're offline. Check your internet connection and try again.",
            canRetry: true
        )
        return view
    }

    @available(iOS 17.0, *)
    #Preview("Light · Default") {
        makeFactsListViewPreview(style: .light, contentSize: .large)
    }

    @available(iOS 17.0, *)
    #Preview("Dark · Default") {
        makeFactsListViewPreview(style: .dark, contentSize: .large)
    }

    @available(iOS 17.0, *)
    #Preview("Light · XXXL") {
        makeFactsListViewPreview(style: .light, contentSize: .extraExtraExtraLarge)
    }

    @available(iOS 17.0, *)
    #Preview("Dark · XXXL") {
        makeFactsListViewPreview(style: .dark, contentSize: .extraExtraExtraLarge)
    }

    @available(iOS 17.0, *)
    #Preview("Light · Accessibility XXXL") {
        makeFactsListViewPreview(style: .light, contentSize: .accessibilityExtraExtraExtraLarge)
    }

    @available(iOS 17.0, *)
    #Preview("Dark · Accessibility XXXL") {
        makeFactsListViewPreview(style: .dark, contentSize: .accessibilityExtraExtraExtraLarge)
    }
#endif

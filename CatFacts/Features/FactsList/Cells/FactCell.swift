import UIKit
import SnapKit

final class FactCell: UICollectionViewListCell {
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }()

    private lazy var newImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "sparkles"))
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .caption1)
        imageView.adjustsImageSizeForAccessibilityContentSizeCategory = true
        imageView.tintColor = .systemBlue
        imageView.isAccessibilityElement = false
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(UILayoutPriority(999), for: .horizontal)
        return imageView
    }()

    private lazy var newLabel: UILabel = {
        let label = UILabel()
        label.text = "New"
        label.font = .preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .systemBlue
        label.numberOfLines = 0
        return label
    }()

    private lazy var newStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [newImageView, newLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        stack.isHidden = true
        return stack
    }()

    private lazy var verifiedImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "checkmark.square.fill"))
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .caption1)
        imageView.adjustsImageSizeForAccessibilityContentSizeCategory = true
        imageView.tintColor = .systemGreen
        imageView.isAccessibilityElement = false
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(UILayoutPriority(999), for: .horizontal)
        return imageView
    }()

    private lazy var verifiedLabel: UILabel = {
        let label = UILabel()
        label.text = "Verified"
        label.font = .preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var verifiedStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [verifiedImageView, verifiedLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        stack.isHidden = true
        return stack
    }()

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleLabel, newStack, verifiedStack])
        stack.axis = .vertical
        stack.spacing = 10
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        isAccessibilityElement = true
        contentView.accessibilityElementsHidden = true
        accessibilityTraits = .button
        accessibilityHint = "Opens fact details"
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(text: String, isVerified: Bool, isNew: Bool) {
        titleLabel.text = text
        newStack.isHidden = !isNew
        verifiedStack.isHidden = !isVerified
        accessibilityLabel = text
        let statuses = [isNew ? "New" : nil, isVerified ? "Verified" : nil].compactMap { $0 }
        accessibilityValue = statuses.isEmpty ? nil : statuses.joined(separator: ", ")
    }
}

#if DEBUG
    private final class FactCellPreviewController: UICollectionViewController {
        private let registration = UICollectionView.CellRegistration<FactCell, Int> { cell, _, index in
            let fact = CatFactFixtures.make(
                createdAt: index < 2 ? Date() : Date(timeIntervalSince1970: 0),
                isVerified: index.isMultiple(of: 2)
            )
            cell.configure(
                text: fact.text,
                isVerified: fact.isVerified,
                isNew: fact.isNew
            )
        }

        override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            4
        }

        override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: indexPath.item)
        }
    }

    @available(iOS 17.0, *)
    @MainActor
    private func makeFactCellPreview(style: UIUserInterfaceStyle, contentSize: UIContentSizeCategory) -> UIViewController {
        let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        let layout = UICollectionViewCompositionalLayout.list(using: configuration)
        let controller = FactCellPreviewController(collectionViewLayout: layout)
        controller.traitOverrides.userInterfaceStyle = style
        controller.traitOverrides.preferredContentSizeCategory = contentSize
        controller.collectionView.backgroundColor = .systemGroupedBackground
        return controller
    }

    @available(iOS 17.0, *)
    #Preview("Light · Default") {
        makeFactCellPreview(style: .light, contentSize: .large)
    }

    @available(iOS 17.0, *)
    #Preview("Dark · Default") {
        makeFactCellPreview(style: .dark, contentSize: .large)
    }

    @available(iOS 17.0, *)
    #Preview("Light · XXXL") {
        makeFactCellPreview(style: .light, contentSize: .extraExtraExtraLarge)
    }

    @available(iOS 17.0, *)
    #Preview("Dark · XXXL") {
        makeFactCellPreview(style: .dark, contentSize: .extraExtraExtraLarge)
    }

    @available(iOS 17.0, *)
    #Preview("Light · Accessibility XXXL") {
        makeFactCellPreview(style: .light, contentSize: .accessibilityExtraExtraExtraLarge)
    }

    @available(iOS 17.0, *)
    #Preview("Dark · Accessibility XXXL") {
        makeFactCellPreview(style: .dark, contentSize: .accessibilityExtraExtraExtraLarge)
    }
#endif

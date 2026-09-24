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

    private let newStatusView = FactStatusView(status: .new)
    private let verifiedStatusView = FactStatusView(status: .verified)

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleLabel, newStatusView, verifiedStatusView])
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
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(text: String, isVerified: Bool, isNew: Bool, searchQuery: String = "") {
        titleLabel.attributedText = highlightedText(text, query: searchQuery)
        newStatusView.isHidden = !isNew
        verifiedStatusView.isHidden = !isVerified
        accessibilityLabel = text
        accessibilityHint = String(localized: "accessibility.openDetails")
        let statuses = [newStatusView, verifiedStatusView].filter { !$0.isHidden }.compactMap(\.accessibilityLabel)
        accessibilityValue = statuses.isEmpty ? nil : statuses.joined(separator: String(localized: "status.separator"))
    }

    private func highlightedText(_ text: String, query: String) -> NSAttributedString {
        let attributedText = NSMutableAttributedString(string: text)
        guard !query.isEmpty else { return attributedText }

        var searchRange = text.startIndex ..< text.endIndex
        while let range = text.range(of: query, options: .caseInsensitive, range: searchRange, locale: .current),
              !range.isEmpty {
            attributedText.addAttribute(
                .backgroundColor,
                value: UIColor.systemYellow.withAlphaComponent(0.35),
                range: NSRange(range, in: text)
            )
            searchRange = range.upperBound ..< text.endIndex
        }

        return attributedText
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

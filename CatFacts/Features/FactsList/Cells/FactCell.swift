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
        let stack = UIStackView(arrangedSubviews: [titleLabel, verifiedStack])
        stack.axis = .vertical
        stack.spacing = 10
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessories = [.disclosureIndicator()]

        contentView.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityHint = "Opens fact details"
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(text: String, isVerified: Bool) {
        titleLabel.text = text
        verifiedStack.isHidden = !isVerified
        accessibilityLabel = text
        accessibilityValue = isVerified ? "Verified" : nil
    }
}

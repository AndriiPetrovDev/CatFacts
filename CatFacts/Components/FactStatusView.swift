import UIKit

final class FactStatusView: UIStackView {
    enum Status {
        case new
        case verified
    }

    init(status: Status) {
        super.init(frame: .zero)

        let title: String
        let symbolName: String
        let symbolColor: UIColor
        let textColor: UIColor

        switch status {
        case .new:
            title = "New"
            symbolName = "sparkles"
            symbolColor = .systemBlue
            textColor = .systemBlue

        case .verified:
            title = "Verified"
            symbolName = "checkmark.square.fill"
            symbolColor = .systemGreen
            textColor = .secondaryLabel
        }

        let imageView = UIImageView(image: UIImage(systemName: symbolName))
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .caption1)
        imageView.adjustsImageSizeForAccessibilityContentSizeCategory = true
        imageView.tintColor = symbolColor
        imageView.isAccessibilityElement = false
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(UILayoutPriority(999), for: .horizontal)

        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = textColor
        label.numberOfLines = 0
        label.isAccessibilityElement = false

        addArrangedSubview(imageView)
        addArrangedSubview(label)
        axis = .horizontal
        alignment = .center
        spacing = 6
        isHidden = true
        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityTraits = .staticText
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

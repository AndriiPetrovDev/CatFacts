import UIKit
import SnapKit

final class FactDetailsView: UIView {
    private lazy var scrollView = UIScrollView()
    private lazy var contentView = UIView()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .title2)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.accessibilityTraits = .header
        return label
    }()

    private lazy var textLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textColor = .label
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
        let stack = UIStackView(arrangedSubviews: [titleLabel, textLabel, newStack, verifiedStack])
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(12, after: textLabel)
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground

        addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(contentStack)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(safeAreaLayoutGuide)
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }

        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(24)
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(title: String, text: String, isVerified: Bool, isNew: Bool) {
        titleLabel.text = title
        textLabel.text = text
        newStack.isHidden = !isNew
        verifiedStack.isHidden = !isVerified
    }
}

#if DEBUG
    @available(iOS 17.0, *)
    @MainActor
    private func makeFactDetailsViewPreview(style: UIUserInterfaceStyle, contentSize: UIContentSizeCategory) -> FactDetailsView {
        let fact = CatFactFixtures.make()
        let view = FactDetailsView()
        view.traitOverrides.userInterfaceStyle = style
        view.traitOverrides.preferredContentSizeCategory = contentSize
        view.configure(
            title: "Cat Fact",
            text: fact.text,
            isVerified: fact.isVerified,
            isNew: fact.isNew
        )
        return view
    }

    @available(iOS 17.0, *)
    #Preview("Light · Default") {
        makeFactDetailsViewPreview(style: .light, contentSize: .large)
    }

    @available(iOS 17.0, *)
    #Preview("Dark · Default") {
        makeFactDetailsViewPreview(style: .dark, contentSize: .large)
    }

    @available(iOS 17.0, *)
    #Preview("Light · XXXL") {
        makeFactDetailsViewPreview(style: .light, contentSize: .extraExtraExtraLarge)
    }

    @available(iOS 17.0, *)
    #Preview("Dark · XXXL") {
        makeFactDetailsViewPreview(style: .dark, contentSize: .extraExtraExtraLarge)
    }

    @available(iOS 17.0, *)
    #Preview("Light · Accessibility XXXL") {
        makeFactDetailsViewPreview(style: .light, contentSize: .accessibilityExtraExtraExtraLarge)
    }

    @available(iOS 17.0, *)
    #Preview("Dark · Accessibility XXXL") {
        makeFactDetailsViewPreview(style: .dark, contentSize: .accessibilityExtraExtraExtraLarge)
    }
#endif

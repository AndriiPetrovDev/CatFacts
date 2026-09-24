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
        label.accessibilityTraits.insert(.header)
        return label
    }()

    private lazy var textLabel: UILabel = {
        let label = UILabel()
        label.accessibilityIdentifier = "facts.details.text"
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textColor = .label
        return label
    }()

    private let newStatusView = FactStatusView(status: .new)
    private let verifiedStatusView = FactStatusView(status: .verified)

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleLabel, textLabel, newStatusView, verifiedStatusView])
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

    func configure(title: String, text: String, isVerified: Bool, isNew: Bool, localization: Localization = Localization()) {
        titleLabel.text = title
        textLabel.text = text
        newStatusView.localize(using: localization)
        verifiedStatusView.localize(using: localization)
        newStatusView.isHidden = !isNew
        verifiedStatusView.isHidden = !isVerified

        var elements: [UIView] = [titleLabel, textLabel]
        if isNew {
            elements.append(newStatusView)
        }
        if isVerified {
            elements.append(verifiedStatusView)
        }
        contentStack.accessibilityElements = elements
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
            title: Localization()[.factTitle],
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

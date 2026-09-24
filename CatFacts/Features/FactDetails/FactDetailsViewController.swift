import UIKit
import SnapKit

final class FactDetailsViewController: UIViewController {
    private let viewModel: FactDetailsViewModel

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
        stack.spacing = AppLayout.sectionSpacing
        stack.setCustomSpacing(12, after: textLabel)
        return stack
    }()

    init(viewModel: FactDetailsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String(localized: "details.title")
        navigationItem.largeTitleDisplayMode = .never
        setupView()
        configureContent()
    }

    private func setupView() {
        view.backgroundColor = .systemBackground

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(contentStack)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }

        contentStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(AppLayout.horizontalInset)
            make.top.bottom.equalToSuperview().inset(24)
        }
    }

    private func configureContent() {
        titleLabel.text = viewModel.title
        textLabel.text = viewModel.text
        newStatusView.isHidden = !viewModel.isNew
        verifiedStatusView.isHidden = !viewModel.isVerified

        var elements: [UIView] = [titleLabel, textLabel]
        if viewModel.isNew {
            elements.append(newStatusView)
        }
        if viewModel.isVerified {
            elements.append(verifiedStatusView)
        }
        contentStack.accessibilityElements = elements
    }
}

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    @MainActor
    private func makeFactDetailsViewControllerPreview(style: UIUserInterfaceStyle, contentSize: UIContentSizeCategory) -> UINavigationController {
        let fact = CatFactFixtures.make()
        let controller = FactDetailsViewController(viewModel: FactDetailsViewModel(fact: fact))
        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.traitOverrides.userInterfaceStyle = style
        navigationController.traitOverrides.preferredContentSizeCategory = contentSize
        return navigationController
    }

    @available(iOS 17.0, *)
    #Preview("Light · Default") {
        makeFactDetailsViewControllerPreview(style: .light, contentSize: .large)
    }

    @available(iOS 17.0, *)
    #Preview("Dark · Default") {
        makeFactDetailsViewControllerPreview(style: .dark, contentSize: .large)
    }

    @available(iOS 17.0, *)
    #Preview("Light · XXXL") {
        makeFactDetailsViewControllerPreview(style: .light, contentSize: .extraExtraExtraLarge)
    }

    @available(iOS 17.0, *)
    #Preview("Dark · XXXL") {
        makeFactDetailsViewControllerPreview(style: .dark, contentSize: .extraExtraExtraLarge)
    }

    @available(iOS 17.0, *)
    #Preview("Light · Accessibility XXXL") {
        makeFactDetailsViewControllerPreview(style: .light, contentSize: .accessibilityExtraExtraExtraLarge)
    }

    @available(iOS 17.0, *)
    #Preview("Dark · Accessibility XXXL") {
        makeFactDetailsViewControllerPreview(style: .dark, contentSize: .accessibilityExtraExtraExtraLarge)
    }
#endif

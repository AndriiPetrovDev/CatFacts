import UIKit

final class FactDetailsViewController: UIViewController {
    private let viewModel: FactDetailsViewModel

    private lazy var contentView: FactDetailsView = {
        let view = FactDetailsView()
        view.configure(title: viewModel.title, text: viewModel.text, isVerified: viewModel.isVerified, isNew: viewModel.isNew)
        return view
    }()

    init(viewModel: FactDetailsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = contentView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Fact Details"
        navigationItem.largeTitleDisplayMode = .never
    }
}

#if DEBUG
    @available(iOS 17.0, *)
    @MainActor
    private func makeFactDetailsViewControllerPreview(style: UIUserInterfaceStyle, contentSize: UIContentSizeCategory) -> UINavigationController {
        let fact = CatFact(
            id: "preview",
            text: "A cat's whiskers help it sense nearby objects and navigate narrow spaces, even in the dark.",
            createdAt: Date(),
            isVerified: true
        )
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

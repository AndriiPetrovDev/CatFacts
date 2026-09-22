import UIKit

final class FactDetailsViewController: UIViewController {
    private let viewModel: FactDetailsViewModel
    private let contentView = FactDetailsView()

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
        contentView.configure(title: viewModel.title, text: viewModel.text)
    }
}

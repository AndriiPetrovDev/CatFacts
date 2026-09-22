import UIKit

final class FactDetailsViewController: UIViewController {
    private let viewModel: FactDetailsViewModel

    private lazy var contentView: FactDetailsView = {
        let view = FactDetailsView()
        view.configure(title: viewModel.title, text: viewModel.text, isVerified: viewModel.isVerified)
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

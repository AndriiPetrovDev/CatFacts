import UIKit
import SnapKit

final class FactDetailsView: UIView {
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let textLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground

        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header

        textLabel.font = .preferredFont(forTextStyle: .body)
        textLabel.adjustsFontForContentSizeCategory = true
        textLabel.numberOfLines = 0
        textLabel.textColor = .secondaryLabel

        addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(textLabel)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(safeAreaLayoutGuide)
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(24)
        }

        textLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.leading.trailing.bottom.equalToSuperview().inset(24)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(title: String, text: String) {
        titleLabel.text = title
        textLabel.text = text
    }
}

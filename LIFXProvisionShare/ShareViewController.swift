/// Share Extension: receives an image from the share sheet,
/// shows a preview for confirmation, then saves to the App Group container.

import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private var sharedImageData: Data?

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Use this screenshot?"
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "LIFX Provision will scan this image for bulb SSIDs"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let acceptButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Accept", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17)
        button.tintColor = .secondaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        layoutUI()
        loadSharedImage()
    }

    private func layoutUI() {
        let buttonStack = UIStackView(arrangedSubviews: [cancelButton, acceptButton])
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 16
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(imageView)
        view.addSubview(subtitleLabel)
        view.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            imageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            imageView.bottomAnchor.constraint(equalTo: subtitleLabel.topAnchor, constant: -16),

            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            subtitleLabel.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -20),

            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            buttonStack.heightAnchor.constraint(equalToConstant: 50),
        ])

        acceptButton.addTarget(self, action: #selector(acceptTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    }

    private func loadSharedImage() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            close()
            return
        }

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] item, _ in
                    var imageData: Data?

                    if let url = item as? URL {
                        imageData = try? Data(contentsOf: url)
                    } else if let data = item as? Data {
                        imageData = data
                    } else if let image = item as? UIImage {
                        imageData = image.pngData()
                    }

                    DispatchQueue.main.async {
                        self?.sharedImageData = imageData
                        if let data = imageData, let image = UIImage(data: data) {
                            self?.imageView.image = image
                        } else {
                            self?.close()
                        }
                    }
                }
                return
            }
        }

        close()
    }

    @objc private func acceptTapped() {
        if let data = sharedImageData {
            saveToAppGroup(data)
        }
        close()
    }

    @objc private func cancelTapped() {
        close()
    }

    private func saveToAppGroup(_ data: Data) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.lifxprovision.shared"
        ) else { return }

        let fileURL = containerURL.appendingPathComponent("shared_screenshot.png")
        try? data.write(to: fileURL)
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

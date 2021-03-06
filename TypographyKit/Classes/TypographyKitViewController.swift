//
//  TypographyKitViewController.swift
//  TypographyKit
//
//  Created by Ross Butler on 9/10/18.
//

import Foundation

class TypographyKitViewController: UITableViewController {

    // MARK: Type definitions
    public typealias Delegate = TypographyKitViewControllerDelegate
    public typealias NavigationSettings = ViewControllerNavigationSettings

    // MARK: State
    weak var delegate: Delegate?
    var navigationSettings: NavigationSettings?
    private var typographyStyleNames: [String] = []

    override func viewDidLoad() {
        title = "TypographyKit Styles"
        typographyStyleNames = TypographyKit.fontTextStyles.map({ $0.key }).sorted()
        configureView()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return typographyStyleNames.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellReuseIdentifier = String(describing: TypographyKitTableViewCell.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
        let typographyStyleName = typographyStyleNames[indexPath.row]
        guard let typographyKitCell = cell as? TypographyKitTableViewCell,
            let typographyStyle = TypographyKit.fontTextStyles[typographyStyleName] else {
            return cell
        }
        typographyKitCell.typographyStyleName.text = typographyStyleName
        typographyKitCell.typographyStyleName.fontTextStyleName = typographyStyleName
        var typographyStyleDetails: String = ""
        if let fontName = typographyStyle.fontName, let pointSize = typographyStyle.pointSize {
            typographyStyleDetails = "\(fontName) @ \(pointSize)pt"
            if let textColor = typographyStyle.textColor, let colorName = TypographyKit.colorName(color: textColor) {
                typographyStyleDetails.append(" in \(colorName.capitalized)")
            }
            if let letterCase = typographyStyle.letterCase, !letterCase.description.isEmpty {
                typographyStyleDetails.append(", \(letterCase.description)")
            }
        }
        typographyKitCell.typographyStyleDetails.text = typographyStyleDetails
        typographyKitCell.typographyStyleDetails.textColor = typographyStyle.textColor
        if let typographyColor = typographyStyle.textColor, colorIsBright(color: typographyColor) {
            typographyKitCell.contentView.backgroundColor = UIColor.gray
        } else {
            typographyKitCell.contentView.backgroundColor = UIColor.white
        }
        return typographyKitCell
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 150
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    private func colorIsBright(color: UIColor) -> Bool {
        let brightnessThreshold: CGFloat = 0.8
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let colorBrightness = (red * 0.299) + (green * 0.587) + (blue * 0.114)
        return colorBrightness > brightnessThreshold
    }
}

private extension TypographyKitViewController {

    private func configureNavigationBar() {
        let closeButtonType = navigationSettings?.closeButton ?? .done
        let doneButton = UIBarButtonItem(barButtonSystemItem: closeButtonType,
                                         target: self,
                                         action: #selector(close))
        let exportButton = UIBarButtonItem(title: "Export", style: .plain, target: self, action: #selector(export))
        let closeButtonAlignment = navigationSettings?.closeButtonAlignment ?? .closeButtonLeftExportButtonRight
        switch closeButtonAlignment {
        case .closeButtonLeftExportButtonRight:
            navigationItem.leftBarButtonItem = doneButton
            navigationItem.rightBarButtonItem = exportButton
        case .closeButtonRightExportButtonLeft:
            navigationItem.leftBarButtonItem = exportButton
            navigationItem.rightBarButtonItem = doneButton
        case .noCloseButtonExportButtonLeft:
            navigationItem.leftBarButtonItem = exportButton
        case .noCloseButtonExportButtonRight:
            navigationItem.rightBarButtonItem = exportButton
        }
        navigationItem.leftItemsSupplementBackButton = true
    }

    private func configureTableView() {
        let cellReuseIdentifier = String(describing: TypographyKitTableViewCell.self)
        let cellNib = UINib(nibName: cellReuseIdentifier, bundle: Bundle(for: type(of: self)))
        tableView.register(cellNib, forCellReuseIdentifier: cellReuseIdentifier)
        tableView.dataSource = self
        tableView.estimatedRowHeight = 150
        tableView.rowHeight = UITableView.automaticDimension
    }

    func configureView() {
        configureNavigationBar()
        configureTableView()
    }

    @objc func close() {
        if viewControllerShouldDismiss() {
            let isAnimated: Bool = navigationSettings?.animated ?? true
            let isModal: Bool = navigationSettings?.isModal ?? (navigationController == nil)
            
            if isModal {
                dismiss(animated: isAnimated, completion: nil)
            } else {
                hideNavigationBarIfNeeded()
                navigationController?.popViewController(animated: isAnimated)
            }
        }
        delegate?.viewControllerDidFinish()
    }

    @objc func export() {
        var deltaY: CGFloat = 0
        var pageY: CGFloat = 0
        let tableViewContentRect = CGRect(origin: CGPoint.zero, size: tableView.contentSize)
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, tableViewContentRect, nil)
        UIGraphicsBeginPDFPage()
        guard let pdfContext = UIGraphicsGetCurrentContext() else { return }
        for section in 0..<tableView.numberOfSections {
            for row in 0..<tableView.numberOfRows(inSection: section) {
                let indexPath = IndexPath(row: row, section: section)
                let cell = self.tableView(tableView, cellForRowAt: indexPath)
                cell.updateConstraintsIfNeeded()
                cell.layoutIfNeeded()
                pdfContext.translateBy(x: 0, y: deltaY)
                if pageY + cell.contentView.frame.size.height > tableView.contentSize.height {
                    UIGraphicsBeginPDFPage()
                    pageY = 0
                }
                cell.contentView.layer.render(in: pdfContext)
                deltaY = cell.contentView.frame.size.height
                pageY += deltaY
            }
        }
        UIGraphicsEndPDFContext()
        let activityViewController = UIActivityViewController(activityItems: [pdfData], applicationActivities: nil)
        if UIDevice.current.userInterfaceIdiom == .pad {
            activityViewController.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(activityViewController, animated: true, completion: nil)
    }
    
    /// Hides or unhides the navigation bar according to navigational preferences.
    private func hideNavigationBarIfNeeded() {
        let isNavigationBarHidden: Bool? = navigationSettings?.isNavigationBarHidden
        if let isNavigationBarHidden = isNavigationBarHidden {
            navigationController?.isNavigationBarHidden = isNavigationBarHidden
        }
    }
    
    /// Determines whether or not this view controller should dismiss itself
    /// or whether code outside the controller is responsible for this.
    private func viewControllerShouldDismiss() -> Bool {
        return navigationSettings?.autoClose ?? true // default to auto-close
    }
    
}

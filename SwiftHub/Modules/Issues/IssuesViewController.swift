//
//  IssuesViewController.swift
//  SwiftHub
//
//  Created by Sygnoos9 on 11/20/18.
//  Copyright © 2018 Khoren Markosyan. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources

private let reuseIdentifier = R.reuseIdentifier.issueCell.identifier

enum IssueSegments: Int {
    case open, closed

    var title: String {
        switch self {
        case .open: return R.string.localizable.issuesOpenSegmentTitle.key.localized()
        case .closed: return R.string.localizable.issuesClosedSegmentTitle.key.localized()
        }
    }

    var state: State {
        switch self {
        case .open: return .open
        case .closed: return .closed
        }
    }
}

class IssuesViewController: TableViewController {

    var viewModel: IssuesViewModel!

    lazy var segmentedControl: SegmentedControl = {
        let items = [IssueSegments.open.title,
                     IssueSegments.closed.title]
        let view = SegmentedControl(items: items)
        view.selectedSegmentIndex = 0
        return view
    }()

    lazy var ownerImageView: SlideImageView = {
        let view = SlideImageView()
        view.cornerRadius = 40
        return view
    }()

    lazy var headerView: View = {
        let view = View()
        view.hero.id = "TopHeaderId"
        view.addSubview(self.ownerImageView)
        self.ownerImageView.snp.makeConstraints({ (make) in
            make.top.equalToSuperview().inset(self.inset)
            make.centerX.centerY.equalToSuperview()
            make.size.equalTo(80)
        })
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func makeUI() {
        super.makeUI()

        navigationItem.titleView = segmentedControl

        languageChanged.subscribe(onNext: { [weak self] () in
            self?.segmentedControl.setTitle(IssueSegments.open.title, forSegmentAt: 0)
            self?.segmentedControl.setTitle(IssueSegments.closed.title, forSegmentAt: 1)
        }).disposed(by: rx.disposeBag)

        themeService.rx
            .bind({ $0.primaryDark }, to: headerView.rx.backgroundColor)
            .disposed(by: rx.disposeBag)

        stackView.insertArrangedSubview(headerView, at: 0)

        tableView.register(R.nib.issueCell)
    }

    override func bindViewModel() {
        super.bindViewModel()

        let segmentSelected = Observable.of(segmentedControl.rx.selectedSegmentIndex.map { IssueSegments(rawValue: $0)! }).merge()
        let refresh = Observable.of(Observable.just(()), headerRefreshTrigger, segmentSelected.mapToVoid().skip(1)).merge()
        let input = IssuesViewModel.Input(headerRefresh: refresh,
                                          footerRefresh: footerRefreshTrigger,
                                          segmentSelection: segmentSelected,
                                          selection: tableView.rx.modelSelected(IssueCellViewModel.self).asDriver())
        let output = viewModel.transform(input: input)

        viewModel.loading.asObservable().bind(to: isLoading).disposed(by: rx.disposeBag)
        viewModel.headerLoading.asObservable().bind(to: isHeaderLoading).disposed(by: rx.disposeBag)
        viewModel.footerLoading.asObservable().bind(to: isFooterLoading).disposed(by: rx.disposeBag)

        output.navigationTitle.drive(onNext: { [weak self] (title) in
            self?.navigationTitle = title
        }).disposed(by: rx.disposeBag)

        output.imageUrl.drive(onNext: { [weak self] (url) in
            if let url = url {
                self?.ownerImageView.setSources(sources: [url])
                self?.ownerImageView.hero.id = url.absoluteString
            }
        }).disposed(by: rx.disposeBag)

        output.items.asDriver(onErrorJustReturn: [])
            .drive(tableView.rx.items(cellIdentifier: reuseIdentifier, cellType: IssueCell.self)) { tableView, viewModel, cell in
                cell.bind(to: viewModel)
            }.disposed(by: rx.disposeBag)

        output.userSelected.drive(onNext: { [weak self] (viewModel) in
            self?.navigator.show(segue: .userDetails(viewModel: viewModel), sender: self, transition: .detail)
        }).disposed(by: rx.disposeBag)

        output.issueSelected.drive(onNext: { [weak self] (url) in
            if let url  = url {
                self?.navigator.show(segue: .webController(url), sender: self)
            }
        }).disposed(by: rx.disposeBag)

        viewModel.error.asDriver().drive(onNext: { [weak self] (error) in
            self?.showAlert(title: R.string.localizable.commonError.key.localized(), message: error.localizedDescription)
        }).disposed(by: rx.disposeBag)
    }
}

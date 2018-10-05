// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import Result
import TrustKeystore

protocol TransactionCoordinatorDelegate: class, CanOpenURL {
    func didPress(for type: PaymentFlow, in coordinator: TransactionCoordinator)
    func didCancel(in coordinator: TransactionCoordinator)
}

class TransactionCoordinator: Coordinator {
    private let keystore: Keystore
    private let storage: TransactionsStorage

    lazy var rootViewController: TransactionsViewController = {
        return makeTransactionsController(with: session.account)
    }()

    lazy var dataCoordinator: TransactionDataCoordinator = {
        let coordinator = TransactionDataCoordinator(
            session: session,
            storage: storage,
            keystore: keystore
        )
        return coordinator
    }()

    weak var delegate: TransactionCoordinatorDelegate?

    let session: WalletSession
    let tokensStorage: TokensDataStore
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    init(
        session: WalletSession,
        navigationController: UINavigationController = NavigationController(),
        storage: TransactionsStorage,
        keystore: Keystore,
        tokensStorage: TokensDataStore
    ) {
        self.session = session
        self.keystore = keystore
        self.navigationController = navigationController
        self.storage = storage
        self.tokensStorage = tokensStorage

        NotificationCenter.default.addObserver(self, selector: #selector(didEnterForeground), name: .UIApplicationWillEnterForeground, object: nil)
    }

    func start() {
        navigationController.viewControllers = [rootViewController]
    }

    private func makeTransactionsController(with account: Wallet) -> TransactionsViewController {
        let viewModel = TransactionsViewModel()
        let controller = TransactionsViewController(
            account: account,
            dataCoordinator: dataCoordinator,
            session: session,
            tokensStorage: tokensStorage,
            viewModel: viewModel
        )

        let rightItems: [UIBarButtonItem] = {
            switch viewModel.isBuyActionAvailable {
            case true:
                return [
                    UIBarButtonItem(image: R.image.deposit(), landscapeImagePhone: R.image.deposit(), style: .done, target: self, action: #selector(deposit)),
                ]
            case false: return []
            }
        }()
        controller.navigationItem.rightBarButtonItems = rightItems
        controller.delegate = self
        return controller
    }

    func showTransaction(_ transaction: Transaction) {
        let controller = TransactionViewController(
                session: session,
                transaction: transaction,
                delegate: self
        )
        if UIDevice.current.userInterfaceIdiom == .pad {
            let nav = UINavigationController(rootViewController: controller)
            nav.modalPresentationStyle = .formSheet
            controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: self, action: #selector(dismiss))
            navigationController.present(nav, animated: true, completion: nil)
        } else {
            navigationController.pushViewController(controller, animated: true)
        }
    }

    @objc func didEnterForeground() {
        rootViewController.fetch()
    }

    @objc func dismiss() {
        navigationController.dismiss(animated: true, completion: nil)
    }

    func stop() {
        dataCoordinator.stop()
        session.stop()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func deposit(sender: UIBarButtonItem) {
        showDeposit(for: session.account, from: sender)
    }

    func showDeposit(for account: Wallet, from barButtonItem: UIBarButtonItem? = .none) {
        let coordinator = DepositCoordinator(
            navigationController: navigationController,
            account: account,
            delegate: self
        )
        coordinator.start(from: barButtonItem)
    }
}

extension TransactionCoordinator: TransactionsViewControllerDelegate {
    func didPressSend(in viewController: TransactionsViewController) {
        if let type = viewController.paymentType {
            delegate?.didPress(for: type, in: self)
        } else {
            delegate?.didPress(for: .send(type: .ether(config: session.config, destination: .none)), in: self)
        }
    }

    func didPressTransaction(transaction: Transaction, in viewController: TransactionsViewController) {
        showTransaction(transaction)
    }

    func didPressDeposit(for account: Wallet, sender: UIView, in viewController: TransactionsViewController) {
        let coordinator = DepositCoordinator(
            navigationController: navigationController,
            account: account,
            delegate: self
        )
        coordinator.start(from: sender)
    }

    func reset() {
        delegate?.didCancel(in: self)
    }
}

extension TransactionCoordinator: CanOpenURL {
    func didPressViewContractWebPage(forContract contract: String, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}

extension TransactionCoordinator: TransactionViewControllerDelegate {
}

extension TransactionCoordinator: DepositCoordinatorDelegate {
}

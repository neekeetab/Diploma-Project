//
//  ViewController.swift
//  StateMachine
//
//  Created by Nikita Belousov on 5/18/19.
//  Copyright © 2019 Nikita Belousov. All rights reserved.
//

import UIKit
import ReactiveSwift
import ReactiveCocoa
import Result

/// To be conformed by your actions.
/// - Actions are represented as structs and typically don't contain any logic.
/// - States shouldn't perform any side effects.
protocol ActionType {}

/// To be conformed by your state enums.
/// - States are represented as enums and typically don't contain any logic.
/// - States shouldn't perform any side effects.
protocol StateType {}


/// Takes `Action`s and forwards them to all interested parties.
/// - You use `actions` property to subsribe to the forwarded actions.
/// - You tipically have one instance of the `Dispatcher` within your app.
/// For that use `shared` property.
class Dispatcher {
    
    static let shared = Dispatcher()
    
    let actions: Signal<ActionType, NoError>
    
    func dispatch(action: ActionType) {
        observer.send(value: action)
    }
    
    private let observer: Signal<ActionType, NoError>.Observer
    
    init() {
        (actions, observer) = Signal.pipe()
    }
    
}

/// Represents a finite-state machine.
class StateMachine<State: StateType, Action: ActionType> {
    
    /// Takes a state and an action and returns a new state.
    /// - For each pair of state and action there should be at most one case of state returned.
    /// In case the pair of state and action is not in processable by the instance of the
    /// transition function, nil should be returned.
    /// – Above guarantees the property of the finite-state machine – the later
    /// should always know what's the next state given the current state and an action.
    typealias TransitionFunction = (State, Action) -> State?
    
    let currentState: MutableProperty<State>
    
    func apply(action: Action) {
        for transitionFunction in transitionFunctionList {
            if let newState = transitionFunction(currentState.value, action) {
                currentState.value = newState
                break
            }
        }
    }
    
    private let transitionFunctionList: [TransitionFunction]
    
    init(state: State, transitionFunctionList: [TransitionFunction]) {
        
        currentState = MutableProperty(state)
        self.transitionFunctionList = transitionFunctionList
        
    }
    
}

/// Container for a state machine. Observes actions forwared by `dispatcher`
/// and applies them to the state maachine.
class Store<State: StateType, Action: ActionType> {
    
    let currentState: MutableProperty<State>
    
    private let stateMachine: StateMachine<State, Action>
    
    init(dispatcher: Dispatcher, initialState: State, transitionFunctionList: [StateMachine<State, Action>.TransitionFunction]) {
        stateMachine = StateMachine<State, Action>(state: initialState, transitionFunctionList: transitionFunctionList)
        currentState = stateMachine.currentState
        dispatcher.actions
            .take(duringLifetimeOf: self)
            .filterMap { $0 as? Action }
            .on(value: { [unowned self] in
                self.stateMachine.apply(action: $0)
            })
            .observeCompleted { }
    }
    
}

/// Represents a unit of something that you usually get in paginated
/// server responses
struct Item {
    let value: String
}

enum Error: Swift.Error { }

/// Mimics a real network service for demo purposes
class NetworkService {
    
    struct ItemsResponse {
        let items: [Item]
        let total: UInt
    }
    
    static func items(offset: UInt, size: UInt, completionBlock: @escaping (Result<ItemsResponse, Error>) -> ()) {
        
        let text = """
            To be, or not to be, that is the question:
            Whether 'tis nobler in the mind to suffer
            The slings and arrows of outrageous fortune,
            Or to take arms against a sea of troubles
            And by opposing end them. To die—to sleep,
            No more; and by a sleep to say we end
            The heart-ache and the thousand natural shocks
            That flesh is heir to: 'tis a consummation
            Devoutly to be wish'd. To die, to sleep;
            To sleep, perchance to dream—ay, there's the rub:
            For in that sleep of death what dreams may come,
            When we have shuffled off this mortal coil,
            Must give us pause—there's the respect
            That makes calamity of so long life.
            For who would bear the whips and scorns of time,
            Th'oppressor's wrong, the proud man's contumely,
            The pangs of dispriz'd love, the law's delay,
            The insolence of office, and the spurns
            That patient merit of th'unworthy takes,
            When he himself might his quietus make
            With a bare bodkin? Who would fardels bear,
            To grunt and sweat under a weary life,
            But that the dread of something after death,
            The undiscovere'd country, from whose bourn
            No traveller returns, puzzles the will,
            And makes us rather bear those ills we have
            Than fly to others that we know not of?
            Thus conscience does make cowards of us all,
            And thus the native hue of resolution
            Is sicklied o'er with the pale cast of thought,
            And enterprises of great pitch and moment
            With this regard their currents turn awry
            And lose the name of action.
        """
        
        let lines = text.split(separator: "\n")
        let total = UInt(lines.count)
        let items = Array(offset ..< min(offset + size, total)).map { Item(value: String(lines[Int($0)])) }
        let response = ItemsResponse(items: items, total: total)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // add delay for demo purposes
            completionBlock(Result<ItemsResponse, Error>.success(response))
        }
        
    }
    
}

class ViewModel {
    
    typealias DataSource = [Item]
    
    enum State: StateType {
        case initial
        case isLoadingFirstPage
        case isReloading(DataSource)
        case idle(DataSource)
        case isLoadingAdditionalPage(DataSource)
        case loaded(DataSource)
        case error(Error)
    }
    
    enum Action: ActionType {
        case startLoading
        case loadNextPage
        case loadedThereIsMore(DataSource)
        case loaded(DataSource)
        case loadingFailed(Error)
        case reload
    }
    
    static func transitionFunction1(state: State, action: Action) -> State? {
        switch (state, action) {
        case (.initial, .startLoading):
            return .isLoadingFirstPage
        default:
            return nil
        }
    }
    
    static func transitionFunction2(state: State, action: Action) -> State? {
        switch (state, action) {
        case (.isLoadingFirstPage, .loadingFailed(let error)):
            return .error(error)
        default:
            return nil
        }
    }
    
    static func transitionFunction3(state: State, action: Action) -> State? {
        switch (state, action) {
        case (.isLoadingFirstPage, .loadedThereIsMore(let dataSource)):
            return .idle(dataSource)
        default:
            return nil
        }
    }
    
    static func transitionFunction4(state: State, action: Action) -> State? {
        switch (state, action) {
        case (.isLoadingFirstPage, .loaded(let dataSource)):
            return .loaded(dataSource)
        default:
            return nil
        }
    }
    
    static func transitionFunction5(state: State, action: Action) -> State? {
        switch (state, action) {
        case (.isLoadingAdditionalPage(let previousDataSource), .loadedThereIsMore(let newDataSource)):
            return .idle(previousDataSource + newDataSource)
        default:
            return nil
        }
    }
    
    static func transitionFunction6(state: State, action: Action) -> State? {
        switch (state, action) {
        case (.idle(let dataSource), .loadNextPage):
            return .isLoadingAdditionalPage(dataSource)
        default:
            return nil
        }
    }
    
    static func transitionFunction7(state: State, action: Action) -> State? {
        switch (state, action) {
        case (.isLoadingAdditionalPage(let previousDataSource), .loaded(let newDataSource)):
            return .loaded(previousDataSource + newDataSource)
        default:
            return nil
        }
    }
    
    static func transitionFunction8(state: State, action: Action) -> State? {
        switch (state, action) {
        case (.isLoadingAdditionalPage(_), .loadingFailed(let error)):
            return .error(error)
        default:
            return nil
        }
    }
    
    static func transitionFunction9(state: State, action: Action) -> State? {
        switch (state, action) {
        case (.idle(let dataSource), .reload):
            return .isReloading(dataSource)
        default:
            return nil
        }
    }
    
    static func transitionFunction10(state: State, action: Action) -> State? {
        switch (state, action) {
        case (.isReloading(_), .loadedThereIsMore(let dataSource)):
            return .idle(dataSource)
        default:
            return nil
        }
    }
    
    static func transitionFunction11(state: State, action: Action) -> State? {
        switch (state, action) {
        case (.loaded(let dataSource), .reload):
            return .isReloading(dataSource)
        default:
            return nil
        }
    }
    
    static func transitionFunction12(state: State, action: Action) -> State? {
        switch (state, action) {
        case (.isReloading(_), .loadingFailed(let error)):
            return .error(error)
        default:
            return nil
        }
    }
    
    let store = Store<State, Action>(dispatcher: Dispatcher.shared, initialState: .initial, transitionFunctionList: [
        transitionFunction1,
        transitionFunction2,
        transitionFunction3,
        transitionFunction4,
        transitionFunction5,
        transitionFunction6,
        transitionFunction7,
        transitionFunction8,
        transitionFunction9,
        transitionFunction10,
        transitionFunction11,
        transitionFunction12])
    
    private let pageSize: UInt = 5
    
    func apply(_ action: Action) {
        
        Dispatcher.shared.dispatch(action: action)
        
        switch action {
        case .startLoading, .loadNextPage:
            let currentNumberOfItems = UInt(store.currentState.value.dataSource?.count ?? 0)
            NetworkService.items(offset: currentNumberOfItems, size: pageSize) { response in
                switch response {
                case .success(let response):
                    Dispatcher.shared.dispatch(action: response.items.count >= response.total ? Action.loaded(response.items) : Action.loadedThereIsMore(response.items))
                case .failure(let error):
                    Dispatcher.shared.dispatch(action: Action.loadingFailed(error))
                }
            }
        case .reload:
            NetworkService.items(offset: 0, size: pageSize) { response in
                switch response {
                case .success(let response):
                    Dispatcher.shared.dispatch(action: response.items.count >= response.total ? Action.loaded(response.items) : Action.loadedThereIsMore(response.items))
                case .failure(let error):
                    Dispatcher.shared.dispatch(action: Action.loadingFailed(error))
                }
            }
        default:
            break
        }
        
    }
    
}

extension Reactive where Base: UITableView {
    
    // Binding target for UITableView's tableFooterView property
    var tableFooterView: BindingTarget<UIView?> {
        return makeBindingTarget { tableView, view in
            tableView.tableFooterView = view
        }
    }
    
}

class ViewWithActivityIndicatorInIt: UIView {
    
    let activityIndicatorView: UIActivityIndicatorView
    
    override init(frame: CGRect) {
        activityIndicatorView = UIActivityIndicatorView(style: .gray)
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        super.init(frame: frame)
        self.addSubview(activityIndicatorView)
        activityIndicatorView.startAnimating()
        activityIndicatorView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        activityIndicatorView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
    }
    
}

class ViewController: UIViewController {

    let viewModel = ViewModel()
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var initialLoadActivityIndicatorView: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup refresh control
        let refreshControl = UIRefreshControl()
        if #available(iOS 10.0, *) {
            tableView.refreshControl = refreshControl
        } else {
            tableView.addSubview(refreshControl)
        }
        
        // Apply state changes to refresh control
        refreshControl.reactive.isRefreshing <~ viewModel.store.currentState.producer.filterMap {
            switch $0 {
            case .isReloading(_):
                return true
            default:
                return false
            }
        }
        
        // observe refresh events
        refreshControl.reactive.controlEvents(.valueChanged)
            .take(duringLifetimeOf: self)
            .on(value: { [unowned self] _ in
                self.viewModel.apply(.reload)
            })
            .observeCompleted { }
        
        // setup activity indicator at the bottom
        let activityIndicatorHolder = ViewWithActivityIndicatorInIt(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 60))
        let dummyViewToHideSeparatorsAtTheBottom = UIView()
        tableView.reactive.tableFooterView <~ viewModel.store.currentState.map { state -> UIView? in
            switch state {
            case .isLoadingAdditionalPage(_):
                return activityIndicatorHolder
            default:
                return dummyViewToHideSeparatorsAtTheBottom
            }
        }
        
        // reload table view on each change in data source
        tableView.reactive.reloadData <~ viewModel.store.currentState.signal.map { _ in () }
        
        // hide initialLoadActivityIndicatorView after the initial load
        initialLoadActivityIndicatorView.reactive.isHidden <~
            viewModel.store.currentState.producer.map {
            switch $0 {
            case .isLoadingFirstPage:
                return false
            default:
                return true
            }
        }
        
        // start loading
        viewModel.apply(.startLoading)
        
    }

}

extension ViewModel.State {
    var dataSource: ViewModel.DataSource? {
        switch self {
        case .idle(let dataSource), .isLoadingAdditionalPage(let dataSource), .isReloading(let dataSource), .loaded(let dataSource):
            return dataSource
        default:
            return nil
        }
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.store.currentState.value.dataSource?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = viewModel.store.currentState.value.dataSource![indexPath.row].value
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == viewModel.store.currentState.value.dataSource!.count - 1 {
            if case .idle = viewModel.store.currentState.value {
                viewModel.apply(.loadNextPage)
            }
        }
    }
    
}

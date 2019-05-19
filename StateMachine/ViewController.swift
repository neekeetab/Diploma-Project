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
import enum Result.NoError

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

/// Mimics a real network service for demo purposes
class NetworkService {
    
    enum Error: Swift.Error {
        case some
    }
    
    struct ItemsResponse {
        let items: [Item]
        let total: UInt
    }
    
    static func items(offset: UInt, size: UInt) -> SignalProducer<ItemsResponse, Error> {
        
        let lyricsToTheBestSongEver = """
            We're no strangers to love
            You know the rules and so do I
            A full commitment's what I'm thinking of
            You wouldn't get this from any other guy
            I just wanna tell you how I'm feeling
            Gotta make you understand
            Never gonna give you up
            Never gonna let you down
            Never gonna run around and desert you
            Never gonna make you cry
            Never gonna say goodbye
            Never gonna tell a lie and hurt you
            We've known each other for so long
            Your heart's been aching but you're too shy to say it
            Inside we both know what's been going on
            We know the game and we're gonna play it
            And if you ask me how I'm feeling
            Don't tell me you're too blind to see
            Never gonna give you up
            Never gonna let you down
            Never gonna run around and desert you
            Never gonna make you cry
            Never gonna say goodbye
            Never gonna…
        """
        
        let lines = lyricsToTheBestSongEver.split(separator: "\n")
        let total = UInt(lines.count)
        let items = Array(offset ..< min(offset + size, total)).map { Item(value: String(lines[Int($0)])) }
        let response = ItemsResponse(items: items, total: total)
        
        return SignalProducer([response])
            // add delay for demo purposes
            .delay(0.5, on: QueueScheduler.main)
    }
    
}

class ViewModel {
    
    typealias DataSource = [Item]
    
    enum Error: Swift.Error { }
    
    enum State: StateType {
        case initial
        case isLoadingFirstPage
        case isReloadaing(DataSource)
        case idle(DataSource)
        case isLoadingAdditionalPage(DataSource)
        case loaded(DataSource)
        case error(Error)
    }
    
    enum Action: ActionType {
        case startLoading
        case loadNextPage
        case loadedThereIsMore
        case loaded
        case loadingFailed
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
        case (.initial, .startLoading):
            return .isLoadingFirstPage
        default:
            return nil
        }
    }
    
    let store = Store<State, Action>(dispatcher: Dispatcher.shared, initialState: .initial, transitionFunctionList: [
        transitionFunction1,
        transitionFunction2])
    
    func apply(_ action: Action) {
        
        Dispatcher.shared.dispatch(action: action)
        
        switch action {
        case .startLoading:
            // fetch items here
            break
        case .loadNextPage:
            // fetch items here
            break
        case .reload:
            break
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
    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        viewModel.store.currentState
//            .producer
//            .take(duringLifetimeOf: self)
//
//    }
    
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
        
        refreshControl.reactive.isRefreshing <~ viewModel.store.currentState.producer.filterMap {
            switch $0 {
            case .isReloadaing(_):
                return true
            default:
                return false
            }
        }
        // TODO: set isEnabled, isHidden?
//        refreshControl.reactive.refresh = CocoaAction(viewModel.stapler.refreshAction)
        
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
//        tableView.reactive.tableFooterView <~ viewModel.stapler.shouldShowNextPageActivityIndicator
//            .map { $0 ? activityIndicatorHolder : dummyViewToHideSeparatorsAtTheBottom }
        
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
        case .idle(let dataSource), .isLoadingAdditionalPage(let dataSource), .isReloadaing(let dataSource), .loaded(let dataSource):
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

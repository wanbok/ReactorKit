//
//  ReactorSchedulerTests.swift
//  ReactorKitTests
//
//  Created by Suyeol Jeon on 2019/10/17.
//

import ReactorKit
import RxSwift
import XCTest

final class ReactorSchedulerTests: XCTestCase {
  func testStateStreamIsCreatedOnce() {
    final class SimpleReactor: Reactor {
      typealias Action = Never
      typealias Mutation = Never
      typealias State = Int

      let initialState: State = 0

      func transform(action: Observable<Action>) -> Observable<Action> {
        sleep(5)
        return action
      }
    }

    let reactor = SimpleReactor()
    var states: [Observable<SimpleReactor.State>] = []
    let lock = NSLock()

    for _ in 0..<100 {
      DispatchQueue.global().async {
        let state = reactor.state
        lock.lock()
        states.append(state)
        lock.unlock()
      }
    }

    XCTWaiter().wait(for: [XCTestExpectation()], timeout: 10)

    XCTAssertGreaterThan(states.count, 0)
    for state in states {
      XCTAssertTrue(state === states.first)
    }
  }

  func testScheduler() {
    final class SimpleReactor: Reactor {
      typealias Action = Void
      typealias Mutation = Void

      struct State {
        var reductionThreads: [Thread] = []
      }

      let initialState: State = State()
      let scheduler: ImmediateSchedulerType = SerialDispatchQueueScheduler(qos: .default)

      func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        let currentThread = Thread.current
        newState.reductionThreads.append(currentThread)
        return newState
      }
    }

    let reactor = SimpleReactor()
    let disposeBag = DisposeBag()

    var observationThreads: [Thread] = []

    reactor.state
      .subscribe(onNext: { _ in
        let currentThread = Thread.current
        observationThreads.append(currentThread)
      })
      .disposed(by: disposeBag)

    for _ in 0..<100 {
      reactor.action.onNext(Void())
    }

    XCTWaiter().wait(for: [XCTestExpectation()], timeout: 1)

    let reductionThreads = reactor.currentState.reductionThreads
    XCTAssertEqual(reductionThreads.count, 100)
    for thread in reductionThreads {
      XCTAssertNotEqual(thread, Thread.main)
    }

    XCTAssertEqual(observationThreads.count, 101) // +1 for initial state
    for thread in observationThreads {
      XCTAssertNotEqual(thread, Thread.main)
    }
  }
}

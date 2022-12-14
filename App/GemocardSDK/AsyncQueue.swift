//
//  AsyncQueue.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 07.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation

/// Queue data structure implements queue methods and can be used in different threads
struct AsyncQueue<T> {
    private let queue = DispatchQueue(label: "queue.operations", attributes: .concurrent)
    private var elements: [T] = []
    
    mutating func enqueue(_ value: T) {
        queue.sync(flags: .barrier) {
            self.elements.append(value)
        }
    }
    
    mutating func enqueueArray(_ array: [T]) {
        queue.sync(flags: .barrier) {
            self.elements = self.elements + array
        }
    }
    
    mutating func dequeue() -> T? {
        return queue.sync(flags: .barrier) {
            guard !self.elements.isEmpty else {
                return nil
            }
            return self.elements.removeFirst()
        }
    }
    
    mutating func getElementsAndClear() -> [T] {
        return queue.sync(flags: .barrier) {
            let elements = elements
            self.elements = []
            return elements
        }
    }
    
    mutating func clear() {
        queue.sync(flags: .barrier) {
            self.elements = []
        }
    }
    
    mutating func getlength() -> Int {
        return queue.sync(flags: .barrier) {
            return elements.count
        }
    }
    
    var head: T? {
        return queue.sync(flags: .barrier) {
            return elements.first
        }
    }
    
    var tail: T? {
        return queue.sync(flags: .barrier) {
            return elements.last
        }
    }
    
    var isEmpty: Bool {
        return queue.sync(flags: .barrier) {
            return elements.isEmpty
        }
    }
    
    var getElements: [T] {
        return queue.sync(flags: .barrier) {
            return elements
        }
    }
}

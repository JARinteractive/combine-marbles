import Foundation
import Combine

struct Operator: Hashable, Identifiable {
    static func == (lhs: Operator, rhs: Operator) -> Bool {
        lhs.id == rhs.id
    }
    
    var id: String { name }
    
    let name: String
    
    let sources: [PublisherViewModel<String>]
    let description: String
    let result: PublisherViewModel<String>
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Operator {
    static var map: Operator {
        let source = PublisherViewModel([
            Event(time: 0.25, type: .output("1")),
            Event(time: 0.5, type: .output("2")),
            Event(time: 0.75, type: .output("3")),
            Event(time: 1, type: .finished)
        ])
        
        let result = PublisherViewModel<String>(
            source.$events
                .map {
                    $0.map { $0.map { "\((Int($0) ?? 0) * 2)" } }
                }
                .eraseToAnyPublisher())
        return Operator(name: "map", sources: [source], description: "publisher1.map { $0 * 2 }", result: result)
    }
    
    static var filter: Operator {
        let source = PublisherViewModel([
            Event(time: 0.2, type: .output("1")),
            Event(time: 0.35, type: .output("2")),
            Event(time: 0.5, type: .output("3")),
            Event(time: 0.65, type: .output("4")),
            Event(time: 0.8, type: .output("5")),
            Event(time: 1, type: .finished)
        ])
        
        let result = PublisherViewModel<String>(
            source.$events
                .map {
                    $0.filter {
                        $0.isCompletion || ($0.value.map { Int($0) ?? -1 }?.isMultiple(of: 2) ?? false) }
                }
                .eraseToAnyPublisher())
        return Operator(name: "filter", sources: [source], description: "publisher1.filter { $0.isMultiple(of: 2) }", result: result)
    }
    
    static var prefix: Operator {
        let source = PublisherViewModel([
            Event(time: 0.2, type: .output("1")),
            Event(time: 0.35, type: .output("2")),
            Event(time: 0.5, type: .output("3")),
            Event(time: 0.65, type: .output("4")),
            Event(time: 0.8, type: .output("5")),
            Event(time: 1, type: .finished)
        ])
        
        let result = PublisherViewModel<String>(
            source.$events
                .map {
                    let values = Array($0.prefix(3))
                    return values + [Event(time: values.last?.time ?? 1, type: .finished)]
                }
                .eraseToAnyPublisher())
        return Operator(name: "prefix", sources: [source], description: "publisher1.prefix(3)", result: result)
    }
    
    static var removeDuplicates: Operator {
        let source = PublisherViewModel([
            Event(time: 0.1, type: .output("1")),
            Event(time: 0.25, type: .output("2")),
            Event(time: 0.4, type: .output("2")),
            Event(time: 0.55, type: .output("3")),
            Event(time: 0.7, type: .output("2")),
            Event(time: 0.85, type: .output("5")),
            Event(time: 1, type: .finished)
        ])
        
        let result = PublisherViewModel<String>(
            source.$events
                .map {
                    $0.reduce(into: [Event<String>]()) { result, event in
                        if event.value != result.last?.value {
                            result.append(event)
                        }
                    }
                }
                .eraseToAnyPublisher())
        return Operator(name: "removeDuplicates", sources: [source], description: "publisher1.removeDuplicates()", result: result)
    }
    
    static var combineLatest: Operator {
        let source1 = PublisherViewModel([
            Event(time: 0.25, type: .output("1")),
            Event(time: 0.5, type: .output("2")),
            Event(time: 0.7, type: .output("3")),
            Event(time: 1, type: .finished)
        ])
        let source2 = PublisherViewModel([
            Event(time: 0.1, type: .output("A")),
            Event(time: 0.4, type: .output("B")),
            Event(time: 0.8, type: .output("C")),
            Event(time: 1, type: .finished)
        ])
        
        let combine: AnyPublisher<[Event<String>], Never> = source1.$events.combineLatest(source2.$events) {
            let numbers = $0.map { (1, $0) }
            let letters = $1.map { (2, $0) }
            let sortedEvents = (numbers + letters).sorted { first, second in
                first.1.time < second.1.time
            }
            let output: [Event<String>] = sortedEvents.reduce([(String?, String?, CGFloat)]()) { result, eventAndStreamTuple in
                if let value = eventAndStreamTuple.1.value {
                    if eventAndStreamTuple.0 == 1 {
                        return result + [(value, result.last?.1, eventAndStreamTuple.1.time)]
                    } else {
                        return result + [(result.last?.0, value, eventAndStreamTuple.1.time)]
                    }
                } else {
                    return result
                }
            }.compactMap {
                guard let number = $0, let letter = $1 else {
                    return nil
                }
                let time = $2
                return Event<String>(time: time, type: .output("(\(number),\(letter))"))
            }
            return output + [numbers.last?.1 ?? Event(time: 1, type: .finished)]
        }.eraseToAnyPublisher()
        
        let result = PublisherViewModel<String>(combine)
        return Operator(name: "combineLatest", sources: [source1, source2], description: "publisher1.combineLatest(publisher2)", result: result)
    }
    
    static var merge: Operator {
        let source1 = PublisherViewModel([
            Event(time: 0.1, type: .output("A")),
            Event(time: 0.4, type: .output("B")),
            Event(time: 0.7, type: .output("C")),
            Event(time: 0.8, type: .finished)
        ])
        let source2 = PublisherViewModel([
            Event(time: 0.25, type: .output("D")),
            Event(time: 0.55, type: .output("E")),
            Event(time: 0.85, type: .output("F")),
            Event(time: 1, type: .finished)
        ])
        
        let flatMapped: AnyPublisher<[Event<String>], Never> = source1.$events.combineLatest(source2.$events) {
            let source1 = $0
            let source2 = $1
            
            return [source1, source2]
                .flatMap { $0 }
                .filter { !$0.isCompletion } + [source1.last ?? Event(time: 1, type: .finished)]
        }.eraseToAnyPublisher()
        
        let result = PublisherViewModel<String>(flatMapped)
        return Operator(name: "merge", sources: [source1, source2], description: "publisher1.merge(with: publisher2)", result: result)
    }
    
    static var zipOperator: Operator {
        let source1 = PublisherViewModel([
            Event(time: 0.1, type: .output("A")),
            Event(time: 0.4, type: .output("B")),
            Event(time: 0.7, type: .output("C")),
            Event(time: 0.8, type: .finished)
        ])
        let source2 = PublisherViewModel([
            Event(time: 0.25, type: .output("D")),
            Event(time: 0.55, type: .output("E")),
            Event(time: 0.85, type: .output("F")),
            Event(time: 0.9, type: .finished)
        ])
        
        let flatMapped: AnyPublisher<[Event<String>], Never> = source1.$events.combineLatest(source2.$events) {
            let source1Values = $0.filter { !$0.isCompletion }
            let source2Values = $1.filter { !$0.isCompletion }
            let source1Completion = $0.first { $0.isCompletion }
            let source2Completion = $1.first { $0.isCompletion }
            
            let values: [Event<String>] = zip(source1Values, source2Values).compactMap {
                switch ($0.type, $1.type) {
                case (.output(let value1), .output(let value2)):
                    return Event(time: max($0.time, $1.time), type: .output("(\(value1),\(value2))"))
                default:
                    return nil
                }
            }
            let completion: Event<String>
            if source2Completion?.time ?? 1 < source1Completion?.time ?? 1 {
                completion = Event(time: max(values.last?.time ?? 1, source2Completion?.time ?? 1), type: .finished)
            } else {
                completion = source1Completion ?? Event.init(time: 1, type: .finished)
            }
            return values + [completion]
        }.eraseToAnyPublisher()
        
        let result = PublisherViewModel<String>(flatMapped)
        return Operator(name: "zip", sources: [source1, source2], description: "publisher1.zip(with: publisher2)", result: result)
    }
    
    static var flatMap: Operator {
        let source1 = PublisherViewModel([
            Event(time: 0.02, type: .output("1")),
            Event(time: 0.35, type: .output("2")),
            Event(time: 0.7, type: .output("3")),
            Event(time: 1, type: .finished)
        ])
        let source2 = PublisherViewModel([
            Event(time: 0.05, type: .output("A")),
            Event(time: 0.15, type: .output("B")),
            Event(time: 0.25, type: .output("C")),
            Event(time: 0.35, type: .finished)
        ])
        
        let flatMapped: AnyPublisher<[Event<String>], Never> = source1.$events.combineLatest(source2.$events) {
            let numbers = $0
            let letters = $1
            
            return numbers.flatMap { (event: Event<String>) -> [Event<String>] in
                guard let number = event.value else { return [Event<String>]() }
                let baseTime = event.time
                return letters.compactMap {
                    guard let letter = $0.value else { return nil }
                    return Event(time: baseTime + $0.time, type: .output("(\(number),\(letter))"))
                }
            } + [numbers.last ?? Event(time: 1, type: .finished)]
        }.eraseToAnyPublisher()
        
        let result = PublisherViewModel<String>(flatMapped)
        return Operator(name: "flatMap", sources: [source1, source2], description: "publisher1.flatMap { value1 in publisher2.map { (value1, $0) } }", result: result)
    }
    
    static var switchToLatest: Operator {
        let source1 = PublisherViewModel([
            Event(time: 0.02, type: .output("1")),
            Event(time: 0.35, type: .output("2")),
            Event(time: 0.7, type: .output("3")),
            Event(time: 1, type: .finished)
        ])
        let source2 = PublisherViewModel([
            Event(time: 0.05, type: .output("A")),
            Event(time: 0.15, type: .output("B")),
            Event(time: 0.25, type: .output("C")),
            Event(time: 0.35, type: .finished)
        ])
        
        let flatMapped: AnyPublisher<[Event<String>], Never> = source1.$events.combineLatest(source2.$events) {
            let numbers = $0
            let letters = $1
            
            return numbers.reduce([Event<String>]()) { result, event in
                guard let number = event.value else { return result }
                return result.filter { $0.time < event.time } + letters.compactMap {
                    guard let letter = $0.value else { return nil }
                    return Event(time: event.time + $0.time, type: .output("(\(number),\(letter))"))
                }
            } + [numbers.last ?? Event(time: 1, type: .finished)]
        }.eraseToAnyPublisher()
        
        let result = PublisherViewModel<String>(flatMapped)
        return Operator(name: "switchToLatest", sources: [source1, source2], description: "publisher1.map { value1 in publisher2.map { (value1, $0) } }.switchToLatest()", result: result)
    }
    
    static var withLatestFrom: Operator {
        let source1 = PublisherViewModel([
            Event(time: 0.25, type: .output("1")),
            Event(time: 0.5, type: .output("2")),
            Event(time: 0.8, type: .output("3")),
            Event(time: 1, type: .finished)
        ])
        let source2 = PublisherViewModel([
            Event(time: 0.3, type: .output("A")),
            Event(time: 0.4, type: .output("B")),
            Event(time: 0.6, type: .output("C")),
            Event(time: 0.7, type: .finished)
        ])
        
        let flatMapped: AnyPublisher<[Event<String>], Never> = source1.$events.combineLatest(source2.$events) {
            let numbers = $0
            let letters = $1
            
            return numbers.compactMap { number in
                guard number.value != nil else { return number }
                let latestLetter = letters
                    .filter { $0.value != nil }
                    .last { $0.time < number.time }
                return latestLetter?.value.map {
                    Event(time: number.time, type: .output($0))
                }
            }
        }.eraseToAnyPublisher()
        
        let result = PublisherViewModel<String>(flatMapped)
        return Operator(name: "withLatestFrom*", sources: [source1, source2], description: "publisher1.withLatestFrom(publisher2)", result: result)
    }
}

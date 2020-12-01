import SwiftUI
import Combine

struct Event<T: Equatable>: Equatable {
    let time: CGFloat
    let type: EventType
    let id: UUID
    
    init(time: CGFloat, type: EventType, id: UUID = UUID()) {
        self.time = time
        self.type = type
        self.id = id
    }
    
    enum EventType: Equatable {
        case output(T)
        case finished
        case failure
    }
    
    func map<U>(_ transform: (T) -> U) -> Event<U> {
        switch type {
        case .output(let value):
            return Event<U>(time: time, type: .output(transform(value)))
        case .finished:
            return Event<U>(time: time, type: .finished)
        case .failure:
            return Event<U>(time: time, type: .failure)
        }
    }
    
    var value: T? {
        switch self.type {
        case .finished, .failure:
            return nil
        case .output(let value):
            return value
        }
    }
    
    var isCompletion: Bool {
        switch self.type {
        case .finished, .failure:
            return true
        case .output:
            return false
        }
    }
}

class PublisherViewModel<T: Equatable>: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    @Published var events = [Event<T>]()
    let allowInteraction: Bool
    
    init(_ events: [Event<T>]) {
        allowInteraction = true
        self.events = events
    }
    
    init(_ events: AnyPublisher<[Event<T>], Never>) {
        allowInteraction = false
        events.sink { [weak self] in
            self?.events = $0
                .sorted { $0.time < $1.time }
                .reduce(into: []) { result, next in
                    guard !(result.last?.isCompletion ?? false) else { return }
                    result.append(next)
                }
        }.store(in: &cancellables)
    }
    
    func updateTime(_ time: CGFloat, on event: Event<T>) {
        events = (events
                    .filter { $0.id != event.id } + [Event(time: time, type: event.type, id: event.id)])
            .map {
                if time < $0.time && (event.type == .finished || event.type == .failure) {
                    return Event(time: time, type: $0.type, id: $0.id)
                } else if time > $0.time && ($0.type == .finished || $0.type == .failure) {
                    return Event(time: time + 0.0000001, type: $0.type, id: $0.id)
                } else {
                    return $0
                }
            }
            .sorted { $0.time < $1.time }
    }
}

struct OperatorDetailView: View {
    let combineOperator: Operator
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                Text(combineOperator.name)
                    .font(.largeTitle)
                Divider()
                ForEach(Array(combineOperator.sources.enumerated()), id: \.0) {
                    PublisherView(viewModel: $0.1)
                        .id(combineOperator.name)
                        .padding(.horizontal, 10)
                }
                Divider()
                Text(combineOperator.description).font(.title).scaledToFit()
                Divider()
                PublisherView(viewModel: combineOperator.result)
                    .id("result")
                    .padding(.horizontal, 10)
            }
            .padding()
        }
    }
}


struct PublisherView: View {
    @ObservedObject var viewModel: PublisherViewModel<String>
    @State private var dragOffset: CGFloat?
    
    private let radius: CGFloat = 30
    private let marbleColor = Color(hue: 0.49, saturation: 0.56, brightness: 0.62).opacity(0.9)
    
    var body: some View {
        ZStack {
        Rectangle()
            .frame(height: 1, alignment: .center)
            .foregroundColor(.gray)
        GeometryReader(content: { geometry in
            ForEach(viewModel.events, id: \.id) { event in
                switch event.type {
                case .output(let value):
                    ZStack {
                        Circle()
                            .foregroundColor(marbleColor)
                            .frame(width: radius * 2, height: radius * 2)
                        Text(value).bold()
                    }
                    .offset(x: event.time * geometry.size.width - radius, y: 0)
                    .gesture(DragGesture()
                                .onChanged { value in
                                    let offset = dragOffset ?? (event.time * geometry.size.width) - value.startLocation.x
                                    dragOffset = offset
                                    let time = min(1, max(0, (offset + value.location.x) / geometry.size.width))
                                    viewModel.updateTime(time, on: event)
                                }
                                .onEnded { value in
                                    dragOffset = nil
                                }
                    ).id(event.id)
                case .finished:
                    ZStack {
                        Rectangle()
                            .frame(width: 3, height: radius * 2 + 10)
                    }
                    .frame(width: radius * 2, height: radius * 2)
                    .contentShape(Rectangle()) // expands touch area
                    .offset(x: event.time * geometry.size.width - radius, y: 0)
                    .gesture(DragGesture()
                                .onChanged { value in
                                    let offset = dragOffset ?? (event.time * geometry.size.width) - value.startLocation.x
                                    dragOffset = offset
                                    let time = min(1, max(0, (offset + value.location.x) / geometry.size.width))
                                    viewModel.updateTime(time, on: event)
                                }
                                .onEnded { value in
                                    dragOffset = nil
                                }
                    ).id(event.id)
                case .failure:
                    ZStack {
                        Rectangle()
                            .frame(width: 3, height: radius * 2 + 10)
                            .foregroundColor(.red)
                    }
                    .frame(width: radius * 2, height: radius * 2)
                    .contentShape(Rectangle()) // expands touch area
                    .offset(x: event.time * geometry.size.width - radius, y: 0)
                    .gesture(DragGesture()
                                .onChanged { value in
                                    let offset = dragOffset ?? (event.time * geometry.size.width) - value.startLocation.x
                                    dragOffset = offset
                                    let time = min(1, max(0, (offset + value.location.x) / geometry.size.width))
                                    viewModel.updateTime(time, on: event)
                                }
                                .onEnded { value in
                                    dragOffset = nil
                                }
                    ).id(event.id)
                }
            }
        }
        )
        .frame(minHeight: radius * 2, idealHeight: radius * 2)
        .disabled(!viewModel.allowInteraction)
        }
    }
}

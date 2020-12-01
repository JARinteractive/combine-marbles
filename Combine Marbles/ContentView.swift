import SwiftUI

struct ContentView: View {
    @State private var selected: Operator?

    var body: some View {
        NavigationView {
            OperatorListView(operators: [Operator.map, Operator.filter, Operator.removeDuplicates, Operator.prefix, Operator.merge, Operator.zipOperator, Operator.flatMap, Operator.switchToLatest, Operator.combineLatest, Operator.withLatestFrom], selected: $selected)
            
            selected.map {
                OperatorDetailView(combineOperator: $0)
            }
        }
        .frame(minWidth: 700, minHeight: 300)
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

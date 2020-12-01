import SwiftUI

struct OperatorListView: View {
    let operators: [Operator]
    @Binding var selected: Operator?

    var body: some View {
        List(selection: $selected) {
            ForEach(operators) { combineOperator in
                OperatorRow(combineOperator: combineOperator)
                    .tag(combineOperator)
                    .padding()
            }
        }
        .frame(minWidth: 225)
    }
}

struct OperatorRow: View {
        var combineOperator: Operator
        
        var body: some View {
            HStack(alignment: .center) {
                VStack(alignment: .leading) {
                    Text(combineOperator.name)
                        .fontWeight(.bold)
                        .truncationMode(.tail)
                        .frame(minWidth: 20)
                }
            }
            .padding(.vertical, 4)
        }
}

import SwiftUI

// MARK: - PIN Components

enum PINKey { case digit(Character), delete }

struct PINDotsView: View {
    let count: Int
    let filled: Int
    var body: some View {
        HStack(spacing: 18) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i < filled ? Color.white : Color.clear)
                    .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 2))
                    .frame(width: 16, height: 16)
                    .animation(.spring(response: 0.15), value: filled)
            }
        }
    }
}

struct PINPadView: View {
    let accentColor: Color
    let onKey: (PINKey) -> Void
    private let rows: [[String]] = [["1","2","3"],["4","5","6"],["7","8","9"],["","0","⌫"]]
    var body: some View {
        VStack(spacing: 14) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 20) {
                    ForEach(row, id: \.self) { label in
                        if label.isEmpty {
                            Color.clear.frame(width: 82, height: 82)
                        } else if label == "⌫" {
                            Button { onKey(.delete) } label: {
                                Image(systemName: "delete.backward")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .frame(width: 82, height: 82)
                            }
                        } else {
                            Button { onKey(.digit(label.first!)) } label: {
                                Text(label)
                                    .font(.system(size: 30, weight: .regular, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(width: 82, height: 82)
                                    .background(Circle().fill(.white.opacity(0.08)))
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ShakeEffect: ViewModifier {
    var trigger: Bool
    func body(content: Content) -> some View {
        content
            .offset(x: trigger ? -8 : 0)
            .animation(trigger
                ? .spring(response: 0.1, dampingFraction: 0.2).repeatCount(4, autoreverses: true)
                : .default, value: trigger)
    }
}

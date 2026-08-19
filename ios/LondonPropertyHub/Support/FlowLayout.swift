import SwiftUI

/// Lays chips and buttons out left to right, wrapping to a new line when the
/// row runs out of width. SwiftUI has no built-in wrapping stack, and an HStack
/// would either clip or squeeze the labels.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, in: width)

        let height = rows.reduce(into: CGFloat.zero) { total, row in
            total += row.height
        } + lineSpacing * CGFloat(max(0, rows.count - 1))

        let widest = rows.map(\.width).max() ?? 0

        return CGSize(
            width: proposal.width ?? widest,
            height: height
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = arrange(subviews: subviews, in: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX

            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)

                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )

                x += size.width + spacing
            }

            y += row.height + lineSpacing
        }
    }

    // MARK: - Row packing

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, in width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width

            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
                current.indices = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.indices.append(index)
                current.width = needed
                current.height = max(current.height, size.height)
            }
        }

        if !current.indices.isEmpty {
            rows.append(current)
        }

        return rows
    }
}

/// Pairs a record with its 1-based display position.
///
/// `Array(collection.enumerated())` looks like the obvious way to get an index
/// alongside each element, but its elements are tuples, and Swift key paths
/// cannot refer to tuple elements — so `ForEach(…, id: \.element.id)` does not
/// compile. This carries the same information in a type that has real
/// properties to point at.
struct Numbered<Value: Identifiable>: Identifiable {
    let number: Int
    let value: Value

    var id: Value.ID { value.id }
}

extension Collection where Element: Identifiable {
    /// Elements paired with their 1-based position, safe to use as `ForEach` data.
    func numbered() -> [Numbered<Element>] {
        enumerated().map { Numbered(number: $0.offset + 1, value: $0.element) }
    }
}

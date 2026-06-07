import Foundation

struct MarkdownViewportPlanner {
    func initialViewportSlice(
        from blocks: [MarkdownRenderBlock],
        viewportHeight: Double,
        overscanRatio: Double,
        minimumBlockCount: Int,
        maximumBlockCount: Int,
        maximumHeavyBlockCount: Int = 1
    ) -> [MarkdownRenderBlock] {
        guard !blocks.isEmpty else { return [] }

        let clampedMaximum = max(min(maximumBlockCount, blocks.count), 1)
        let clampedMinimum = min(max(minimumBlockCount, 1), clampedMaximum)
        let clampedHeavyMaximum = max(maximumHeavyBlockCount, 1)
        let targetHeight = max(viewportHeight * (1 + overscanRatio), viewportHeight)

        var result: [MarkdownRenderBlock] = []
        var accumulatedHeight: Double = 0
        var heavyBlockCount = 0

        for block in blocks.prefix(clampedMaximum) {
            let estimatedHeight = preferredHeight(for: block)
            let isHeavy = isHeavyBlock(block)
            let hasFilledViewport = accumulatedHeight >= viewportHeight

            if !result.isEmpty && hasFilledViewport && isHeavy && heavyBlockCount >= clampedHeavyMaximum {
                break
            }

            if !result.isEmpty && result.count >= clampedMinimum {
                if accumulatedHeight >= targetHeight {
                    break
                }
            }

            result.append(block)
            accumulatedHeight += estimatedHeight
            if isHeavy {
                heavyBlockCount += 1
            }
        }

        return result
    }

    private func preferredHeight(for block: MarkdownRenderBlock) -> Double {
        if let preferredHeight = block.preferredHeight {
            return max(preferredHeight, 28)
        }

        let lineCount = max(block.markdown.components(separatedBy: "\n").count, 1)

        switch block.kind {
        case .heading:
            return 56
        case .paragraph:
            return min(max(Double(lineCount) * 30, 42), 220)
        case .list:
            return min(max(Double(lineCount) * 28, 52), 240)
        case .quote:
            return min(max(Double(lineCount) * 28, 52), 240)
        case .code:
            return min(max(Double(lineCount) * 24 + 36, 120), 420)
        case .table:
            return min(max(Double(lineCount) * 30 + 32, 120), 360)
        case .html:
            return min(max(Double(lineCount) * 28, 48), 240)
        case .image:
            return 220
        case .thematicBreak:
            return 28
        }
    }

    private func isHeavyBlock(_ block: MarkdownRenderBlock) -> Bool {
        switch block.kind {
        case .code:
            let estimatedHeight = preferredHeight(for: block)
            let lineCount = max(block.markdown.components(separatedBy: "\n").count, 1)
            return estimatedHeight >= 160 || lineCount >= 7
        case .table:
            return preferredHeight(for: block) >= 160
        case .image:
            return true
        case .html:
            return preferredHeight(for: block) >= 180
        case .heading, .paragraph, .list, .quote, .thematicBreak:
            return false
        }
    }
}

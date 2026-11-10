extension Collection where Element: Equatable {
    public func firstIndex(of run: some Collection<Element>) -> Index? {
        guard !run.isEmpty else { return startIndex }
        var start = startIndex
        while start != endIndex {
            var here = start
            var wanted = run.startIndex
            while here != endIndex, wanted != run.endIndex, self[here] == run[wanted] {
                here = index(after: here)
                wanted = run.index(after: wanted)
            }
            if wanted == run.endIndex { return start }
            start = index(after: start)
        }
        return nil
    }

    public func contains(_ run: some Collection<Element>) -> Bool {
        firstIndex(of: run) != nil
    }
}

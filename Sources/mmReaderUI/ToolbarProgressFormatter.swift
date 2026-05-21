public enum ToolbarProgressFormatter {
    public static func format(page: Int, total: Int) -> String {
        guard total > 0 else {
            return "0/0 0%"
        }
        let percent = Int((Double(page) / Double(total)) * 100)
        return "\(page)/\(total) \(percent)%"
    }
}

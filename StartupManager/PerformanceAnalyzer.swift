import Foundation

struct PerformanceMetrics {
    let estimatedStartupTime: TimeInterval // seconds
    let memoryImpact: Int // MB
    let cpuImpact: String // Low, Medium, High
    let overallImpact: String // Low, Medium, High
}

class PerformanceAnalyzer {
    static let shared = PerformanceAnalyzer()

    func analyzeItem(_ item: any LaunchItem) -> PerformanceMetrics {
        var startupTime: TimeInterval = 0.0
        var memoryImpact = 0
        var cpuImpactScore = 0

        // Analyze based on item type
        if let agent = item as? LaunchAgent {
            startupTime += analyzeAgent(agent)
            cpuImpactScore += getAgentCPUImpact(agent)
            memoryImpact = estimateMemoryUsage(agent)
        } else if let daemon = item as? LaunchDaemon {
            startupTime += analyzeDaemon(daemon)
            cpuImpactScore += getDaemonCPUImpact(daemon)
            memoryImpact = estimateMemoryUsage(daemon)
        } else if item is LoginItem {
            startupTime += 0.2 // Login items typically add 200ms
            cpuImpactScore = 1
            memoryImpact = 50
        }

        // Determine CPU impact level
        let cpuImpact: String
        if cpuImpactScore >= 4 {
            cpuImpact = "High"
        } else if cpuImpactScore >= 2 {
            cpuImpact = "Medium"
        } else {
            cpuImpact = "Low"
        }

        // Calculate overall impact
        let overallImpact = calculateOverallImpact(
            startupTime: startupTime,
            cpuScore: cpuImpactScore,
            memory: memoryImpact
        )

        return PerformanceMetrics(
            estimatedStartupTime: startupTime,
            memoryImpact: memoryImpact,
            cpuImpact: cpuImpact,
            overallImpact: overallImpact
        )
    }

    private func analyzeAgent(_ agent: LaunchAgent) -> TimeInterval {
        var time: TimeInterval = 0.05 // Base time for launch agent (50ms)

        guard let plistContent = PlistParser.parsePlist(at: agent.path) else {
            return time
        }

        // Check RunAtLoad - if true, runs at startup
        if let runAtLoad = plistContent["RunAtLoad"] as? Bool, runAtLoad {
            time += 0.1 // 100ms
        }

        // Check KeepAlive - if true, continuously running
        if let keepAlive = plistContent["KeepAlive"] as? Bool, keepAlive {
            time += 0.15 // 150ms
        }

        // Check StartInterval - periodic tasks add overhead
        if plistContent["StartInterval"] != nil {
            time += 0.05 // 50ms
        }

        // Check WatchPaths - file monitoring adds overhead
        if let watchPaths = plistContent["WatchPaths"] as? [String], !watchPaths.isEmpty {
            time += 0.08 // 80ms
        }

        return time
    }

    private func analyzeDaemon(_ daemon: LaunchDaemon) -> TimeInterval {
        var time: TimeInterval = 0.1 // Daemons have higher base impact (100ms)

        guard let plistContent = PlistParser.parsePlist(at: daemon.path) else {
            return time
        }

        // Daemons typically have higher impact
        if let runAtLoad = plistContent["RunAtLoad"] as? Bool, runAtLoad {
            time += 0.15 // 150ms
        }

        if let keepAlive = plistContent["KeepAlive"] as? Bool, keepAlive {
            time += 0.2 // 200ms
        }

        // Network listeners add significant overhead
        if plistContent["Sockets"] != nil {
            time += 0.12 // 120ms
        }

        return time
    }

    private func getAgentCPUImpact(_ agent: LaunchAgent) -> Int {
        var score = 1

        guard let plistContent = PlistParser.parsePlist(at: agent.path) else {
            return score
        }

        if let keepAlive = plistContent["KeepAlive"] as? Bool, keepAlive {
            score += 2
        }

        if plistContent["StartInterval"] != nil {
            score += 1
        }

        if plistContent["WatchPaths"] != nil {
            score += 1
        }

        return score
    }

    private func getDaemonCPUImpact(_ daemon: LaunchDaemon) -> Int {
        var score = 2 // Daemons start with higher base

        guard let plistContent = PlistParser.parsePlist(at: daemon.path) else {
            return score
        }

        if let keepAlive = plistContent["KeepAlive"] as? Bool, keepAlive {
            score += 2
        }

        if plistContent["Sockets"] != nil {
            score += 1
        }

        return score
    }

    private func estimateMemoryUsage(_ item: any LaunchItem) -> Int {
        // Base memory estimate
        var memory = 30 // MB

        if let agent = item as? LaunchAgent {
            guard let plistContent = PlistParser.parsePlist(at: agent.path) else {
                return memory
            }
            if let keepAlive = plistContent["KeepAlive"] as? Bool, keepAlive {
                memory += 20
            }
        } else if let daemon = item as? LaunchDaemon {
            memory = 50 // Daemons use more memory
            guard let plistContent = PlistParser.parsePlist(at: daemon.path) else {
                return memory
            }
            if let keepAlive = plistContent["KeepAlive"] as? Bool, keepAlive {
                memory += 30
            }
        }

        return memory
    }

    private func calculateOverallImpact(startupTime: TimeInterval, cpuScore: Int, memory: Int) -> String {
        let score = (startupTime * 10) + Double(cpuScore) + (Double(memory) / 30)

        if score >= 15 {
            return "High"
        } else if score >= 8 {
            return "Medium"
        } else {
            return "Low"
        }
    }

    func calculateTotalStartupImpact(
        loginItems: [LoginItem],
        launchAgents: [LaunchAgent],
        launchDaemons: [LaunchDaemon]
    ) -> (totalTime: TimeInterval, enabledTime: TimeInterval, itemCount: Int) {
        // Most items start in parallel, so we calculate the "critical path"
        // We estimate ~30% overlap, so total = sum * 0.3 + max
        var allTimes: [TimeInterval] = []
        var enabledTimes: [TimeInterval] = []
        var enabledCount = 0

        for item in loginItems where item.isEnabled {
            let metrics = analyzeItem(item)
            allTimes.append(metrics.estimatedStartupTime)
            enabledTimes.append(metrics.estimatedStartupTime)
            enabledCount += 1
        }

        for item in launchAgents where item.isEnabled {
            let metrics = analyzeItem(item)
            allTimes.append(metrics.estimatedStartupTime)
            enabledTimes.append(metrics.estimatedStartupTime)
            enabledCount += 1
        }

        for item in launchDaemons where item.isEnabled {
            let metrics = analyzeItem(item)
            allTimes.append(metrics.estimatedStartupTime)
            enabledTimes.append(metrics.estimatedStartupTime)
            enabledCount += 1
        }

        // Calculate realistic impact: max time + 30% of sum (for serial portions)
        let maxTime = enabledTimes.max() ?? 0.0
        let sumTime = enabledTimes.reduce(0, +)
        let estimatedImpact = maxTime + (sumTime * 0.3)

        return (sumTime, estimatedImpact, enabledCount)
    }
}

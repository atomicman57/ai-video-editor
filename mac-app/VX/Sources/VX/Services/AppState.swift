import SwiftUI

enum Route: Hashable { case library, briefing, editor, settings }

/// Central observable store. Owns navigation, the loaded project + storyboard,
/// live cost, and the currently running job.
@MainActor
final class AppState: ObservableObject {
    @Published var route: Route = .library
    @Published var projects: [ProjectSummary] = []
    @Published var activeProject: ProjectSummary?
    @Published var detail: ProjectDetail?
    @Published var storyboard: Storyboard?
    @Published var cost: CostSummary = .zero
    @Published var selectedSegment: Int?
    @Published var editMode: String = "story"   // "story" | "timeline"

    @Published var connected = false
    @Published var loadError: String?
    @Published var currentJob: JobInfo?

    private let api = APIClient.shared
    private let importService: any ProjectImportService

    init(importService: any ProjectImportService = APIClient.shared) {
        self.importService = importService
    }

    // -- Lifecycle -----------------------------------------------------------
    func bootstrap() async {
        await waitForSidecar()
        await reloadProjects()
    }

    func waitForSidecar() async {
        for _ in 0..<40 {
            if (try? await api.health()) != nil { connected = true; return }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        connected = false
        loadError = "Could not reach the VX sidecar on \(SidecarConfiguration.baseURL().absoluteString). Run `vx serve` (or `python -m ai_video_editor.server`)."
    }

    func reloadProjects() async {
        do { projects = try await api.projects(); loadError = nil }
        catch { loadError = "\(error.localizedDescription)" }
    }

    // -- Navigation ----------------------------------------------------------
    func open(_ p: ProjectSummary) {
        activeProject = p
        editMode = p.mode
        route = .editor
        Task { await loadProject(p.id) }
    }

    func beginBriefing() {
        activeProject = nil
        detail = nil
        storyboard = nil
        selectedSegment = nil
        currentJob = nil
        loadError = nil
        route = .briefing
    }

    func loadProject(_ id: String) async {
        async let d = try? await api.project(id)
        async let sb = try? await api.storyboard(id)
        async let c = try? await api.cost(id)
        detail = await d
        storyboard = await sb
        cost = await c ?? .zero
        selectedSegment = storyboard?.segments.first?.index
    }

    func refreshCost() async {
        guard let id = activeProject?.id else { return }
        if let c = try? await api.cost(id) { cost = c }
    }

    // -- Jobs ----------------------------------------------------------------
    func runAnalyze(timeline: Bool, visual: Bool) {
        guard let id = activeProject?.id else { return }
        Task { await track(try await api.analyze(id, AnalyzeRequest(visual: visual, timeline: timeline))) }
    }

    func runCut(proxyMode: Bool) {
        guard let id = activeProject?.id else { return }
        Task { await track(try await api.cut(id, CutRequest(proxyMode: proxyMode))) }
    }

    func importProject(_ request: CreateProjectRequest) async {
        activeProject = nil
        detail = nil
        storyboard = nil
        selectedSegment = nil
        currentJob = nil
        loadError = nil

        do {
            let submitted = try await importService.createProject(request)
            currentJob = submitted
            var latest = submitted

            if !submitted.isTerminal {
                let updates = await importService.jobUpdates(for: submitted.id)
                for await update in updates {
                    latest = update
                    currentJob = update
                    if let c = update.cost { cost = c }
                    if update.isTerminal { break }
                }
            }

            guard latest.status == "completed" else {
                loadError = latest.error ?? "Import ended before preprocessing completed."
                return
            }

            projects = try await importService.projects()
            guard let imported = projects.first(where: { $0.id == request.name }) else {
                loadError = "Imported project '\(request.name)' was not returned by the sidecar."
                return
            }
            activeProject = imported
            editMode = imported.mode
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func track(_ job: JobInfo) async {
        currentJob = job
        let stream = await JobStream(jobID: job.id)
        for await update in stream.updates() {
            currentJob = update
            if let c = update.cost { cost = c }
            if update.isTerminal {
                if let id = activeProject?.id { await loadProject(id) }
                await reloadProjects()
            }
        }
    }
}

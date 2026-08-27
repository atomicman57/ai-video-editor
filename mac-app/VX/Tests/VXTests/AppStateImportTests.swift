import XCTest
@testable import VX

@MainActor
final class AppStateImportTests: XCTestCase {
    func testBeginBriefingClearsPreviouslyOpenProject() {
        let service = ImportServiceStub(project: project(id: "unused"))
        let state = AppState(importService: service)
        state.activeProject = project(id: "old-project")
        state.storyboard = Storyboard(
            title: "Old storyboard",
            editorialReasoning: "",
            estimatedDurationSec: 1,
            style: "vlog",
            storyConcept: "",
            cast: [],
            storyArc: [],
            segments: [],
            discarded: [],
            musicPlan: [],
            technicalNotes: [],
            pacingNotes: []
        )

        state.beginBriefing()

        XCTAssertEqual(state.route, .briefing)
        XCTAssertNil(state.activeProject)
        XCTAssertNil(state.storyboard)
    }

    func testImportTracksCompletionAndSelectsCreatedProject() async {
        let imported = project(id: "new-trip")
        let service = ImportServiceStub(project: imported)
        let state = AppState(importService: service)
        let request = CreateProjectRequest(name: imported.id, sourceDir: "/tmp/vacation")

        await state.importProject(request)

        XCTAssertEqual(state.currentJob?.status, "completed")
        XCTAssertEqual(state.projects, [imported])
        XCTAssertEqual(state.activeProject, imported)
        XCTAssertTrue(service.deliveredTerminalUpdate)
    }

    func testFailedJobExposesItsProviderError() {
        let failed = JobInfo(
            id: "job-failed",
            kind: "analyze",
            project: "new-trip",
            status: "failed",
            stage: "Phase 1",
            progress: 0.75,
            error: "GEMINI_API_KEY is not set",
            result: nil,
            cost: nil,
            logTail: nil,
            durationSec: 0.5
        )

        XCTAssertEqual(failed.failureMessage, "GEMINI_API_KEY is not set")
    }

    private func project(id: String) -> ProjectSummary {
        ProjectSummary(
            id: id,
            name: id,
            type: "editorial",
            provider: "gemini",
            style: "vlog",
            mode: "story",
            clipCount: 3,
            createdAt: nil,
            stylePreset: nil,
            hasStoryboard: false,
            hasRoughCut: false,
            latestVersion: nil
        )
    }
}

private final class ImportServiceStub: ProjectImportService, @unchecked Sendable {
    let project: ProjectSummary
    var deliveredTerminalUpdate = false

    init(project: ProjectSummary) {
        self.project = project
    }

    func createProject(_ request: CreateProjectRequest) async throws -> JobInfo {
        job(status: "queued", progress: 0)
    }

    func projects() async throws -> [ProjectSummary] {
        [project]
    }

    func jobUpdates(for jobID: String) async -> AsyncStream<JobInfo> {
        AsyncStream { continuation in
            continuation.yield(job(status: "running", progress: 0.5))
            deliveredTerminalUpdate = true
            continuation.yield(job(status: "completed", progress: 1))
            continuation.finish()
        }
    }

    private func job(status: String, progress: Double) -> JobInfo {
        JobInfo(
            id: "job-1",
            kind: "create",
            project: project.id,
            status: status,
            stage: "Preprocessing",
            progress: progress,
            error: nil,
            result: nil,
            cost: nil,
            logTail: nil,
            durationSec: status == "completed" ? 1 : nil
        )
    }
}

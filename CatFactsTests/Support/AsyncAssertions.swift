import XCTest

func assertThrowsError<T>(
    _ message: String = "Expected an error",
    file: StaticString = #filePath,
    line: UInt = #line,
    operation: () async throws -> T,
    verify: (Error) -> Void
) async {
    do {
        _ = try await operation()
        XCTFail(message, file: file, line: line)
    } catch {
        verify(error)
    }
}

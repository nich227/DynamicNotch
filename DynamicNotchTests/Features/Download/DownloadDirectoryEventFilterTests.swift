import CoreServices
import XCTest
@testable import DynamicNotch

final class DownloadDirectoryEventFilterTests: XCTestCase {
    private let roots = ["/Users/test/Downloads", "/Users/test/Pictures"]
    private let noFlags = FSEventStreamEventFlags(kFSEventStreamEventFlagNone)

    func testDirectChildAndRootEventsAreRelevant() {
        XCTAssertTrue(DownloadDirectoryEventFilter.isRelevant(path: "/Users/test/Downloads/file.zip", flags: noFlags, rootPaths: roots))
        XCTAssertTrue(DownloadDirectoryEventFilter.isRelevant(path: "/Users/test/Downloads", flags: noFlags, rootPaths: roots))
        XCTAssertTrue(DownloadDirectoryEventFilter.isRelevant(path: "/Users/test/Downloads/", flags: noFlags, rootPaths: roots))
    }

    func testDeepWritesOutsideTemporaryBundlesAreIgnored() {
        XCTAssertFalse(DownloadDirectoryEventFilter.isRelevant(
            path: "/Users/test/Pictures/Photos Library.photoslibrary/database/Photos.sqlite",
            flags: noFlags,
            rootPaths: roots
        ))
        XCTAssertFalse(DownloadDirectoryEventFilter.isRelevant(path: "/Users/test/Downloads/repo/src/main.swift", flags: noFlags, rootPaths: roots))
    }

    func testWritesInsideTemporaryDownloadBundlesAreRelevant() {
        XCTAssertTrue(DownloadDirectoryEventFilter.isRelevant(path: "/Users/test/Downloads/archive.zip.download/archive.zip", flags: noFlags, rootPaths: roots))
        XCTAssertTrue(DownloadDirectoryEventFilter.isRelevant(path: "/Users/test/Downloads/Video.PART/chunk/0", flags: noFlags, rootPaths: roots))
    }

    func testUnrecognizedPathsAndRescanFlagsFallBackToScan() {
        XCTAssertTrue(DownloadDirectoryEventFilter.isRelevant(path: "/Volumes/Other/deep/file", flags: noFlags, rootPaths: roots))
        XCTAssertTrue(DownloadDirectoryEventFilter.isRelevant(
            path: "/Users/test/Pictures/Photos Library.photoslibrary/database/Photos.sqlite",
            flags: FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs),
            rootPaths: roots
        ))
    }

    func testSiblingWithSharedPrefixIsNotTreatedAsChild() {
        XCTAssertTrue(DownloadDirectoryEventFilter.isRelevant(path: "/Users/test/DownloadsOld/a/b", flags: noFlags, rootPaths: roots))
    }

    func testRootPathsIncludeResolvedSymlinkForm() {
        let url = URL(fileURLWithPath: "/var/folders")
        let paths = DownloadDirectoryEventFilter.rootPaths(for: [url, url])
        XCTAssertTrue(paths.contains("/private/var/folders"))
        XCTAssertEqual(paths.count, Set(paths).count)
    }
}

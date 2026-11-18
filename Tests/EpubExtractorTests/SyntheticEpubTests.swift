import Foundation
import Testing
@testable import EpubExtractor

/// Builds tiny unzipped EPUB folders on disk so parser behavior can be tested without fixtures.
private func makeEpub(
    opf: String,
    files: [String: String],
    containerPath: String = "OEBPS/content.opf"
) throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    var all = files
    all["META-INF/container.xml"] = """
    <?xml version="1.0"?>
    <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
      <rootfiles><rootfile full-path="\(containerPath)" media-type="application/oebps-package+xml"/></rootfiles>
    </container>
    """
    all["OEBPS/content.opf"] = opf
    for (path, content) in all {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    return root
}

private let epub2OPF = """
<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Test Book</dc:title>
    <dc:creator>Ann Author</dc:creator>
    <dc:creator>Bob Author</dc:creator>
    <dc:publisher>Pub Co</dc:publisher>
    <dc:identifier id="id">urn:uuid:1234</dc:identifier>
    <meta name="cover" content="cover-img"/>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="ch1" href="chapter%201.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="chapter2.xhtml" media-type="application/xhtml+xml"/>
    <item id="cover-img" href="cover.jpg" media-type="image/jpeg"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="ch1"/>
    <itemref idref="ch2" linear="no"/>
  </spine>
</package>
"""

private let epub2Files: [String: String] = [
    "OEBPS/toc.ncx": """
    <?xml version="1.0"?>
    <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
      <navMap>
        <navPoint id="n1" playOrder="1">
          <navLabel><text>Chapter One</text></navLabel>
          <content src="chapter%201.xhtml#sec"/>
        </navPoint>
      </navMap>
    </ncx>
    """,
    "OEBPS/chapter 1.xhtml": """
    <html><head><title>ignored</title><style>p { color: red }</style></head>
    <body><h1>One</h1><p>Hello &amp; welcome&nbsp;friend&#33;</p><script>var x = 1;</script></body></html>
    """,
    "OEBPS/chapter2.xhtml": "<html><body><p>Second</p></body></html>"
]

@Suite struct SyntheticEpubTests {
    @Test func parsesEpub2MetadataSpineAndChapters() throws {
        let root = try makeEpub(opf: epub2OPF, files: epub2Files)
        defer { try? FileManager.default.removeItem(at: root) }

        let epub = try EpubParser().parseEpub(epubDirectoryURL: root)

        #expect(epub.type == .epub2)
        #expect(epub.title == "Test Book")
        #expect(epub.authors == ["Ann Author", "Bob Author"])
        #expect(epub.identifier == "urn:uuid:1234")
        #expect(epub.publisher == "Pub Co")
        #expect(epub.coverURL?.lastPathComponent == "cover.jpg")

        #expect(epub.spines.count == 2)
        #expect(epub.spines[0].linear == true)   // attribute absent defaults to yes
        #expect(epub.spines[1].linear == false)

        #expect(epub.chapters.count == 1)
        #expect(epub.chapters[0].label == "Chapter One")
        #expect(epub.chapters[0].src.lastPathComponent == "chapter 1.xhtml")
        #expect(epub.chapters[0].src.fragment == "sec")
    }

    @Test func extractsPlainTextAndSeparatesChapters() throws {
        let root = try makeEpub(opf: epub2OPF, files: epub2Files)
        defer { try? FileManager.default.removeItem(at: root) }
        let epub = try EpubParser().parseEpub(epubDirectoryURL: root)

        let first = try epub.content(forSpine: epub.spines[0])
        #expect(first.contains("Hello & welcome friend!"))
        #expect(!first.contains("color"))
        #expect(!first.contains("var x"))
        #expect(!first.contains("ignored"))

        let all = try epub.allContent()
        #expect(all.contains("friend!\n\nSecond"))
    }

    @Test func parsesEpub3NavAndCoverProperty() throws {
        let opf = """
        <?xml version="1.0"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>Three</dc:title>
            <dc:identifier id="id">isbn:9</dc:identifier>
          </metadata>
          <manifest>
            <item id="navdoc" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
            <item id="c1" href="text/c1.xhtml" media-type="application/xhtml+xml"/>
            <item id="img" href="cover.png" media-type="image/png" properties="cover-image"/>
          </manifest>
          <spine><itemref idref="c1"/></spine>
        </package>
        """
        let files = [
            "OEBPS/nav.xhtml": """
            <html xmlns:epub="http://www.idpf.org/2007/ops"><body>
              <nav epub:type="toc"><ol>
                <li><a href="text/c1.xhtml">First</a></li>
              </ol></nav>
            </body></html>
            """,
            "OEBPS/text/c1.xhtml": "<html><body><p>Body</p></body></html>"
        ]
        let root = try makeEpub(opf: opf, files: files)
        defer { try? FileManager.default.removeItem(at: root) }

        let epub = try EpubParser().parseEpub(epubDirectoryURL: root)

        #expect(epub.type == .epub3)
        #expect(epub.identifier == "isbn:9")
        #expect(epub.coverURL?.lastPathComponent == "cover.png")
        #expect(epub.chapters.count == 1)
        #expect(epub.chapters[0].label == "First")
        #expect(epub.spineIndex(for: epub.chapters[0]) == 0)
        #expect(try epub.content(forSpine: epub.spines[0]) == "Body")
    }

    @Test func rejectsRootFileOutsideEpubFolder() throws {
        let root = try makeEpub(opf: epub2OPF, files: epub2Files, containerPath: "../escape.opf")
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(throws: EpubParseError.rootFileNotFound) {
            try EpubParser().parseEpub(epubDirectoryURL: root)
        }
    }

    @Test func rejectsSpineHrefEscapingEpubFolder() throws {
        let opf = epub2OPF.replacingOccurrences(of: "chapter2.xhtml", with: "../../../etc/passwd")
        let root = try makeEpub(opf: opf, files: epub2Files)
        defer { try? FileManager.default.removeItem(at: root) }
        let epub = try EpubParser().parseEpub(epubDirectoryURL: root)

        #expect(throws: EpubContentError.self) {
            try epub.content(forSpine: epub.spines[1])
        }
    }
}

@Suite struct PlainTextExtractorTests {
    @Test func decodesEntitiesAndBreaksBlocks() {
        let text = PlainTextExtractor.text(fromHTML: "<p>A&mdash;B</p><p>&#x41;&#66; &unknown; end</p><!-- note --><br/>tail")
        #expect(text == "A—B\nAB &unknown; end\ntail")
    }
}

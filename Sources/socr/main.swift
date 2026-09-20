// socr — capture a screen region, OCR it with Apple Vision, print text to stdout.
import Foundation
import Vision

let version = "0.1.0"

let usage = """
Usage: socr [options]

Capture a screen region, OCR it with Apple Vision, and print the recognized
text to stdout. Press Escape to cancel the capture.

Options:
  -l, --lang <langs>   Recognition language(s), joined with '+' (default: en-US)
  -x, --silent         Do not play the screenshot sound
  -v, --version        Print version and exit
  -h, --help           Print this help and exit
"""

struct Options {
    var languages = ["en-US"]
    var silent = false
}

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data("socr: \(message)\n".utf8))
    exit(code)
}

func parse(_ argv: [String]) -> Options {
    var o = Options()
    var i = 0
    while i < argv.count {
        let a = argv[i]
        i += 1
        switch a {
        case "-h", "--help": print(usage); exit(0)
        case "-v", "--version": print(version); exit(0)
        case "-x", "--silent": o.silent = true
        case "-l", "--lang":
            guard i < argv.count else { fail("\(a) requires a value") }
            o.languages = argv[i].split(separator: "+").map(String.init)
            i += 1
        default:
            if a.hasPrefix("--lang=") {
                o.languages = a.dropFirst(7).split(separator: "+").map(String.init)
            } else {
                fail("unknown option \(a)\n\(usage)")
            }
        }
    }
    if o.languages.isEmpty { fail("no language given") }
    return o
}

/// Runs the interactive screencapture UI. Returns the PNG path, or nil if cancelled.
func capture(silent: Bool) -> String? {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("socr-\(ProcessInfo.processInfo.processIdentifier).png").path
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    p.arguments = [silent ? "-ix" : "-i", path]
    do { try p.run() } catch { fail("screencapture failed: \(error.localizedDescription)") }
    p.waitUntilExit()
    // screencapture exits 1 when the user presses Escape.
    if p.terminationStatus == 1 { return nil }
    if p.terminationStatus != 0 { fail("screencapture exited with status \(p.terminationStatus)") }
    let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
    return size > 0 ? path : nil
}

func loadImage(_ path: String) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

func recognize(_ image: CGImage, languages: [String]) throws -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = languages
    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    return (request.results ?? [])
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: "\n")
}

func run() -> Int32 {
    let opts = parse(Array(CommandLine.arguments.dropFirst()))

    guard let path = capture(silent: opts.silent) else { return 0 }
    defer { try? FileManager.default.removeItem(atPath: path) }

    guard let image = loadImage(path) else { fail("could not read image at \(path)") }
    let text: String
    do { text = try recognize(image, languages: opts.languages) }
    catch { fail("recognition failed: \(error.localizedDescription)") }

    if text.isEmpty { return 0 }
    print(text)
    return 0
}

exit(run())

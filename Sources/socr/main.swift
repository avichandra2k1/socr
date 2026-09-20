// socr — capture a screen region, OCR it with Apple Vision, print text to stdout.
import AppKit
import Foundation
import Vision

let version = "0.1.0"

let usage = """
Usage: socr [options] [image]
       socr languages

Capture a screen region (or read an image file), OCR it with Apple Vision,
and print the recognized text to stdout. Press Escape to cancel the capture.

Commands:
  languages            List the language codes Vision supports

Options:
  -l, --lang <langs>   Recognition language(s), joined with '+' (default: en-US)
                       Vision does not auto-detect. See: socr languages
  -x, --silent         Do not play the screenshot sound
  -c, --clipboard      Also copy the recognized text to the clipboard
      --fast           Use the fast recognition level (less accurate)
  -v, --version        Print version and exit
  -h, --help           Print this help and exit
"""

struct Options {
    var languages = ["en-US"]
    var silent = false
    var clipboard = false
    var fast = false
    var image: String?
    var listLanguages = false
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
        case "-c", "--clipboard": o.clipboard = true
        case "--fast": o.fast = true
        case "-l", "--lang":
            guard i < argv.count else { fail("\(a) requires a value") }
            o.languages = argv[i].split(separator: "+").map(String.init)
            i += 1
        case "languages": o.listLanguages = true
        default:
            if a.hasPrefix("--lang=") {
                o.languages = a.dropFirst(7).split(separator: "+").map(String.init)
            } else if a.hasPrefix("-"), a.count > 1 {
                fail("unknown option \(a)\n\(usage)")
            } else if o.image == nil {
                o.image = a
            } else {
                fail("unexpected argument \(a)")
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

func recognize(_ image: CGImage, languages: [String], fast: Bool) throws -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = fast ? .fast : .accurate
    request.usesLanguageCorrection = true
    let supported = try request.supportedRecognitionLanguages()
    if let bad = languages.first(where: { !supported.contains($0) }) {
        fail("unsupported language \(bad) (see: socr languages)")
    }
    request.recognitionLanguages = languages
    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    return (request.results ?? [])
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: "\n")
}

func run() -> Int32 {
    let opts = parse(Array(CommandLine.arguments.dropFirst()))

    if opts.listLanguages {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = opts.fast ? .fast : .accurate
        guard let langs = try? request.supportedRecognitionLanguages() else { fail("failed to query supported languages") }
        print(langs.joined(separator: "\n"))
        return 0
    }

    let path: String
    var isTemp = false
    if let image = opts.image {
        path = image
    } else {
        guard let captured = capture(silent: opts.silent) else { return 0 }
        path = captured
        isTemp = true
    }
    defer { if isTemp { try? FileManager.default.removeItem(atPath: path) } }

    guard let image = loadImage(path) else { fail("could not read image at \(path)") }
    let text: String
    do { text = try recognize(image, languages: opts.languages, fast: opts.fast) }
    catch { fail("recognition failed: \(error.localizedDescription)") }

    if text.isEmpty { return 0 }
    if opts.clipboard {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
    print(text)
    return 0
}

exit(run())

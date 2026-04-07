import Cocoa
import CoreGraphics

// List all displays
let maxDisplays: UInt32 = 10
var displays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
var displayCount: UInt32 = 0
CGGetActiveDisplayList(maxDisplays, &displays, &displayCount)

// Parse argument
let args = CommandLine.arguments
if args.count < 2 {
    print("用法: screenshot <display_number> [output_path]")
    print("")
    print("可用的 display:")
    for i in 0..<Int(displayCount) {
        let id = displays[i]
        let w = CGDisplayPixelsWide(id)
        let h = CGDisplayPixelsHigh(id)
        let isMain = CGDisplayIsMain(id) != 0 ? " (Main)" : ""
        print("  \(i + 1): \(w)x\(h)\(isMain) [ID: \(id)]")
    }
    exit(0)
}

guard let displayNum = Int(args[1]), displayNum >= 1, displayNum <= Int(displayCount) else {
    print("錯誤: display 編號必須在 1~\(displayCount) 之間")
    exit(1)
}

let targetDisplay = displays[displayNum - 1]
let outputPath = args.count >= 3 ? args[2] : "screenshot.png"

// Take screenshot
guard let image = CGDisplayCreateImage(targetDisplay) else {
    print("錯誤: 無法截圖")
    exit(1)
}

let url = URL(fileURLWithPath: outputPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
    print("錯誤: 無法建立檔案")
    exit(1)
}
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)

print("截圖已儲存: \(outputPath) (\(image.width)x\(image.height))")

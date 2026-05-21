import AppKit
import Testing
@testable import mmReaderUI

@MainActor
@Test func readerViewAppliesHexTextColor() {
    let view = ReaderView(frame: .init(x: 0, y: 0, width: 400, height: 300))
    view.applyTextColorHex("#33AAFF")

    #expect(view.debugTextColorHexForTesting == "#33AAFF")
}

@MainActor
@Test func readerViewAppliesVisibleTextOnTransparentBackground() {
    let view = ReaderView(frame: .init(x: 0, y: 0, width: 400, height: 300))

    view.setText("hello world")

    #expect(view.debugTextValueForTesting == "hello world")
    #expect(view.debugDrawsBackgroundForTesting == false)
}

@MainActor
@Test func readerViewUsesTextViewForLongFormReading() {
    let view = ReaderView(frame: .init(x: 0, y: 0, width: 400, height: 300))

    #expect(view.subviews.first is NSTextView)
}

@MainActor
@Test func readerTextViewAllowsWindowBackgroundDragging() {
    let view = ReaderView(frame: .init(x: 0, y: 0, width: 400, height: 300))
    guard let textView = view.subviews.first as? NSTextView else {
        Issue.record("ReaderView should install NSTextView as its first subview")
        return
    }

    #expect(textView.mouseDownCanMoveWindow == true)
}

@MainActor
@Test func readerViewUsesRegularSystemFontWithoutShadow() {
    let view = ReaderView(frame: .init(x: 0, y: 0, width: 400, height: 300))
    view.setText("hello")

    guard let textView = view.subviews.first as? NSTextView else {
        Issue.record("ReaderView should install NSTextView as its first subview")
        return
    }

    let font = textView.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
    let shadow = textView.textStorage?.attribute(.shadow, at: 0, effectiveRange: nil) as? NSShadow

    #expect(font != nil)
    #expect(font?.fontDescriptor.symbolicTraits.contains(.bold) == false)
    #expect(shadow == nil)
}

@MainActor
@Test func readerViewAppliesFontAndTextAlpha() {
    let view = ReaderView(frame: .init(x: 0, y: 0, width: 400, height: 300))

    view.applyFontSize(26)
    view.applyTextAlpha(0.7)

    #expect(view.debugFontSizeForTesting == 26)
    #expect(view.debugTextAlphaForTesting == 0.7)
}

import SwiftUI
import AppKit

struct TwoFactorView: View {
    @State private var code: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedField: Int?
    let onComplete: (String) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            headerView
            codeInputView
        }
        .padding(24)
        .onAppear {
            focusedField = 0
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 4) {
            Text("Two-Factor Authentication")
                .font(.headline)
            Text("Enter the verification code")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var codeInputView: some View {
        HStack(spacing: 8) {
            ForEach(0..<6) { index in
                codeField(index: index)
            }
        }
    }
    
    private func codeField(index: Int) -> some View {
        TextField("", text: $code[index])
            .font(.system(size: 24, weight: .medium))
            .frame(width: 45, height: 55)
            .textFieldStyle(PlainTextFieldStyle())
            .multilineTextAlignment(.center)
            .background(codeFieldBackground)
            .focused($focusedField, equals: index)
            .onChange(of: code[index]) { newValue in
                handleInput(newValue, at: index)
            }
            .onAppear {
                setupPasteMonitor()
            }
    }
    
    private func setupPasteMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.characters?.lowercased() == "v" {
                handlePaste()
                return nil
            }
            return event
        }
    }
    
    private var codeFieldBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray, lineWidth: 1)
            )
    }
    
    private func handleInput(_ newValue: String, at index: Int) {
        if newValue.count >= 1 {
            code[index] = String(newValue.prefix(1))
            if index < 5 {
                focusedField = index + 1
            } else {
                focusedField = nil
                onComplete(code.joined())
            }
        }
    }
    
    private func handlePaste() {
        guard let pasteboardString = NSPasteboard.general.string(forType: .string) else { return }
        let numbers = pasteboardString.filter { $0.isNumber }
        let codeArray = Array(numbers.prefix(6))
        
        for (index, char) in codeArray.enumerated() {
            code[index] = String(char)
        }
        
        if codeArray.count == 6 {
            focusedField = nil
            onComplete(code.joined())
        } else {
            focusedField = min(codeArray.count, 5)
        }
    }
}

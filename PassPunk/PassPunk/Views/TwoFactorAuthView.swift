import SwiftUI

struct TwoFactorAuthView: View {
    @Binding var code: String
    @Binding var isPresented: Bool
    var onSubmit: (String) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enter 2FA Code")
                .font(.headline)
            
            TextField("Code", text: $code)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 200)
            
            Button("Submit") {
                onSubmit(code)
            }
        }
        .padding()
    }
} 
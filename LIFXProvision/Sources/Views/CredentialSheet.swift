/// Sheet for entering target WiFi credentials before provisioning a bulb.

import SwiftUI

struct CredentialSheet: View {
    let bulbSSID: String
    @Binding var targetSSID: String
    @Binding var targetPassword: String
    @Binding var savedTargetSSID: String
    let onProvision: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Bulb") {
                    Label(bulbSSID, systemImage: "lightbulb.fill")
                }

                Section("Target Network") {
                    TextField("Network name", text: $targetSSID)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if !savedTargetSSID.isEmpty && targetSSID != savedTargetSSID {
                        Button {
                            targetSSID = savedTargetSSID
                        } label: {
                            Label(savedTargetSSID, systemImage: "clock.arrow.circlepath")
                        }
                    }
                }

                Section("Password") {
                    SecureField("Password", text: $targetPassword)
                        .textContentType(.password)
                }

                Section {
                    Button(action: onProvision) {
                        HStack {
                            Spacer()
                            Text("Provision")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(targetSSID.isEmpty || targetPassword.isEmpty)
                }
            }
            .navigationTitle("Set WiFi Credentials")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

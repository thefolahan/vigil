import SwiftUI
import VigilKit

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var confirmRemove = false

    var body: some View {
        Form {
            Section("Agents") {
                Toggle("Keep the Mac awake while agents work", isOn: $model.watchAgents)
                Picker("Wait before sleeping", selection: $model.graceMinutes) {
                    Text("1 minute").tag(1)
                    Text("3 minutes").tag(3)
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("20 minutes").tag(20)
                }
                Text("An agent that goes quiet keeps the Mac awake this long, so a slow reply or a pause between steps does not end the session.")
                    .font(.caption).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recognised")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .leading), count: 3),
                              alignment: .leading, spacing: 10) {
                        ForEach(AgentCatalog.builtIn, id: \.id) { kind in
                            HStack(spacing: 8) {
                                AgentBadge(kind: kind, size: 22)
                                Text(kind.name)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            Section("Lid closed") {
                if model.lidModeInstalled {
                    Toggle("Keep running with the lid closed", isOn: $model.lidMode)
                    Picker("Stop below this charge on battery", selection: $model.batteryFloor) {
                        ForEach([10, 15, 20, 25, 30, 40, 50], id: \.self) { Text("\($0)%").tag($0) }
                    }
                    Button("Remove lid mode permission", role: .destructive) { confirmRemove = true }
                } else {
                    LabeledContent("Not set up") {
                        Button(model.settingUp ? "Setting up" : "Set up") { model.setUpLidMode() }
                            .disabled(model.settingUp)
                    }
                }
                Text("Lid mode adds one rule to /etc/sudoers.d/vigil that lets your account run exactly two commands without a password: pmset -a disablesleep 1 and pmset -a disablesleep 0. A guard agent turns sleep back on within about half a minute if Vigil quits unexpectedly. Lid mode also stops when the Mac runs hot or the battery drops below the limit. Keep the Mac on a hard surface with air around it, never in a bag.")
                    .font(.caption).foregroundStyle(.secondary)
                if let error = model.setupError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            Section("Alerts") {
                Toggle("Notify me when an agent stops after working", isOn: $model.notifyWhenDone)
                TextField("ntfy topic", text: $model.phoneTopic, prompt: Text("e.g. vigil-7f3k29qx"))
                HStack {
                    Text("Install the free ntfy app on your phone and subscribe to the same topic. Alerts are sent there only while you are away from the Mac. Anyone who knows the topic can read them, so make it long and random.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Send test") { model.sendTestAlert() }
                        .disabled(model.phoneTopic.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("General") {
                Toggle("Open at login", isOn: $model.launchAtLogin)
                LabeledContent("History") {
                    Button("Clear \(Format.count(model.sessions.count, "session"))") { model.clearHistory() }
                        .disabled(model.sessions.isEmpty)
                }
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")
            }
        }
        .formStyle(.grouped)
        .tint(.flame)
        .frame(width: 520)
        .frame(minHeight: 560)
        .confirmationDialog("Remove lid mode?", isPresented: $confirmRemove) {
            Button("Remove", role: .destructive) { model.removeLidMode() }
        } message: {
            Text("Vigil asks for your password to delete the sudoers rule and turns sleep back on.")
        }
    }
}

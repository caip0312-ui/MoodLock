import SwiftUI

struct SettingsView: View {
    @AppStorage("voiceRecordingEnabled") private var voiceRecordingEnabled = false

    var body: some View {
        List {
            Section {
                Toggle("语音录音", isOn: $voiceRecordingEnabled)
            } footer: {
                Text("开启后，记录心情时可以立即补充一段语音。仅在 App 内可用，锁屏和桌面小组件不支持录音。")
            }
        }
        .navigationTitle("设置")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}

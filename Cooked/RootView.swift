import SwiftUI

struct RootView: View {
    @Environment(TimerViewModel.self) private var viewModel

    var body: some View {
        ZStack {
            MainPageView()

            if viewModel.isAlarmActive {
                AlarmOverlay()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}
struct AlarmOverlay: View {
    @Environment(TimerViewModel.self) private var viewModel

    var body: some View {
        VStack {
            HStack(spacing: 12) {

                Image(systemName: "alarm.fill")
                    .foregroundStyle(.white)

                Text("Alarm is ringing")
                    .foregroundStyle(.white)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    viewModel.stopAlarm()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.red.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()
        }
    }
}


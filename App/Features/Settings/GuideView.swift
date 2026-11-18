import SwiftUI

/// User Guide explaining the analog film workflow and core features.
struct GuideView: View {
    @Environment(\.dismiss) private var dismiss

    struct GuideStep: Identifiable {
        let id: Int
        let number: String
        let title: String
        let englishTitle: String
        let icon: String
        let description: String
        let tip: String
    }

    private let steps: [GuideStep] = [
        GuideStep(
            id: 1,
            number: "01",
            title: "Khung ngắm & Bấm máy",
            englishTitle: "Viewfinder & Shutter",
            icon: "camera.viewfinder",
            description: "Chụp hết 36 kiểu hoặc bấm Kết thúc sớm bất cứ lúc nào khi muốn cuộn phim dừng lại. Kính ngắm cơ học mô phỏng trọn vẹn cảm giác chụp máy film analog cổ điển, không xem lại ảnh ngay lập tức.",
            tip: "Tip: Bạn có thể bật lưới bố cục 3x3 và phản hồi rung khi bấm máy trong cài đặt."
        ),
        GuideStep(
            id: 2,
            number: "02",
            title: "Phòng tối & Tráng phim",
            englishTitle: "Darkroom & Developing",
            icon: "timer",
            description: "Chờ 60 phút theo thời gian thực để tráng ảnh, không thể tua nhanh hay bỏ qua. Quá trình mô phỏng buồng tối hóa học thực tế, giữ trọn cảm giác hồi hộp chờ đợi từng cuộn phim ra lò.",
            tip: "Tip: Thiết bị sẽ gửi thông báo cho bạn ngay khi cuộn phim đã tráng xong."
        ),
        GuideStep(
            id: 3,
            number: "03",
            title: "Mở cuộn & Xuất ảnh",
            englishTitle: "Contact Sheet & Export",
            icon: "photo.stack",
            description: "Xem toàn bộ Contact Sheet 36 tấm ảnh âm bản và dương bản. Phóng to chi tiết từng khung hình với hiệu ứng hạt phim (grain), quang sai viền (halation), lưu về Photos hoặc chia sẻ với bạn bè.",
            tip: "Tip: Chạm vào bất kỳ khung hình nào để xem chi tiết ở độ phân giải cao nhất."
        ),
        GuideStep(
            id: 4,
            number: "04",
            title: "Phòng thí nghiệm",
            englishTitle: "Darkroom Import",
            icon: "flask",
            description: "Áp 14 bộ màu film analog huyền thoại (Kodak Portra, Tri-X, CineStill...) lên ảnh có sẵn từ máy của bạn. Giữ nguyên độ chi tiết và tái hiện chất màu film chân thực.",
            tip: "Tip: Nhấn giữ vào ảnh xem trước để so sánh ảnh gốc và ảnh đã tráng film."
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingL) {
                    header
                    ForEach(steps) { step in
                        stepCard(step)
                    }
                    footer
                }
                .padding(Theme.spacingM)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Done")
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.amber)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Rectangle().fill(Theme.amber).frame(width: 6, height: 6)
                Text("ROLL 36 // USER MANUAL")
                    .monoLabel(size: 11, color: Theme.amber)
            }
            Text("Quy trình Analog")
                .monoDisplay(size: 26, color: Theme.text)
            Text("Trải nghiệm nhiếp ảnh phim chân thực: Bấm máy, Kiên nhẫn chờ tráng và Khám phá ảnh.")
                .bodyText(color: Theme.muted)
                .font(.subheadline)
        }
        .padding(.bottom, Theme.spacingS)
    }

    private func stepCard(_ step: GuideStep) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingM) {
            HStack(alignment: .center, spacing: Theme.spacingM) {
                Text(step.number)
                    .monoDisplay(size: 22, color: Theme.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .monoLabel(size: 13, color: Theme.text)
                    Text(step.englishTitle)
                        .monoLabel(size: 10, color: Theme.muted)
                }
                Spacer()
                Image(systemName: step.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.amber)
                    .frame(width: 36, height: 36)
                    .monoBox(fill: Theme.surface, radius: Theme.boxRadius)
            }

            Rectangle()
                .fill(Theme.line)
                .frame(height: Theme.lineWidth)

            Text(step.description)
                .bodyText(color: Theme.text)
                .font(.footnote)
                .lineSpacing(3)

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.amber)
                    .padding(.top, 2)
                Text(step.tip)
                    .monoLabel(size: 10, color: Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .monoBox(fill: Theme.surface, radius: Theme.boxRadius)
        }
        .padding(Theme.spacingM)
        .monoBox(fill: Theme.card, radius: Theme.cardRadius)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: Theme.spacingM) {
            PrimaryButton(title: "Done", action: { dismiss() })
                .accessibilityLabel("Done")
        }
        .padding(.top, Theme.spacingS)
    }
}

#Preview {
    GuideView()
}

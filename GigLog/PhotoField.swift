import ImageIO
import SwiftUI
import UIKit

/// A thumbnail that takes a photo with the camera (or picks one from the library on devices
/// without a camera), and shows it full screen when tapped.
struct PhotoField: View {
    let title: String
    @Binding var data: Data?

    @State private var showingCamera = false
    @State private var showingFull = false
    /// A small decoded copy for the row; decoding the full photo on every redraw would use
    /// several MB of memory per photo.
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            if data != nil, let thumbnail {
                Button { showingFull = true } label: {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View \(title)")
            }
            Text(title)
            Spacer()
            Menu {
                Button(data == nil ? "Take photo" : "Retake photo", systemImage: "camera") { showingCamera = true }
                if data != nil {
                    Button("Remove photo", systemImage: "trash", role: .destructive) { data = nil }
                }
            } label: {
                Image(systemName: data == nil ? "camera" : "ellipsis.circle")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(data == nil ? "Take \(title)" : "\(title) options")
        }
        .task(id: data) {
            thumbnail = data.flatMap { UIImage.thumbnail(from: $0, maxPixelSize: 192) }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in data = image.compressedJPEG() }
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showingFull) {
            if let data, let image = UIImage(data: data) {
                NavigationStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .navigationTitle(title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { Button("Done") { showingFull = false } }
                }
            }
        }
    }
}

/// Wraps UIImagePickerController for taking a photo.
struct CameraPicker: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onPick(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

extension UIImage {
    /// Decodes a downsized copy straight from the JPEG data, without decoding the full image first.
    static func thumbnail(from data: Data, maxPixelSize: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    /// Shrinks to at most 1600 px on the long side and JPEG-compresses (~200–300 KB).
    func compressedJPEG(maxDimension: CGFloat = 1600) -> Data? {
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.6)
    }
}

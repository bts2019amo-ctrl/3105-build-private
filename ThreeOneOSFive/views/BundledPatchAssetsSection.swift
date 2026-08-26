import SwiftUI

import UIKit



struct BundledPatchAssetsSection: View {
  
    @State private var assets: [URL] = []
  

  
    var body: some View {
      
        Section {
          
            if assets.isEmpty {
              
                Text("No imported resources")
              
                    .foregroundStyle(.secondary)
              
            } else {
              
                ForEach(assets, id: \.path) { asset in
                                             
                    HStack(spacing: 12) {
                      
                        thumbnail(for: asset)
                      
                        VStack(alignment: .leading, spacing: 3) {
                          
                            Text(asset.deletingPathExtension().lastPathComponent)
                          
                                .font(.body.weight(.semibold))
                          
                                .lineLimit(2)
                          
                            Text("Imported resource • visual catalog only")
                          
                                .font(.caption)
                          
                                .foregroundStyle(.secondary)
                          
                        }
                      
                        Spacer()
                      
                        Image(systemName: "doc.fill")
                      
                            .foregroundStyle(.secondary)
                      
                    }
                                             
                    .padding(.vertical, 4)
                                             
                    .accessibilityElement(children: .combine)
                                             
                                            }
              
            }
          
        } header: {
          
            Label("Imported patches", systemImage: "shippingbox")
          
        } footer: {
          
            Text("These files are displayed only and are not executed or applied by the app.")
          
        }
      
        .onAppear(perform: loadAssets)
      
    }
  

  
    private func loadAssets() {
      
        assets = (Bundle.main.urls(forResourcesWithExtension: nil, subdirectory: "patch_assets") ?? [])
      
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
      
    }
  

  
    @ViewBuilder
  
    private func thumbnail(for url: URL) -> some View {
      
        if ["png", "jpg", "jpeg"].contains(url.pathExtension.lowercased()),
      
           let image = UIImage(contentsOfFile: url.path) {
             
            Image(uiImage: image)
             
                .resizable()
             
                .scaledToFill()
             
                .frame(width: 44, height: 44)
             
                .clipShape(RoundedRectangle(cornerRadius: 8))
             
           } else {
             
            Image(systemName: "doc.text.fill")
             
                .font(.system(size: 24))
             
                .foregroundStyle(.orange)
             
                .frame(width: 44, height: 44)
             
           }
      
    }
  
}



























































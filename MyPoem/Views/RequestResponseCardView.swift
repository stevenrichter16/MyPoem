import SwiftUI
import _SwiftData_SwiftUI

struct RequestResponseCardView: View {
    let request: Request
    // no longer need requestStore here

    @StateObject private var vm: RequestResponseCardViewModel
    @Query(sort: \Response.dateCreated, order: .forward) private var responses: [Response]


    init(request: Request, requestStore: RequestStoring, responseStore: ResponseStoring) {
      self.request = request
      _vm = StateObject(
        wrappedValue: RequestResponseCardViewModel(
          request: request,
          requestStore: requestStore,
          responseStore: responseStore
        )
      )
    }

  // One static formatter for “6:12pm”
  private static let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "h:mma"
    f.amSymbol = "am"; f.pmSymbol = "pm"
    return f
  }()

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // — Request line
        Text(request.poemType.name)
            .font(.caption2)
            .foregroundColor(.secondary)

      Text(request.userInput)
        .font(.headline)
        .foregroundColor(.primary)

      // — Response area
      ZStack(alignment: .topLeading) {
          if vm.isLoading {
          // placeholder with fixed height
          HStack(spacing: 6) {
            ProgressView()
              .scaleEffect(0.7)
            Text("Thinking…")
              .font(.caption)
              .foregroundColor(.gray)
          }
          .frame(height: 24)               // just a bit taller than one line
        } else {
          VStack(alignment: .leading, spacing: 4) {
              Text(vm.displayedText)
              .font(.body)
              .foregroundColor(.secondary)

            Text(Self.timeFormatter
                  .string(from: Date()))
              .font(.caption2)
              .foregroundColor(.gray)
              .frame(maxWidth: .infinity,
                     alignment: .trailing)
          }
          .fixedSize(horizontal: false,
                     vertical: true)
          .transition(.opacity)            // fade in smoothly
        }
      }
    }
    .padding()
    .background(Color(.secondarySystemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05),
            radius: 5, x: 0, y: 3)
    .padding(.horizontal)
    .onChange(of: responses) { response in
        guard let resp = response.last else { return }
        if (resp.requestId == request.id) {
            vm.triggerAnimation(response: resp)
        }
    }
//    .onAppear(perform: loadAndAnimate)
//    .animation(.easeInOut(duration: 0.3),
//               value: vm.displayedText)     // smooth updates
  }

//  private func loadAndAnimate() {
//    guard isLoading else { return }
//
//    DispatchQueue.global(qos: .userInitiated).async {
//      // replace with your async fetch/API call
//        let resp = (try? vm.requestStore
//          .fetchResponse(requestId: request.id)?
//          .content)
//        ?? "Error generating response."
//
//      DispatchQueue.main.async {
//        fullResponse = resp
//        isLoading = false
//        typeOutByWords(resp)
//      }
//    }
//  }
//
//  private func typeOutByWords(_ text: String) {
//    displayedText = ""
//    let words = text.split(separator: " ").map(String.init)
//    var delay: Double = 0
//
//    for word in words {
//      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
//        // append with a leading space if needed
//        displayedText += (displayedText.isEmpty ? "" : " ") + word
//      }
//      delay += 0.05   // adjust speed here
//    }
//  }
}

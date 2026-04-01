import Foundation

struct ErrorPresenter {
    func userPresentableError(for error: Error) -> UserPresentableError {
        if let presentable = error as? UserPresentableError {
            return presentable
        }
        return UserPresentableError(
            title: "Something Went Wrong",
            message: error.localizedDescription
        )
    }
}

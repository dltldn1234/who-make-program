import Foundation
import JarvisCore

@main
struct JarvisCLI {
    static func main() async {
        let engine = JarvisEngine(executor: MacActionExecutor())

        print("JARVIS Core 0.1")
        print("명령을 입력하세요. 종료하려면 '종료'를 입력하세요.")

        while true {
            print("\n사용자 > ", terminator: "")
            guard let input = readLine() else { break }
            if ["종료", "exit", "quit"].contains(input.lowercased()) { break }

            let prepared = await engine.prepare(input)
            var approved = true

            if case let .userConfirmation(reason) = prepared.approval {
                print("자비스 > \(reason) 승인할까요? (y/N): ", terminator: "")
                approved = readLine()?.lowercased() == "y"
            }

            let response = await engine.execute(prepared, approved: approved)
            print("자비스 > \(response.message)")
        }

        print("자비스를 종료합니다.")
    }
}

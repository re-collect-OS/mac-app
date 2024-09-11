import Amplify
import AWSCognitoAuthPlugin
import AWSAPIPlugin
import Sentry

struct AmplifyConfiguration {
    static func configure() {
        Amplify.Logging.logLevel = .verbose
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.add(plugin: AWSAPIPlugin())
            try Amplify.configure()
            print("Amplify configured with auth and API plugins")
        } catch {
            print("Failed to initialize Amplify: \(error)")
            SentrySDK.capture(error: error)
        }
    }
}

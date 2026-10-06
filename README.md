# Centillion iOS example app

A SwiftUI chat app using the [Centillion iOS SDK](https://github.com/Centillion-Labs/centillion-ios-sdk). It demonstrates streaming replies, conversation history, pagination, retry, and native tool execution.

## Run

Requires Xcode 16+ with Swift 6 and an iOS 17+ simulator or device.

```sh
git clone https://github.com/Centillion-Labs/ios-sdk-example-app.git
cd ios-sdk-example-app
open CentillionSample.xcodeproj
```

Xcode resolves the public SDK through Swift Package Manager, starting at version `0.1.0`. Select the `CentillionSample` scheme, choose an iPhone simulator, and run. For a physical device, choose your development team under Signing & Capabilities.

In Centillion, open your agent's Channels → iOS SDK → Overview, enable Visibility, and save. Copy the agent ID from Setup and enter it in the app. The SDK base URL defaults to `https://app.cntillion.com/api/sdk`. Change it if you use a different Centillion host. No API key is needed. Keep identity signing secrets on your backend.

The app registers `get_app_version`. To try it, create a Client action with that exact name, select Wait for response, and enable the action for iOS SDK. Ask the agent to check the app version.

## Verify

```sh
xcodebuild -project CentillionSample.xcodeproj -scheme CentillionSample \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

The SDK repository contains the library's unit tests. Run `swift test` there.

For local development, use `http://localhost:3000/api/sdk` in the simulator. Local HTTP is allowed only in Debug. Use HTTPS on physical devices and in production.

For a live smoke run, add these launch arguments in Xcode's Run scheme:

```text
-agentId YOUR_AGENT_ID -baseURL http://localhost:3000/api/sdk -smoke YES
```

Enable the `get_app_version` action first. The run checks a reply, message pagination, retry, and native tools, then writes `Documents/sdk-smoke.txt` in the app container. Use a dedicated test agent because this creates conversations and consumes reply credits.

## Source

`CentillionSample.swift` contains the setup form, chat view, history view, and smoke flow. The SDK handles transport, identity, and conversation state. Read its [API guide](https://github.com/Centillion-Labs/centillion-ios-sdk#client-and-streaming) for signed user identity and custom interfaces.

## License

MIT. See [LICENSE](LICENSE).

# mac-app


Clone the repo in Xcode
Build and Run
Safari Sync will ask for Disk Access



### Major Components

1. **Authentication Management**
    - `AuthenticationManager`: Manages all authentication-related activities, including user sign-ins and secure data requests.
2. **UI Components**
    - `ContentView`: Serves as the entry point of the user interface, providing login capabilities and leading to the main functionalities of the app.
    - `SettingsView`: Allows users to adjust application settings, manage account details, and handle integration with various system services.
    - `SearchView`: Facilitates the core functionality of searching, displaying results in various forms such as cards, and managing search states and parameters.
    - `NotesView`, `SafariView`: Dedicated views for managing integration with macOS Notes and Safari, providing specific functionalities like syncing and managing data.
3. **Utility Views**
    - `PeeledRecallCardView`: Displays detailed information about a selected item, with options to interact further such as opening links or expanding content.
    - `AbstractCardView`: Used for displaying synthesized information from multiple sources in a concise format.
    - `VisualEffectView`: Provides aesthetic enhancements to the UI elements based on the system appearance settings.
4. **State Management**
    - `SharedStateManager`, `AppStateManager`: Manage the state across the application, ensuring recall components are updated in response to data changes or user interactions.
    - `SyncStateManager`: Tracks the status of data synchronization processes, particularly for browser history from Safari.
5. **Notifications and Settings**
    - `MyNotificationsView`, `MyAccountView`: Provide interfaces for managing notifications and account settings, respectively.
6. **Error Handling and Logging**
    - Integration with `Sentry` for real-time error tracking and logging, enhancing the maintainability and reliability of the application.

### Functionality and Interactions

- **Authentication Flow**: Users can log in through the `ContentView`, with credentials managed by `AuthenticationManager`.
- **Search and Retrieval**: The main recall flow is handled via `SearchView`, with recalled cards displayed in various formats depending on the kind of recall result. The search process involves fetching data from our backend, filtering results based on user-defined parameters (filters), and displaying them in `SearchView`.
- **Document Interaction**: The application allows for interaction with documents through draggable cards (`DraggableCardView`), where users can view, peel off for more details, or interact with documents. They’re all NSPanel classes.
- **Settings and Preferences**: Users can configure application settings and preferences via `SettingsView`, managing integrations and account settings.
- **Integration with macOS Services**: The application integrates with macOS Notes and Safari, enabling data synchronization and retrieval directly from these services. Notes integration leverages NSAppleScript and Safari integration uses SQLLite database decryption.
- **Update Management**: Utilizes `Sparkle` for managing application updates, ensuring the application remains up-to-date with the latest features and security updates.

### Advanced Features

- **Dynamic UI and State Management**: The application employs advanced state management techniques to handle UI updates dynamically based on user interactions and data changes.
- **Custom Views and Controls**: Implements custom views and controls, such as `SegmentedPicker` and `FilterButton.`
- **Graphical and Visual Effects**: Makes use of `VisualEffectView` to apply native visual effects, enhancing the visual appeal and user experience.

### Security and Performance

- **Error Tracking**: Integrates with Sentry for real-time error tracking and logging, which helps in quickly identifying and resolving issues.

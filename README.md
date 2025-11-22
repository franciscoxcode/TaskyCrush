# 🍬 Tasky Crush

![Status](https://badgen.net/badge/status/in%20progress/yellow)
![Built in](https://badgen.net/badge/Built%20with/XCode/blue)
![Coded with](https://badgen.net/badge/Written%20with/Swift/green)
![Styling](https://badgen.net/badge/Styling/SwiftUI/purple)

Tasky Crush is a **SwiftUI** productivity companion that organizes your to-dos into project “stories” and day filters while handing out shiny coin points whenever you clear a task. Capture tasks with tags, due dates, reminders, and repeating rules, spin up emoji-colored projects on the fly, and jump into markdown notes or your completed history without leaving the home screen.

---
## 👋 Hello World

Hello, world!

---
## 📷 Screenshot

![Your paragraph text](https://github.com/user-attachments/assets/a5d4f5d3-457d-4c86-adf0-4e1f1ff0bc02)



---

## 🔧 Features 

- Organize tasks into emoji-colored “stories” with custom tags, color accents, and a drag-to-reorder manager so your projects stay in the order that makes sense to you.
- Capture rich task details like due dates, recurrence rules, reminders, and markdown notes, so every to-do has the context it needs.
- Filter your day by inbox or project and zero in on today, tomorrow, the weekend, or any custom date while overdue tasks automatically roll forward and recurring items schedule their next appearance.
- Stay motivated with a live coin badge, instant point rewards on completion, and a full completed-history sheet that lets you reschedule, edit, and note-take without leaving the flow.
- Work quickly through inline sheets for adding tasks, managing projects, picking emojis, and opening the markdown note editor right from the main screen.
- Mirror the same “story” style on macOS with a companion target that now reads/writes the exact same SwiftData store, so projects and tasks move seamlessly between iPhone, iPad, and Mac.
- Keep every device in sync with a SwiftData model container backed by the CloudKit container `iCloud.com.franciscocasillas.TaskyCrush`, while still working offline thanks to an automatic local-store fallback.

### Recent UI updates (macOS)
- Simplified the companion header by removing the Tasky Crush title banner and sync disclaimer for a cleaner first impression.
- Hid the "Tus proyectos" heading so the horizontal story list is the focal element.
- Renamed the task section to `Tasks` and removed duplicate emoji badges from the trailing edge of rows.
- Each row now shows the project emoji next to the project name label, keeping context without extra chrome.
- Added calendar-driven shortcuts (Today, Tomorrow, Weekend, Pick Date) so the macOS list can filter tasks by date and only show the picker when needed.
- Added a split task/note layout with a responsive header so the selected note’s metadata aligns with the task column title, and the close button anchors to the right edge of the metadata row.
- Rebuilt the note sidebar card: the placeholder now matches the typing inset, autosave strings are in English, and the status indicator reports the last update time directly in the note footer.
---

## Stack Used

- **SwiftUI** app entry point hosting the main content scene, backed by the HomeViewModel state container.
- Combine-powered observable model that publishes task/project changes and persists them automatically.
- A custom UIKit-backed markdown editor wrapped for SwiftUI to handle rich note-taking features.
- Local notification tooling wired up at launch to request permission, schedule reminders, and surface alerts in the foreground.
- SwiftData model container configured for CloudKit sync, with automatic fallback to a local SQLite store and a one-time JSON migration path for legacy installs.

---

## 🧪 Highlighted Technical Detail

When you finish a repeating task, Tasky Crush doesn’t just clone it, it pipes the completed item through a custom recurrence engine that respects weekday/weekend scopes, month-length clamping, and even minute-level intervals, then aligns the next reminder time before broadcasting the freshly generated occurrence back to the UI via Combine so you can accept or tweak it immediately.

## 📁 Project Structure

```bash
/Assets.xcassets                 # App icon and accent color asset catalog for the UI chrome
/CodexTestingAppApp.swift        # SwiftUI app entry that wires the notification manager and launches the main scene
/Shared/Models/TaskItem.swift           # Codable task DTO covering status, recurrence, reminders, and markdown notes
/Shared/Models/ProjectItem.swift        # Project “story” DTO with emoji, accent color, ordering, and tag catalog metadata
/Shared/Models/SwiftDataModels.swift    # @Model-backed TaskRecord/ProjectRecord definitions for SwiftData + CloudKit
/Shared/Models/DataController.swift     # Singleton that builds the SwiftData container with CloudKit + local fallbacks
/Shared/Models/TaskDataStore.swift      # Persistence facade that fetches/saves models through SwiftData and handles migration
/Utils/RecurrenceEngine.swift    # Date engine that advances repeating tasks with weekday/weekend scope rules
/Utils/NotificationManager.swift # Singleton for requesting permission and scheduling or cancelling local reminders
/ViewModels/HomeViewModel.swift  # Observable store loading/persisting data, rolling overdue tasks, and managing points/tags
/Views/ContentView.swift         # Main dashboard orchestrating filters, task lists, rewards, and all management sheets
/Views/AddTaskView.swift         # Sheet form to capture task details, choose projects/tags, reminders, and recurrence
```

---

## 🚧 Roadmap

- [x] Create tasks  
- [x] Create projects  
- [x] Add due dates to tasks  
- [x] Segment tasks by project with Inbox and All  
- [x] Edit projects  
- [x] Show history of completed tasks  
- [x] Delete projects and tasks  
- [x] Swipe right to change task due date
- [x] Add tags for better filtering  
- [x] Award points for completed tasks  
- [x] Add reminders to tasks  
- [x] Rebuild the reminder editor to support up to three mixed relative/absolute reminders with inline controls  
- [x] Add repeat options for recurring tasks  
- [x] Support full markdown notes per task  
- [x] Improve notes performance  
- [x] Move the manage-project button next to the Tasky Crush title for a cleaner header  
- [x] Replace the top-right add control with a floating action button  
- [x] Hide the Unassigned filter unless there are active unassigned tasks  
- [x] Keep project emojis visible for completed tasks even after a project is deleted  
- [x] Autofocus the add-task title field when opening the floating button sheet  
- [ ] Rearrange tasks via long press  
- [ ] Add due time to tasks
- [x] Implement SwiftData + CloudKit database and sync fallback
- [ ] Create widget to create and check tasks on the go
- [ ] Add quick actions with Siri Shortcuts
- [x] Kick off macOS companion target with the story HStack + add-project sheet

---

## 🚀 Getting Started

To run this app locally:

### Requirements
- Xcode 15 or newer
- macOS Ventura or later
- iOS Simulator or real device (iOS 16+)

### Steps

1. Clone this repository:
```bash
git clone https://github.com/franciscoxcode/TaskyCrush.git
```

2. Open the project in Xcode:
  ```bash
  open TaskyCrush/TaskyCrush.xcodeproj
  ```

3. In the **Signing & Capabilities** tab, select your team, enable the `iCloud` capability, and make sure the container `iCloud.com.franciscocasillas.TaskyCrush` is checked.

4. Build and run the app on a simulator or real device (sign in to the same iCloud account on each device to test sync).

### macOS Target

- Select the `TaskyCrushMac` scheme to launch the macOS companion window.
- You’ll see the horizontal project stories row with the shared visual styling and the `＋` button to create new projects from the same SwiftData store.
- Projects and tasks are shared 1:1 with iOS/iPadOS via the CloudKit container, so any edits you make on Mac instantly reflect on your phone when both devices use the same Apple ID.

---

## 🤝 Contact

Feel free to connect or reach out:

- [GitHub](https://github.com/franciscoxcode)
- [LinkedIn](https://www.linkedin.com/in/franciscoxcode/)
- [Email](mailto:fxcasillas.dev@gmail.com)

---

## 📄 License
Copyright (c) 2025 Francisco Javier Casillas Pérez. All rights reserved.

This project and its source code are proprietary and confidential. No part of this project may be copied, modified, distributed, or used without explicit written permission from the author.  
Unauthorized use, reproduction, or distribution of this software, in whole or in part, is strictly prohibited.

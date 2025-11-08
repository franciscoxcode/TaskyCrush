# 🍬 Tasky Crush

![Status](https://badgen.net/badge/status/in%20progress/yellow)
![Built in](https://badgen.net/badge/Built%20with/XCode/blue)
![Coded with](https://badgen.net/badge/Written%20with/Swift/green)
![Styling](https://badgen.net/badge/Styling/SwiftUI/purple)

Tasky Crush is a **SwiftUI** productivity companion that organizes your to-dos into project “stories” and day filters while handing out shiny coin points whenever you clear a task. Capture tasks with tags, due dates, reminders, and repeating rules, spin up emoji-colored projects on the fly, and jump into markdown notes or your completed history without leaving the home screen.

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
---

## Stack Used

- **SwiftUI** app entry point hosting the main content scene, backed by the HomeViewModel state container.
- Combine-powered observable model that publishes task/project changes and persists them automatically.
- A custom UIKit-backed markdown editor wrapped for SwiftUI to handle rich note-taking features.
- Local notification tooling wired up at launch to request permission, schedule reminders, and surface alerts in the foreground.
- File-based JSON persistence for tasks and projects plus UserDefaults tracking for the user’s point total, keeping progress intact between launches.

---

## 🧪 Highlighted Technical Detail

When you finish a repeating task, Tasky Crush doesn’t just clone it, it pipes the completed item through a custom recurrence engine that respects weekday/weekend scopes, month-length clamping, and even minute-level intervals, then aligns the next reminder time before broadcasting the freshly generated occurrence back to the UI via Combine so you can accept or tweak it immediately.

## 📁 Project Structure

```bash
/Assets.xcassets                 # App icon and accent color asset catalog for the UI chrome
/CodexTestingAppApp.swift        # SwiftUI app entry that wires the notification manager and launches the main scene
/Models/TaskItem.swift           # Codable task model covering status, recurrence, reminders, and markdown notes
/Models/ProjectItem.swift        # Project “story” data with emoji, accent color, ordering, and tag catalog metadata
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
- [ ] Implement CloudKit for database and sync
- [ ] Create widget to create and check tasks on the go
- [ ] Add quick actions with Siri Shortcuts
- [ ] Create MacOS companion app

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
git clone https://github.com/your-username/FavoriteCharacters.git
```

2. Open the project in Xcode:
  ```bash
  open FavoriteCharacters.xcodeproj
  ```

3. Build and run the app on a simulator or real device.

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

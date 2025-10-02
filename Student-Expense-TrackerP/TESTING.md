# Testing Guide

## Running Tests Locally

1. Open `StudentExpenseTracker.xcodeproj` in Xcode.
2. Select the `StudentExpenseTracker` scheme.
3. Press `Command-U` to run all tests.

## Viewing Code Coverage

1. In Xcode, go to the menu: Product > Scheme > Edit Scheme...
2. Select the 'Test' action on the left.
3. Check the box 'Gather coverage for StudentExpenseTracker'.
4. Run tests (Command-U).
5. Open the Report Navigator (Command-9) and select the latest Test report.
6. Click the 'Coverage' tab to view coverage details for each file.

## Linting

- Run `swiftlint` in the project root to check code style. 

---

## 1. **Show QA Testing Results**

### a. **Test Reports from Xcode**
- Run your tests in Xcode (`Command-U`).
- Open the **Report Navigator** (`Command-9`).
- Select the latest test run to view results, including passed/failed tests and code coverage.
- **Export Results:**  
  - Click the “Export” button in the Report Navigator to save the test results as a `.xcresult` bundle or as a text file.
  - You can take screenshots of the results or attach the exported file to your documentation.

### b. **Update Documentation**
- Summarize your test results in your `BUG_REPORTS.md`, `COMPATIBILITY_TESTING.md`, and `BETA_FEEDBACK.md` files.
- Optionally, create a new file like `QA_RESULTS.md` with:
  - Number of tests run, passed, failed
  - Code coverage percentage
  - Screenshots of test results
  - Any known issues

### c. **CI Results (if using GitHub Actions)**
- If you have CI set up, you can show the status badges and logs from your GitHub Actions runs.
- Add a badge to your `README.md`:
  ```markdown
  ![iOS CI](https://github.com/<your-username>/<your-repo>/actions/workflows/ios-ci.yml/badge.svg)
  ```

---

## 2. **Show a Demo of the App**

### a. **Screen Recording**
- Use the built-in macOS **QuickTime Player**:
  1. Open QuickTime Player.
  2. File > New Screen Recording.
  3. Select your iOS Simulator window.
  4. Record yourself using the app, showing key features and test results.
  5. Save and share the video.

### b. **Screenshots**
- Take screenshots of the app running in the simulator (or on a device).
- Show important screens, test results, and any QA-related dialogs.

### c. **Live Demo**
- If presenting live (e.g., via Zoom or in person), share your screen and walk through the app in the simulator.
- Show the test results in Xcode, and demonstrate the app’s features.

### d. **Demo Script**
- Prepare a short script or checklist to ensure you cover all key features and QA highlights during your demo.

---

## 3. **Share Results with Others**

- **Attach exported test results, screenshots, or videos** to your project repository, or upload them to a shared drive.
- **Update your documentation** to reference these artifacts.
- **Send links or files** to your team, instructor, or stakeholders.

---

## Example: QA_RESULTS.md

```markdown
# QA Testing Results

## Automated Tests
- Total tests: 25
- Passed: 25
- Failed: 0
- Code Coverage: 87%

## Manual/Beta Testing
- Devices tested: iPhone 16 Simulator, iPad Air (M3)
- iOS versions: 18.4, 18.5
- No critical bugs found. Minor UI issue on iPad fixed.

## Screenshots
![Test Results](screenshots/test-results.png)
![App Demo](screenshots/app-demo.png)

## Demo Video
[Download Demo Video](demo/demo-video.mov)
```

---

### Would you like help:
- Exporting test results from Xcode?
- Creating a `QA_RESULTS.md` template?
- Recording a demo video or taking screenshots?
- Adding a CI badge to your README?

Let me know which step you want to do next! 

---

## 1. **Export Test Results and Code Coverage from Xcode**

### a. **Export Test Results**
1. Run your tests in Xcode (`Command-U`).
2. Open the **Report Navigator** (`Command-9`).
3. Select the latest test run.
4. Click the “Export” button (top right) to save the results as a `.xcresult` bundle or as a text file.
5. Place the exported file or a screenshot in the `screenshots/` folder (e.g., `screenshots/test-results.png`).

### b. **Export Code Coverage**
1. In Xcode, go to Product > Scheme > Edit Scheme… > Test.
2. Check “Gather coverage for StudentExpenseTracker.”
3. Run tests again.
4. In the Report Navigator, select the test run and click the “Coverage” tab.
5. Take a screenshot of the coverage report and save it as `screenshots/code-coverage.png`.

---

## 2. **Record a Demo Video**

### a. **Using QuickTime Player**
1. Open QuickTime Player.
2. File > New Screen Recording.
3. Select your iOS Simulator window.
4. Record yourself using the app, showing key features and test results.
5. Save the video as `demo-video.mov` and place it in the `demo/` folder.

---

## 3. **Take Screenshots**

- While running your app in the simulator, use `Command + S` or the screenshot tool to capture important screens.
- Save them in the `screenshots/` folder (e.g., `app-demo.png`, `test-results.png`).

---

## 4. **Update Documentation**

- Make sure your `QA_RESULTS.md` references the actual files you’ve added.
- Update the CI badge in `README.md` with your real GitHub username and repo name.

---

## 5. **Push Your Changes**

After adding your screenshots and demo video, run:

```sh
<code_block_to_apply_changes_from>
```

---

### Would you like:
- Step-by-step screenshots for any of these actions?
- A sample script for your demo video?
- Help updating the CI badge with your actual repo info?

Let me know if you want to proceed with any specific part, or if you want a sample script/checklist for your demo! 

---

Absolutely! Here’s a comprehensive guide for all your requests:

---

## 1. **Step-by-Step: Export Test Results and Code Coverage from Xcode**

### a. Export Test Results
1. **Run Tests:**  
   Open your project in Xcode. Press `Command-U` to run all tests.
2. **Open Report Navigator:**  
   Press `Command-9` or click the Report Navigator icon (looks like a speech bubble with a checkmark).
3. **Select Test Run:**  
   Click the most recent test run in the list.
4. **Export Results:**  
   In the top right, click the “Export” button (box with an arrow).  
   - Choose `.xcresult` for full results, or export as text for a summary.
5. **Save Screenshot:**  
   With the test results visible, press `Shift-Command-4` and select the area to capture a screenshot.  
   - Save as `screenshots/test-results.png`.

### b. Export Code Coverage
1. **Enable Coverage:**  
   In Xcode, go to `Product > Scheme > Edit Scheme… > Test`.  
   Check “Gather coverage for StudentExpenseTracker.”
2. **Run Tests Again:**  
   Press `Command-U`.
3. **View Coverage:**  
   In the Report Navigator, select the test run, then click the “Coverage” tab.
4. **Screenshot Coverage:**  
   Press `Shift-Command-4` to capture the coverage view.  
   - Save as `screenshots/code-coverage.png`.

---

## 2. **Step-by-Step: Record a Demo Video**

1. **Open QuickTime Player.**
2. **File > New Screen Recording.**
3. **Select the iOS Simulator window** (click the dropdown next to the record button to choose the window).
4. **Click Record.**
5. **Demo your app:**  
   - Show login, dashboard, adding/editing expenses, and any QA/test result screens.
6. **Stop Recording** (click the stop button in the menu bar).
7. **Save as `demo/demo-video.mov`.**

---

## 3. **Step-by-Step: Take Screenshots**

- While using the simulator, press `Command-S` or use `Shift-Command-4` to select and capture important screens.
- Save as `screenshots/app-demo.png`, `screenshots/test-results.png`, etc.

---

## 4. **Sample Script for Your Demo Video**

Here’s a script you can follow for a smooth, professional demo:

---

**Demo Video Script**

1. **Introduction**
   - “Welcome! This is a demo of the Student Expense Tracker app.”
2. **Login/Authentication**
   - “Let’s start by logging in with a test account.”
3. **Dashboard Overview**
   - “Here’s the dashboard, showing total balance and expenses.”
   - “You can see a summary of recent transactions below.”
4. **Add an Expense**
   - “Let’s add a new expense. Enter the details and save.”
   - “The dashboard updates automatically.”
5. **View Categories/Budgets**
   - “You can manage categories and set budgets from the side menu.”
6. **Profile and Sync**
   - “Profile settings and data sync are available here.”
7. **QA/Testing Results**
   - “Here are the latest automated test results and code coverage.”
   - (Show screenshots or the actual test results in Xcode)
8. **Conclusion**
   - “Thank you for watching this demo!”

---

## 5. **Update the CI Badge in README.md**

Replace the placeholder in your `README.md` with your actual GitHub username and repository name. For example:

```markdown
![iOS CI](https://github.com/machittes/Student-Expense-Tracker/actions/workflows/ios-ci.yml/badge.svg)
```

- If your repo is private, make sure viewers have access to see the badge.

---

## 6. **Push Your Changes**

After adding screenshots and the demo video, run:

```sh
<code_block_to_apply_changes_from>
```

---

If you need actual screenshots or want a checklist for your demo, let me know!  
Would you like a markdown checklist for your demo, or do you want to see example screenshots? 

---

The build and test process failed due to a Swift compilation error in `DashboardView.swift` (and possibly related files). The key error is:

```
'buildExpression' is unavailable: this expression does not conform to 'View'
Testing cancelled because the build failed.
```

This means:
- The tests did not run because the app failed to build.
- The error is likely due to a SwiftUI view builder issue—possibly a misplaced or non-View expression in your `DashboardView.swift`.

---

## What You Should Do Next

1. **Open `DashboardView.swift` in Xcode.**
2. **Look for any code that is not returning a `View`** (e.g., misplaced `let` statements, logic, or non-View expressions inside a `ViewBuilder` context).
3. **Fix the error** (move logic outside the view builder, or wrap it in a `Group` or similar if needed).
4. **Rebuild and re-run tests** (`Command-U` in Xcode).

---

### Example of a Common SwiftUI Error

```swift
VStack {
    let value = 5 // ❌ This is not allowed directly inside a ViewBuilder
    Text("Value: \(value)")
}
```
**Fix:**
```swift
let value = 5
VStack {
    Text("Value: \(value)")
}
```
or
```swift
VStack {
    Group {
        let value = 5
        Text("Value: \(value)")
    }
}
```

---

### Next Steps

- Would you like me to help you pinpoint and fix the error in `DashboardView.swift`?
- Once the build passes, you can re-run the tests and follow the QA steps above.

Let me know if you want to proceed with debugging the SwiftUI error! 

---

The error is caused by `let` statements (and possibly other logic) directly inside SwiftUI view builders, which is not allowed.  
Here are the problematic areas in your `DashboardView.swift`:

---

### 1. **Inside VStack (spanning lines 32–109):**
You have code like:
```swift
VStack(spacing: 20) {
    HStack(spacing: 30) {
        VStack(alignment: .leading) {
            // ...
            let balanceValue = NSDecimalNumber(decimal: viewModel.periodTotalBalance).doubleValue
            Text("$\(String(format: "%.2f", balanceValue))")
                .font(AppFonts.subtitle)
        }
        // ...
    }
    let balance = viewModel.periodTotalBalance
    let expense = viewModel.periodTotalExpense
    let percent: Decimal = balance > 0 ? min(100, (expense / balance) * 100) : 0
    let percentInt: Int = Int(NSDecimalNumber(decimal: percent).doubleValue)
    let balanceValue: Double = NSDecimalNumber(decimal: balance).doubleValue

    let instruction: String
    if expense >= balance && balance > 0 {
        instruction = "Overspending alert!"
    } else if balance == 0 {
        instruction = "No balance left, be careful!"
    } else {
        instruction = "Looks Good."
    }
    // ...
}
```
**This is not allowed.**

---

### 2. **Inside ForEach (spanning lines 144–170):**
You have:
```swift
ForEach(viewModel.filteredTransactions) { transaction in
    HStack {
        // ...
        let amountValue = NSDecimalNumber(decimal: transaction.amount).doubleValue
        let amountText = transaction.isExpense ? "-$\(String(format: "%.2f", amountValue))" : "$\(String(format: "%.2f", amountValue))"
        Text(amountText)
            .font(AppFonts.body)
            .foregroundColor(transaction.isExpense ? .red : .green)
    }
    // ...
}
```
**This is also not allowed.**

---

## **How to Fix**

- Move all `let` statements and logic outside the view builder closures.
- Use computed properties or helper functions, or wrap logic in a `Group {}` if you must keep it inline.

---

## **I will fix these issues for you.**

- Move all `let` and logic outside the view builder closures.
- Use helper computed properties or inline `Group {}` as needed.

Ready to apply the fix! 
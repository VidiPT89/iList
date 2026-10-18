# 🛒 iList

> A shared shopping list for the household, natively built for iOS with SwiftUI.

[Report Bug](https://github.com/VidiPT89/iList/issues) · [Request Feature](https://github.com/VidiPT89/iList/issues)

## ✨ Features

- ✅ Shared shopping lists synced in real time between household members
- ✅ Accounts with Sign in with Apple, Google or email, plus in-app account deletion
- ✅ Invite people to a list with a code or a link; owners can remove members or renew the code
- ✅ Several lists per account (home, holidays, office…)
- ✅ Home screen widget with what's left to buy
- ✅ Optional app lock with a PIN code or Face ID / Touch ID
- ✅ Quick-add catalog with 700+ pre-loaded everyday products across 14 categories
- ✅ Custom item entry with category, quantity and unit
- ✅ Swipe to delete, tap to check off, one-tap clear of checked items
- ✅ See who added each item, at a glance
- ✅ Category filters and instant, accent-insensitive search
- ✅ Runtime language switch — Português (PT-PT) and English, independent of system locale
- ✅ Dark mode, Light mode, and System mode
- ✅ Custom color identity inspired by [ividi.dev](https://ividi.dev/)

## 🛠️ Tech Stack

| Category      | Technology                     |
|---------------|---------------------------------|
| Language      | Swift 5.9+                       |
| UI            | SwiftUI (iOS 26+)                |
| Architecture  | MVVM                             |
| Backend       | Supabase (Auth, Postgres + RLS, Realtime) |
| Security      | Row Level Security, Keychain, LocalAuthentication |

## 🚀 Quick Start

**Prerequisites**
- Xcode 26+
- iOS 26+ simulator or device

**Steps**

```bash
git clone https://github.com/VidiPT89/iList.git
cd iList
open iList.xcodeproj
```

Select the `iList` scheme and run on a simulator or device.

**Using your own Supabase project**

1. Create a project at [supabase.com](https://supabase.com) and run, in the SQL Editor, `supabase_setup.sql` followed by `supabase/migrations/002_accounts_and_sharing.sql`.
2. Enable the Email, Apple and (optionally) Google providers, and add `ilist://login-callback` to the Redirect URLs.
3. Replace the project URL and publishable key in `iList/Services/SupabaseService.swift`.

The publishable key is meant to ship inside the app: every table is protected by Row Level Security, so each person can only read the lists they belong to.

## 📖 Usage

Sign in, choose your name and create a list, or join one with an invite code. Add items from the
quick-add catalog or type a custom one, filter by category, and check items off as they land in the
cart. Every change syncs instantly to everyone in the list. Invite people, switch lists, change
language and appearance, turn on the app lock or delete your account from Settings.

## 🧪 Testing

Build and run the `iList` scheme in Xcode (`⌘R`), or verify the project compiles via:

```bash
xcodebuild -project iList.xcodeproj -scheme iList -destination 'generic/platform=iOS Simulator' build
```

## 📄 License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

## 👨‍💻 Author

**David Arsénio Martins**

🌐 Website: [ividi.dev](https://ividi.dev/)
🐙 GitHub: [@VidiPT89](https://github.com/VidiPT89/)

## 🤝 Contributing

Contributions, issues and feature requests are welcome. Feel free to check the [issues page](https://github.com/VidiPT89/iList/issues).

---

<p align="center">Developed by <a href="https://ividi.dev">David Arsénio Martins</a></p>
<p align="center">If you like this project, consider giving it a ⭐</p>

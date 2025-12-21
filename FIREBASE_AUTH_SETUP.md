# Firebase Authentication Setup

## ⚠️ IMPORTANT: Enable Auth in Firebase Console

Before running the app, you MUST enable Email/Password authentication in Firebase:

### Steps:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **keeptabbys**
3. Click **Authentication** in the left sidebar
4. Click **Get Started** (if first time)
5. Go to **Sign-in method** tab
6. Click **Email/Password**
7. **Toggle ON** the first switch (Email/Password)
8. Click **Save**

### What's Implemented:
- ✅ Sign Up with email/password
- ✅ Sign In with email/password  
- ✅ Sign Out
- ✅ Display name collection during signup
- ✅ Auth state persistence (stays logged in)
- ✅ Host is now a registered authenticated user
- ✅ User info stored with sessions

### Security:
- Passwords must be at least 6 characters
- Email validation included
- Proper error handling for all Firebase auth errors
- User can't access app without authentication

### How It Works:
1. App opens → Check if user logged in
2. If NO → Show login/signup screen
3. If YES → Show home screen
4. When creating room → Uses authenticated user's name and ID
5. When joining room → Uses authenticated user's info
6. Sign out button in app bar

### Testing:
1. First time: Create account (email + password + name)
2. Host a meal: Room created with your authenticated user info
3. Sign out and sign back in: Your account persists
4. Join from another device: They can join with their own account

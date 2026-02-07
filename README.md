# Recipe Action - Shipyard Creator Contest MVP

Turn recipe inspiration into action! AI-powered app that generates grocery lists from TikTok, Instagram, YouTube videos, and recipe URLs.

## 🎯 Contest Brief

**Influencer:** Eitan  
**Problem:** People save recipes they never cook  
**Solution:** Turn "I saw this" into "it's on the table" with AI-powered grocery lists

## ✨ Core Features

### MVP Features
1. **AI Recipe Import**
    - Extract recipes from TikTok, Instagram, YouTube videos
    - Import from any recipe website URL
    - Scan recipe screenshots with image recognition

2. **Smart Grocery Lists**
    - Auto-generate organized grocery lists
    - Categorized by store sections (Produce, Dairy, Meat, etc.)
    - Consolidate ingredients across multiple recipes

3. **Share Everywhere**
    - Share grocery lists via text, email, WhatsApp
    - Export to Reminders app
    - Copy to clipboard

4. **Recipe Organization**
    - "Want to Cook" and "Cooked" collections
    - Search and filter recipes
    - Tag-based organization

### Premium Features (RevenueCat)
- Unlimited recipes (Free: 10 recipes)
- AI-powered import from videos/URLs
- Meal planning calendar
- Recipe collections & folders
- Export to grocery delivery services

## 🛠 Tech Stack

### Frontend
- **Flutter** - Cross-platform (iOS & Android)
- **Provider** - State management
- **Material Design 3** - UI components

### Backend & Services
- **Supabase** - Database, Authentication, Storage
    - PostgreSQL database
    - Row-level security
    - Real-time subscriptions

### AI & Processing
- **Anthropic Claude API** - Recipe extraction from text/images
- **Claude Sonnet 4** - Vision for image recognition

### Monetization
- **RevenueCat** - Subscription management
    - Monthly: $4.99
    - Annual: $39.99 (33% savings)

### Key Packages
```yaml
dependencies:
  supabase_flutter: ^2.3.4
  purchases_flutter: ^6.29.4
  provider: ^6.1.2
  image_picker: ^1.0.7
  share_plus: ^7.2.2
  http: ^1.2.0
```

## 🚀 Setup Instructions

### 1. Prerequisites
```bash
# Install Flutter SDK
flutter --version  # Should be >= 3.0.0

# Clone the repository
git clone <your-repo-url>
cd recipe_action
```

### 2. Supabase Setup

#### A. Create Supabase Project
1. Go to [supabase.com](https://supabase.com)
2. Create new project
3. Copy your Project URL and Anon Key

#### B. Database Setup
Run these SQL commands in Supabase SQL Editor:

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Recipes table
CREATE TABLE recipes (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  title TEXT NOT NULL,
  source_url TEXT,
  source_type TEXT NOT NULL,
  image_url TEXT,
  ingredients JSONB NOT NULL DEFAULT '[]',
  instructions JSONB NOT NULL DEFAULT '[]',
  prep_time TEXT,
  cook_time TEXT,
  servings INTEGER,
  tags TEXT[] DEFAULT '{}',
  want_to_cook BOOLEAN DEFAULT TRUE,
  cooked_date TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Grocery lists table
CREATE TABLE grocery_lists (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  name TEXT NOT NULL,
  items JSONB NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  is_active BOOLEAN DEFAULT TRUE
);

-- Row Level Security
ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE grocery_lists ENABLE ROW LEVEL SECURITY;

-- Policies for recipes
CREATE POLICY "Users can view own recipes"
  ON recipes FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own recipes"
  ON recipes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own recipes"
  ON recipes FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own recipes"
  ON recipes FOR DELETE
  USING (auth.uid() = user_id);

-- Policies for grocery_lists
CREATE POLICY "Users can view own grocery lists"
  ON grocery_lists FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own grocery lists"
  ON grocery_lists FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own grocery lists"
  ON grocery_lists FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own grocery lists"
  ON grocery_lists FOR DELETE
  USING (auth.uid() = user_id);
```

### 3. RevenueCat Setup

#### A. Create RevenueCat Account
1. Sign up at [revenuecat.com](https://www.revenuecat.com)
2. Create new project: "Recipe Action"

#### B. Add Products
Create these products in App Store Connect & Google Play Console:
- `recipe_premium_monthly` - $4.99/month
- `recipe_premium_annual` - $39.99/year

#### C. Configure Entitlements
- Entitlement ID: `premium_features`
- Attach both products to this entitlement

#### D. Get API Keys
Copy your:
- iOS API Key
- Android API Key

### 4. Anthropic API Setup

1. Get API key from [console.anthropic.com](https://console.anthropic.com)
2. Add to your environment variables

### 5. Environment Configuration

Create `.env` file (DO NOT commit this):
```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
ANTHROPIC_API_KEY=your_anthropic_api_key
REVENUECAT_IOS_KEY=your_ios_key
REVENUECAT_ANDROID_KEY=your_android_key
```

Update these files with your keys:
- `lib/services/ai_recipe_extractor.dart` - Add Anthropic API key
- `lib/services/revenue_cat_service.dart` - Add RevenueCat keys
- `lib/main.dart` - Add Supabase credentials

### 6. Install Dependencies

```bash
flutter pub get
```

### 7. iOS Setup

```bash
cd ios
pod install
cd ..
```

Update `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Take photos of recipes to scan them</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Select recipe images from your library</string>
```

### 8. Android Setup

Update `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

## 🏃 Running the App

```bash
# Run on iOS simulator
flutter run -d ios

# Run on Android emulator
flutter run -d android

# Build for production
flutter build ios --release
flutter build apk --release
```

## 📱 Testing In-App Purchases

### iOS Sandbox Testing
1. Create sandbox test account in App Store Connect
2. Sign out of App Store on device
3. Run app and test purchase
4. Sign in with sandbox account when prompted

### Android Testing
1. Add test email to Google Play Console
2. Use internal testing track
3. Test purchases with test account

## 🎨 App Store Assets Needed

### Screenshots (Required for both stores)
- iPhone 6.7": 1290 x 2796 px
- iPhone 5.5": 1242 x 2208 px
- Android Phone: 1080 x 1920 px

### App Icon
- iOS: 1024 x 1024 px (no transparency)
- Android: 512 x 512 px (can have transparency)

### Feature Graphic (Android)
- 1024 x 500 px

## 🚢 Deployment Checklist

### Pre-Launch
- [ ] Test all AI import flows (TikTok, Instagram, YouTube, recipe sites)
- [ ] Test grocery list generation and sharing
- [ ] Verify RevenueCat subscription flow
- [ ] Test on iOS and Android devices
- [ ] Add app icon and splash screen
- [ ] Prepare App Store screenshots
- [ ] Write app descriptions

### App Store Connect (iOS)
- [ ] Create app listing
- [ ] Upload screenshots
- [ ] Set pricing (Free with IAP)
- [ ] Submit for review

### Google Play Console (Android)
- [ ] Create app listing
- [ ] Upload screenshots & feature graphic
- [ ] Set pricing (Free with IAP)
- [ ] Submit for review

## 💡 MVP Development Tips

### Phase 1: Core Loop (Week 1-2)
1. Basic recipe CRUD
2. Manual recipe entry
3. Simple grocery list generation
4. Database integration

### Phase 2: AI Features (Week 2-3)
1. URL scraping for recipe sites
2. Claude API integration
3. Image recipe scanning
4. Video transcript extraction

### Phase 3: Polish & Monetization (Week 3-4)
1. RevenueCat integration
2. Onboarding flow
3. Premium features gating
4. Share functionality
5. UI/UX refinement

### Phase 4: Testing & Launch (Week 4-5)
1. Beta testing with real users
2. Bug fixes
3. App store assets
4. Submission

## 🎯 Success Metrics

Track these in analytics:
- **Activation:** % users who save first recipe
- **Engagement:** Recipes saved per user
- **Conversion:** Free → Premium rate
- **Retention:** Day 1, Day 7, Day 30 retention
- **Revenue:** MRR, ARPU

## 📈 Future Features (Post-MVP)

- Meal planning calendar
- Smart recipe recommendations
- Integration with Instacart/Amazon Fresh APIs
- Social features (share recipes with friends)
- Recipe ratings & reviews
- Nutrition information
- Recipe scaling (adjust servings)
- Dark mode

## 🤝 Contributing

This is a contest submission, but feedback is welcome!

## 📄 License

MIT License - See LICENSE file

## 🎉 Acknowledgments

- **Eitan** - For the challenge brief
- **Shipyard** - For organizing the Creator Contest
- **Anthropic** - For Claude API
- **RevenueCat** - For subscription infrastructure

---

Built with ❤️ for the Shipyard Creator Contest
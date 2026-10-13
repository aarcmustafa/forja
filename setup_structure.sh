#!/usr/bin/env bash
# ==========================================================
#  Estetn Farja IPTV - Project Structure Generator
#  ينشئ هيكل المشروع الكامل لنسخة Android TV / Google TV
# ==========================================================

set -e

ROOT="estitn-farja-iptv"
echo "▶ إنشاء جذر المشروع: $ROOT"
mkdir -p "$ROOT"
cd "$ROOT"

# ----------------------------------------------------------
# 1) تطبيق Flutter - العميل
# ----------------------------------------------------------
echo "▶ إنشاء مجلدات تطبيق Flutter (client)"
mkdir -p client/android/app/src/main/kotlin/com/estitn/farja
mkdir -p client/android/app/src/main/res/{drawable,mipmap-xxxhdpi,values}
mkdir -p client/android/app/src/mobile
mkdir -p client/android/app/src/tv/kotlin/com/estitn/farja/tv
mkdir -p client/android/app/src/tv/res/{drawable,mipmap-xxxhdpi,values}

mkdir -p client/lib/core/{constants,theme,utils}
mkdir -p client/lib/data/{models,repositories,providers}
mkdir -p client/lib/features/{live_tv,movies,series,player}
mkdir -p client/lib/tv/screens
mkdir -p client/lib/tv/widgets
mkdir -p client/lib/tv/navigation

# ----------------------------------------------------------
# 2) الخادم (Backend Proxy)
# ----------------------------------------------------------
echo "▶ إنشاء مجلدات الخادم (server)"
mkdir -p server/src/{routes,middleware,config}

# ----------------------------------------------------------
# 3) خط معالجة البيانات (Data Pipeline)
# ----------------------------------------------------------
echo "▶ إنشاء مجلدات خط معالجة البيانات (data-pipeline)"
mkdir -p data-pipeline/scripts
mkdir -p data-pipeline/sources
mkdir -p data-pipeline/.github/workflows

# ----------------------------------------------------------
# 4) ملفات مشتركة ووثائق
# ----------------------------------------------------------
mkdir -p shared
mkdir -p docs
mkdir -p .github/workflows

# ==========================================================
#  إنشاء الملفات الأساسية الفارغة (Placeholders)
# ==========================================================

echo "▶ إنشاء الملفات الأساسية..."

# --- Android manifests ---
touch client/android/app/src/main/AndroidManifest.xml
touch client/android/app/src/mobile/AndroidManifest.xml
touch client/android/app/src/tv/AndroidManifest.xml
touch client/android/app/src/main/kotlin/com/estitn/farja/MainActivity.kt
touch client/android/app/src/tv/kotlin/com/estitn/farja/tv/MainActivity.kt
touch client/android/app/build.gradle

# --- Flutter entry points ---
touch client/lib/main_mobile.dart
touch client/lib/main_tv.dart
touch client/pubspec.yaml

# --- Server ---
touch server/src/index.js
touch server/src/routes/channels.js
touch server/src/routes/movies.js
touch server/src/routes/stream.js
touch server/src/middleware/auth.js
touch server/src/config/db.js
touch server/package.json
touch server/Dockerfile

# --- Data Pipeline ---
touch data-pipeline/scripts/fetch_sources.py
touch data-pipeline/scripts/parse_m3u.py
touch data-pipeline/scripts/validate_streams.py
touch data-pipeline/scripts/deduplicate.py
touch data-pipeline/scripts/export_db.py
touch data-pipeline/requirements.txt
touch data-pipeline/.github/workflows/update_playlist.yml

# --- Shared + Docs ---
touch shared/schema.sql
touch docs/API.md
touch docs/ARCHITECTURE.md
touch docs/TV_SETUP.md

# --- GitHub Actions ---
touch .github/workflows/build_tv_apk.yml
touch .github/workflows/update_playlist.yml

# --- Root files ---
touch README.md
touch .gitignore
touch docker-compose.yml

# ==========================================================
#  محتوى أساسي لبعض الملفات المهمة
# ==========================================================

# .gitignore
cat > .gitignore <<'EOF'
# Flutter
client/build/
client/.dart_tool/
client/.flutter-plugins
client/.packages
client/pubspec.lock

# Node
server/node_modules/
server/.env

# Python
__pycache__/
*.pyc
data-pipeline/.venv/

# IDE
.idea/
.vscode/
*.iml

# OS
.DS_Store
Thumbs.db
EOF

# README
cat > README.md <<'EOF'
# Estetn Farja IPTV

تطبيق IPTV احترافي يدعم Android TV و Google TV والهواتف.

## البنية
- `client/` تطبيق Flutter (mobile + tv)
- `server/` خادم وكيل لإخفاء روابط البث
- `data-pipeline/` سكربتات فحص وتنظيف روابط M3U
- `shared/` مخطط قاعدة البيانات
- `docs/` الوثائق

## أوامر البناء
```bash
# نسخة التلفاز
flutter build apk --flavor tv -t lib/main_tv.dart

# نسخة الجوال
flutter build apk --flavor mobile -t lib/main_mobile.dart

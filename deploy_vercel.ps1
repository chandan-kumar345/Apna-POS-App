# =========================================================
# Apna POS - One-Click Vercel Web Deployment Script
# =========================================================

Write-Host "🚀 Starting Apna POS Web Build for Vercel..." -ForegroundColor Cyan

# 1. Build Flutter Web Release
Write-Host "📦 Building Flutter Web release bundle..." -ForegroundColor Yellow
flutter build web --release --dart-define=API_URL=https://apna-pos-app.onrender.com/api/v1

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Flutter web build failed. Please resolve the errors above." -ForegroundColor Red
    exit 1
}

# 2. Verify vercel.json in build/web
if (-not (Test-Path "build\web\vercel.json")) {
    Copy-Item "vercel.json" -Destination "build\web\vercel.json"
}

Write-Host "✅ Flutter Web built successfully!" -ForegroundColor Green

# 3. Deploy to Vercel
Write-Host "🌐 Deploying to Vercel Production..." -ForegroundColor Cyan
npx vercel deploy build\web --prod

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n🎉 SUCCESS! Your Apna POS web app is now LIVE on Vercel!" -ForegroundColor Green
} else {
    Write-Host "`n⚠️ Vercel deployment command finished with exit code $LASTEXITCODE" -ForegroundColor Yellow
}

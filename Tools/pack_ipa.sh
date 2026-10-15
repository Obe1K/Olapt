#!/bin/bash
# Запасной способ собрать .ipa вручную, если xcodebuild -exportArchive не сработал:
# копирует приложение из архива, вкладывает профиль и подписывает сертификатом Apple Distribution.
# Нужны переменные: IDENTITY, TEAM_USED, BUNDLE_ID; файл build/sign/profile.mobileprovision.
set -euo pipefail

APP=$(ls -d build/OlaPT.xcarchive/Products/Applications/*.app | head -1)
rm -rf build/manual
mkdir -p build/manual/Payload build/export
cp -R "$APP" build/manual/Payload/
APPDIR=$(ls -d build/manual/Payload/*.app | head -1)
cp build/sign/profile.mobileprovision "$APPDIR/embedded.mobileprovision"

cat > build/sign/ent.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>application-identifier</key><string>${TEAM_USED}.${BUNDLE_ID}</string>
  <key>com.apple.developer.team-identifier</key><string>${TEAM_USED}</string>
  <key>get-task-allow</key><false/>
  <key>beta-reports-active</key><true/>
</dict>
</plist>
EOF

codesign -f -s "$IDENTITY" --entitlements build/sign/ent.plist --timestamp "$APPDIR"
codesign --verify --strict --verbose=2 "$APPDIR"
(cd build/manual && zip -qry ../export/OlaPT.ipa Payload)
ls -la build/export

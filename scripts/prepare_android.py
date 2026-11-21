from pathlib import Path
import shutil
import re

root = Path(__file__).resolve().parents[1]
apps = {
    "admin_app": ("com.example.al_sheikha_admin", "AdminMainActivity.kt"),
    "client_app": ("com.example.al_sheikha_client", "ClientMainActivity.kt"),
}
# Shared Dart address data is copied into each Flutter app's lib tree.
for app in ("admin_app", "client_app"):
    app_shared = root / app / "lib" / "shared"
    app_shared.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / "shared" / "iraq_locations.dart",
                    app_shared / "iraq_locations.dart")

for app, (package, activity_file) in apps.items():
    android = root / app / "android"
    source = root / "shared" / "android"
    pkg_dir = android / "app" / "src" / "main" / "kotlin" / Path(*package.split("."))
    pkg_dir.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source / activity_file, pkg_dir / "MainActivity.kt")
    if app == "admin_app":
        shutil.copyfile(source / "SharedDataProvider.kt", pkg_dir / "SharedDataProvider.kt")
        shutil.copyfile(source / "SharedStoreChannel.kt", pkg_dir / "SharedStoreChannel.kt")
    else:
        shutil.copyfile(source / "ClientSharedStoreChannel.kt", pkg_dir / "ClientSharedStoreChannel.kt")

    manifest = android / "app" / "src" / "main" / "AndroidManifest.xml"
    text = manifest.read_text()
    internet = '<uses-permission android:name="android.permission.INTERNET" />\n'
    if 'android.permission.INTERNET' not in text:
        manifest_start = text.find('<manifest')
        close = text.find('>', manifest_start)
        text = text[:close + 1] + '\n    ' + internet + text[close + 1:]
    if app == "admin_app":
        marker = '<application'
        addition = '''<permission android:name="com.example.al_sheikha_admin.permission.SHARED_DATA" android:protectionLevel="normal" />
    '''
        text = text.replace(marker, addition + marker, 1)
        app_close = '</application>'
        provider = '''<provider
            android:name="com.example.al_sheikha_admin.SharedDataProvider"
            android:authorities="com.example.al_sheikha_admin.shared"
            android:exported="true"
            android:readPermission="com.example.al_sheikha_admin.permission.SHARED_DATA"
            android:writePermission="com.example.al_sheikha_admin.permission.SHARED_DATA" />
        '''
        text = text.replace(app_close, provider + app_close, 1)
    else:
        marker = '<application'
        permission = '<uses-permission android:name="com.example.al_sheikha_admin.permission.SHARED_DATA" />\n    '
        text = text.replace(marker, permission + marker, 1)
    # Ensure Android resizes the Flutter window instead of panning content
    # behind the soft keyboard. This applies to both generated Android apps.
    activity_pattern = r'(<activity\b[^>]*android:name="[^"]*MainActivity"[^>]*)(>)'
    match = re.search(activity_pattern, text, flags=re.DOTALL)
    if match:
        activity_tag = match.group(1)
        if 'android:windowSoftInputMode=' in activity_tag:
            activity_tag = re.sub(r'android:windowSoftInputMode="[^"]*"',
                                  'android:windowSoftInputMode="adjustResize"', activity_tag)
        else:
            activity_tag += ' android:windowSoftInputMode="adjustResize"'
        text = text[:match.start()] + activity_tag + match.group(2) + text[match.end():]
    manifest.write_text(text)

# Give the customer app a clean launcher name and a custom faceless spa icon.
if app == "client_app":
    text = text.replace('android:label="al_sheikha_client"', 'android:label="الشيخة"')
    text = text.replace('android:label="Flutter"', 'android:label="الشيخة"')
    text = text.replace('android:icon="@mipmap/ic_launcher"', 'android:icon="@drawable/sheikha_icon"')
    drawable = android / "app" / "src" / "main" / "res" / "drawable"
    drawable.mkdir(parents=True, exist_ok=True)
    (drawable / "sheikha_icon.xml").write_text("""<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#3B1028" android:pathData="M0,0h108v108h-108z"/>
    <path android:strokeColor="#D7A84B" android:strokeWidth="2.4" android:fillColor="#3B1028" android:pathData="M8,54a46,46 0,1 0,92 0a46,46 0,1 0,-92 0"/>
    <path android:fillColor="#EAD6C2" android:pathData="M54,17c-7,0 -12,7 -12,15v5c-8,4 -14,14 -16,25l-5,24c-1,5 2,8 7,8h52c5,0 8,-3 7,-8l-5,-24c-2,-11 -8,-21 -16,-25v-5c0,-8 -5,-15 -12,-15z"/>
    <path android:fillColor="#3B1028" android:pathData="M42,38c-9,5 -13,15 -14,25l-5,23c-1,4 1,6 5,6h8l8,-23zM66,38c9,5 13,15 14,25l5,23c1,4 -1,6 -5,6h-8l-8,-23z"/>
    <path android:fillColor="#D7A84B" android:pathData="M43,44l11,13 11,-13 5,4 -16,20 -16,-20z"/>
    <path android:fillColor="#D7A84B" android:pathData="M54,75c-6,-8 -13,-8 -18,0 7,-2 12,1 18,8 6,-7 11,-10 18,-8 -5,-8 -12,-8 -18,0z"/>
</vector>
""", encoding="utf-8")

    manifest.write_text(text, encoding="utf-8")

from pathlib import Path
import shutil
import re

root = Path(__file__).resolve().parents[1]
apps = {
    "admin_app": ("com.example.al_sheikha_admin", "AdminMainActivity.kt"),
    "client_app": ("com.example.al_sheikha_client", "ClientMainActivity.kt"),
}
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
    activity_pattern = r'(<activity\\b[^>]*android:name="[^"]*MainActivity"[^>]*)(>)'
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

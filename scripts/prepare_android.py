from pathlib import Path
import shutil

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
    manifest.write_text(text)

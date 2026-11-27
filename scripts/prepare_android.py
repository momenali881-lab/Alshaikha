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
    shutil.copyfile(root / "shared" / "notification_service.dart",
                    app_shared / "notification_service.dart")
    shutil.copyfile(root / "shared" / "one_signal_service.dart",
                    app_shared / "one_signal_service.dart")
    shutil.copyfile(root / "shared" / "one_signal_subscription_gate.dart",
                    app_shared / "one_signal_subscription_gate.dart")

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

    # flutter_local_notifications requires Android core library desugaring.
    gradle_file = android / "app" / "build.gradle.kts"
    gradle_text = gradle_file.read_text(encoding="utf-8")
    if "isCoreLibraryDesugaringEnabled" not in gradle_text:
        compile_options = re.search(r"compileOptions\s*\{", gradle_text)
        if not compile_options:
            raise RuntimeError(f"Missing compileOptions block in {gradle_file}")
        insert_at = compile_options.end()
        gradle_text = (gradle_text[:insert_at] +
                       "\n        isCoreLibraryDesugaringEnabled = true" +
                       gradle_text[insert_at:])
    if "desugar_jdk_libs" not in gradle_text:
        dependencies = re.search(r"dependencies\s*\{", gradle_text)
        if dependencies:
            insert_at = dependencies.end()
            gradle_text = (gradle_text[:insert_at] +
                           '\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")' +
                           gradle_text[insert_at:])
        else:
            gradle_text += ('\ndependencies {\n' +
                            '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")\n' +
                            '}\n')
    gradle_file.write_text(gradle_text, encoding="utf-8")

    manifest = android / "app" / "src" / "main" / "AndroidManifest.xml"
    text = manifest.read_text()
    manifest_start = text.find('<manifest')
    close = text.find('>', manifest_start)
    permission_lines = [
        '<uses-permission android:name="android.permission.INTERNET" />',
        '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />',
        '<uses-permission android:name="android.permission.VIBRATE" />',
    ]
    missing_permissions = [
        line for line in permission_lines
        if line.split('"')[1] not in text
    ]
    if missing_permissions:
        text = (text[:close + 1] + '\n    ' +
                '\n    '.join(missing_permissions) + text[close + 1:])
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
        # Let the customer app draw into the display-cutout/status-bar area so
        # the pink background fills the entire screen behind the camera cutout.
        if app == "client_app" and 'android:windowLayoutInDisplayCutoutMode=' not in activity_tag:
            activity_tag += ' android:windowLayoutInDisplayCutoutMode="shortEdges"'
        text = text[:match.start()] + activity_tag + match.group(2) + text[match.end():]
    # Use the user's exact uploaded artwork as the launcher icon in both apps.
    if app == "client_app":
        text = text.replace('android:label="al_sheikha_client"', 'android:label="الشيخة"')
        text = text.replace('android:label="Flutter"', 'android:label="الشيخة"')
    icon_source = root / "assets" / "launcher_icon.jpg"
    if not icon_source.is_file():
        raise FileNotFoundError(f"Missing original launcher image: {icon_source}")
    with icon_source.open("rb") as image_file:
        signature = image_file.read(8)
    if signature.startswith(bytes.fromhex("ffd8ff")):
        icon_extension = ".jpg"
    elif signature.startswith(bytes.fromhex("89504e470d0a1a0a")):
        icon_extension = ".png"
    else:
        raise ValueError("Launcher image must be a JPEG or PNG file")
    # Flutter's adaptive launcher XML takes precedence over density PNG/JPEG
    # files on Android 8+. Remove the generated defaults so the uploaded artwork
    # is the icon actually selected by Android on modern launchers.
    adaptive_icons = android / "app" / "src" / "main" / "res" / "mipmap-anydpi-v26"
    for adaptive_name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        (adaptive_icons / adaptive_name).unlink(missing_ok=True)

    for density, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                          ("xxhdpi", 144), ("xxxhdpi", 192)):
        mipmap = android / "app" / "src" / "main" / "res" / f"mipmap-{density}"
        mipmap.mkdir(parents=True, exist_ok=True)
        # Remove Flutter's generated launcher files first. Android treats
        # ic_launcher.png and ic_launcher.jpg as the same resource name, so
        # keeping both extensions causes a duplicate-resource build failure.
        for stale_extension in (".png", ".jpg", ".webp"):
            stale_icon = mipmap / f"ic_launcher{stale_extension}"
            if stale_icon.exists() and stale_icon.name != f"ic_launcher{icon_extension}":
                stale_icon.unlink()
        # Resize the unchanged artwork to Android launcher density dimensions.
        from PIL import Image
        with Image.open(icon_source) as original:
            resized = original.convert("RGB").resize((size, size), Image.Resampling.LANCZOS)
            resized.save(mipmap / f"ic_launcher{icon_extension}", quality=100, subsampling=0)

    # Use the supplied artwork as the static native launch screen. No Flutter intro
    # animation or second splash screen is shown after Android starts the app.
    resources = android / "app" / "src" / "main" / "res"
    intro_image = root / app / "assets" / "sheikha_intro.png"
    if not intro_image.is_file():
        raise FileNotFoundError(f"Missing intro artwork: {intro_image}")
    drawable_nodpi = resources / "drawable-nodpi"
    drawable_nodpi.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(intro_image, drawable_nodpi / "sheikha_intro.png")

    launch_drawable = resources / "drawable" / "launch_background.xml"
    launch_drawable.parent.mkdir(parents=True, exist_ok=True)
    launch_drawable.write_text("""<?xml version="1.0" encoding="utf-8"?>
<bitmap xmlns:android="http://schemas.android.com/apk/res/android"
    android:src="@drawable/sheikha_intro"
    android:gravity="fill" />
""", encoding="utf-8")

    values_v31 = resources / "values-v31"
    values_v31.mkdir(parents=True, exist_ok=True)
    (values_v31 / "styles.xml").write_text("""<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowSplashScreenBackground">#B9823D</item>
        <item name="android:windowSplashScreenAnimatedIcon">@drawable/sheikha_intro</item>
        <item name="android:windowSplashScreenAnimationDuration">0</item>
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
</resources>
""", encoding="utf-8")

    # Keep older Android launch screens on the same static supplied artwork.
    values_styles = resources / "values" / "styles.xml"
    if values_styles.exists():
        styles_text = values_styles.read_text(encoding="utf-8")
        styles_text = re.sub(
            r'(<style name="LaunchTheme"[^>]*>)(.*?)(</style>)',
            lambda match: match.group(1) +
                re.sub(r'<item name="android:windowBackground">.*?</item>',
                       '<item name="android:windowBackground">@drawable/launch_background</item>',
                       match.group(2)) +
                ('' if 'name="android:windowBackground"' in match.group(2) else
                 '<item name="android:windowBackground">@drawable/launch_background</item>') +
                match.group(3),
            styles_text, count=1, flags=re.DOTALL)
        values_styles.write_text(styles_text, encoding="utf-8")

    manifest.write_text(text, encoding="utf-8")
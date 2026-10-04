import unittest
from tools.verify_android_apk import validate_manifest

MANIFEST = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="org.lseyesl.microapex">
<application>
<activity android:name="com.godot.game.GodotApp" android:exported="false"/>
<activity-alias android:name=".Launcher" android:targetActivity="com.godot.game.GodotApp" android:exported="true">
<intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter>
</activity-alias>
<provider android:name="androidx.core.content.FileProvider" android:authorities="org.lseyesl.microapex.fileprovider"/>
<provider android:name="androidx.startup.InitializationProvider" android:authorities="org.lseyesl.microapex.androidx-startup"/>
</application></manifest>'''

class ManifestTests(unittest.TestCase):
    def test_exported_alias_to_private_activity_is_valid(self):
        self.assertEqual(validate_manifest(MANIFEST)['launchers'], ['.Launcher'])

    def test_legacy_export_duplicate_authority_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Duplicate provider authority'):
            validate_manifest(MANIFEST.replace('org.lseyesl.microapex.androidx-startup', 'org.lseyesl.microapex.fileprovider'))

    def test_missing_launcher_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'No MAIN/LAUNCHER'):
            validate_manifest(MANIFEST.replace('android.intent.category.LAUNCHER', 'android.intent.category.DEFAULT'))

    def test_non_exported_launcher_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'must be exported'):
            validate_manifest(MANIFEST.replace('android:exported="true"', 'android:exported="false"'))

    def test_missing_alias_target_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'missing activity'):
            validate_manifest(MANIFEST.replace('android:targetActivity="com.godot.game.GodotApp"', 'android:targetActivity=".Missing"'))

    def test_unexpanded_placeholder_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Invalid provider authority'):
            validate_manifest(MANIFEST.replace('org.lseyesl.microapex.androidx-startup', '${applicationId}.androidx-startup'))

if __name__ == '__main__': unittest.main()

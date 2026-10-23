import hashlib, importlib.util, os, pathlib, tempfile, unittest, zipfile
from unittest import mock
spec = importlib.util.spec_from_file_location('publisher', pathlib.Path(__file__).resolve().parents[1] / 'tools/publish_android_artifact.py')
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)

class PublishValidationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = pathlib.Path(self.temp.name)
        self.pin = 'a' * 64
        self.make_files()

    def make_files(self, arch='arm64-v8a'):
        with zipfile.ZipFile(self.path / publisher.FILES[0], 'w') as apk:
            apk.writestr(f'lib/{arch}/libgodot_android.so', b'fixture native library')
        self.sha = publisher.digest(self.path / publisher.FILES[0])
        (self.path / publisher.FILES[1]).write_text(self.sha + '  micro-apex-debug.apk\n')
        (self.path / publisher.FILES[2]).write_text("package: name='org.lseyesl.microapex' versionCode='22' versionName='0.13.3'\n")
        (self.path / publisher.FILES[3]).write_text(self.pin + '\n')

    def assets(self):
        return [dict(name=n, state='uploaded', size=(self.path / n).stat().st_size, digest='sha256:' + publisher.digest(self.path / n)) for n in publisher.artifact_files(self.path)]

    def test_valid_artifact_and_already_uploaded_assets(self):
        self.assertEqual(publisher.validate_files(self.path, self.sha, self.pin), ('22', '0.13.3'))
        publisher.verify_assets(self.assets(), self.path)

    def test_named_variant_artifacts_and_style_mismatch(self):
        import json
        for style in ('original', 'bright_clay'):
            with self.subTest(style=style):
                data = dict(format=1, model_style=style, locked=True, model_ids=['car_test'])
                self.make_files()
                with zipfile.ZipFile(self.path / publisher.FILES[0], 'a') as archive:
                    archive.writestr('assets/config/model_style.json', json.dumps(data))
                name = f'micro-apex-{style}-debug-arm64.apk'
                (self.path / publisher.FILES[0]).rename(self.path / name)
                sha = publisher.digest(self.path / name)
                (self.path / publisher.FILES[1]).unlink()
                (self.path / (name + '.sha256')).write_text(sha + '  ' + name + '\n')
                (self.path / 'model-style.json').write_text(json.dumps(data))
                self.assertEqual(publisher.validate_files(self.path, sha, self.pin), ('22', '0.13.3'))
                publisher.verify_assets(self.assets(), self.path)
                wrong = f"micro-apex-{'bright_clay' if style == 'original' else 'original'}-debug-arm64.apk"
                (self.path / name).rename(self.path / wrong)
                (self.path / (name + '.sha256')).unlink()
                (self.path / (wrong + '.sha256')).write_text(sha + '  ' + wrong + '\n')
                with self.assertRaisesRegex(ValueError, 'filename and packaged style'):
                    publisher.validate_files(self.path, sha, self.pin)
                (self.path / wrong).unlink()
                (self.path / (wrong + '.sha256')).unlink()
                (self.path / 'model-style.json').unlink()

    def test_changed_apk_rejected(self):
        with self.assertRaisesRegex(ValueError, 'approved build'):
            publisher.validate_files(self.path, 'b' * 64, self.pin)

    def test_wrong_certificate_rejected(self):
        with self.assertRaisesRegex(ValueError, 'certificate'):
            publisher.validate_files(self.path, self.sha, 'b' * 64)

    def test_wrong_architecture_rejected(self):
        self.make_files('x86_64')
        with self.assertRaisesRegex(ValueError, 'ARM64'):
            publisher.validate_files(self.path, self.sha, self.pin)

    def test_wrong_package_rejected(self):
        (self.path / publisher.FILES[2]).write_text("package: name='other.app' versionCode='22' versionName='0.13.3'")
        with self.assertRaisesRegex(ValueError, 'package/version'):
            publisher.validate_files(self.path, self.sha, self.pin)

    def test_unexpected_file_rejected(self):
        (self.path / 'unexpected').touch()
        with self.assertRaisesRegex(ValueError, 'contents'):
            publisher.validate_files(self.path, self.sha, self.pin)

    def test_conflicting_or_incomplete_asset_rejected(self):
        for field, value in [('digest', 'sha256:' + 'b' * 64), ('digest', None), ('size', 1), ('state', 'starter')]:
            with self.subTest(field=field, value=value):
                assets = self.assets()
                assets[0][field] = value
                with self.assertRaises(ValueError):
                    publisher.verify_assets(assets, self.path)

    def test_duplicate_or_unknown_asset_rejected(self):
        assets = self.assets()
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            publisher.verify_assets(assets + [assets[0]], self.path)
        assets[0]['name'] = 'unknown.apk'
        with self.assertRaisesRegex(ValueError, 'Unexpected'):
            publisher.verify_assets(assets, self.path)

    def test_sealed_style_metadata_is_preserved_and_must_match_apk(self):
        data = dict(format=1, model_style='bright_clay', locked=True, model_ids=['car_test'])
        import json
        with zipfile.ZipFile(self.path / publisher.FILES[0], 'a') as apk:
            apk.writestr('assets/config/model_style.json', json.dumps(data))
        self.sha = publisher.digest(self.path / publisher.FILES[0])
        (self.path / publisher.FILES[1]).write_text(self.sha + '  micro-apex-debug.apk\n')
        (self.path / 'model-style.json').write_text(json.dumps(data))
        self.assertEqual(publisher.validate_files(self.path, self.sha, self.pin), ('22', '0.13.3'))
        publisher.verify_assets(self.assets(), self.path)
        (self.path / 'model-style.json').unlink()
        with self.assertRaisesRegex(ValueError, 'Missing model style'):
            publisher.validate_files(self.path, self.sha, self.pin)
        data['model_style'] = 'original'
        (self.path / 'model-style.json').write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, 'style metadata'):
            publisher.validate_files(self.path, self.sha, self.pin)

    def test_cloud_upload_is_refused_before_network(self):
        with mock.patch.dict(os.environ, {'GITHUB_ACTIONS': 'false'}), mock.patch.object(publisher, 'gh') as gh:
            with self.assertRaisesRegex(ValueError, 'Actions'):
                publisher.publish('owner/repo', '1', '2', '3', 'v0.13.3-fix', 'a' * 40, 'b' * 64)
            gh.assert_not_called()

    def test_wrong_source_commit_stops_before_download_or_upload(self):
        run = dict(status='completed', conclusion='success', repository=dict(full_name='owner/repo'), head_sha='c' * 40)
        with mock.patch.dict(os.environ, {'GITHUB_ACTIONS': 'true'}), mock.patch.object(publisher, 'api', return_value=run), mock.patch.object(publisher, 'gh') as gh:
            with self.assertRaisesRegex(ValueError, 'SHA mismatch'):
                publisher.publish('owner/repo', '1', '2', '3', 'v0.13.3-fix', 'a' * 40, 'b' * 64)
            gh.assert_not_called()

if __name__ == '__main__':
    unittest.main()

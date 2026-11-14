import sys
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from smoke import launch_macos


class MacLaunchTest(unittest.TestCase):
    def setUp(self):
        self.run = patch('smoke.subprocess.run').start()
        self.launcher = patch('smoke.subprocess.Popen').start().return_value
        self.launcher.poll.return_value = None
        self.kill = patch('smoke.os.kill').start()
        patch('smoke.time.sleep').start()
        self.addCleanup(patch.stopall)

    def test_tracks_translocated_instance_and_preserves_existing_app(self):
        with patch('smoke.running_macos_instances', side_effect=[{111}, {111, 222}, {111, 222}]):
            launch_macos(Path('/tmp/input.app'))
        self.assertEqual([call.args[0] for call in self.kill.call_args_list], [222])
        self.launcher.terminate.assert_called_once()
        self.assertIn('com.apple.quarantine', self.run.call_args_list[0].args[0])

    def test_app_exits_prematurely(self):
        with patch('smoke.running_macos_instances', side_effect=[set(), {222}, set()]):
            with self.assertRaisesRegex(RuntimeError, 'exited prematurely'):
                launch_macos(Path('/tmp/input.app'))
        self.launcher.terminate.assert_called_once()

    def test_bounded_startup(self):
        with patch('smoke.running_macos_instances', return_value=set()), patch('smoke.time.monotonic', side_effect=[0, 1, 31]):
            with self.assertRaisesRegex(RuntimeError, '30 seconds'):
                launch_macos(Path('/tmp/input.app'))
        self.kill.assert_not_called()
        self.launcher.terminate.assert_called_once()

    def test_launch_services_rejection(self):
        self.launcher.poll.return_value = 1
        with patch('smoke.running_macos_instances', return_value=set()):
            with self.assertRaisesRegex(RuntimeError, 'Launch Services rejected'):
                launch_macos(Path('/tmp/input.app'))
        self.kill.assert_not_called()


if __name__ == '__main__':
    unittest.main()

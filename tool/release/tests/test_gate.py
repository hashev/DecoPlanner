import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from gate import check


class GateTest(unittest.TestCase):
    def test_all_success(self):
        self.assertTrue(check({"test": {"result": "success"}, "build": {"result": "success"}}))

    def test_no_false_green(self):
        for result in ["failure", "cancelled", "skipped", None]:
            with self.subTest(result=result):
                self.assertFalse(check({"test": {"result": "success"}, "build": {"result": result}}))
        self.assertFalse(check({}))
        self.assertFalse(check({"build": {}}))

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from version import resolve


class VersionTest(unittest.TestCase):
    def test_valid(self):
        for tag, code in [("v0.0.1", 1), ("v0.1.0", 1000),
                          ("v1.2.3", 1002003), ("v2099.999.999", 2099999999),
                          ("v2100.0.0", 2100000000)]:
            with self.subTest(tag=tag):
                self.assertEqual(resolve(tag), {"tag": tag, "name": tag[1:], "code": code})

    def test_invalid(self):
        for tag in ["v0.0.0", "v2100.0.1", "v2101.0.0", "v1.1000.0",
                    "v1.0.1000", "v01.0.0", "v1.00.0", "v1.0.01",
                    "v1.0.0-rc.1", "v1.0.0+1", "1.0.0", "v-1.0.0",
                    "v1.0.0\n", "v1.0.0;echo bad", "$(echo bad)", "v١.0.0"]:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                resolve(tag)

    def test_monotonic(self):
        tags = ["v0.0.1", "v0.0.999", "v0.1.0", "v0.999.999", "v1.0.0"]
        codes = [resolve(tag)["code"] for tag in tags]
        self.assertEqual(codes, sorted(set(codes)))


if __name__ == "__main__":
    unittest.main()

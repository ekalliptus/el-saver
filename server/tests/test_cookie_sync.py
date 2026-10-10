import hashlib
import hmac
import os
import sys
import tempfile
import unittest
from datetime import timedelta
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("API_KEY", "test-api-key")
os.environ.setdefault("ADMIN_KEY", "test-admin-key")

SERVER_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SERVER_DIR))

import cookie_sync
from cookie_sync import (
    AdminConfirmPayload,
    OrderPayload,
    PaymentWebhookPayload,
    RedeemPayload,
)


def _req(ip: str = "10.9.0.1"):
    """Minimal FastAPI Request stub so endpoint functions are callable directly."""
    return cookie_sync.Request(
        scope={"type": "http", "client": (ip, 50000), "headers": []},
    )


def _sign(order_id: str | None, amount: str | None, secret: bytes = b"test-whsec") -> str:
    msg = f"{order_id or ''}|{amount or ''}"
    return hmac.new(secret, msg.encode(), hashlib.sha256).hexdigest()


def _static_qris() -> str:
    return cookie_sync._tlv_build([("00", "01"), ("01", "11"), ("53", "360"), ("58", "ID")])


class CookieSyncDomainTests(unittest.TestCase):
    def test_bilibili_global_uses_bilibili_tv_domain_without_guessed_keys(self):
        with tempfile.TemporaryDirectory() as directory, \
             patch.object(cookie_sync, "COOKIE_DIR", Path(directory)):
            cookie_sync._write_netscape("bilibili", "SESSDATA=value; bili_jct=csrf")
            lines = (Path(directory) / "bilibili.txt").read_text().splitlines()
        cookie_lines = [line for line in lines if not line.startswith("#")]
        self.assertTrue(cookie_lines)
        self.assertTrue(all(line.startswith(".bilibili.tv\tTRUE\t") for line in cookie_lines))
        self.assertTrue(any("\tSESSDATA\tvalue" in line for line in cookie_lines))
        self.assertTrue(any("\tbili_jct\tcsrf" in line for line in cookie_lines))

    def test_meta_platforms_require_complete_auth_cookie_sets(self):
        incomplete = {
            "instagram": "sessionid=s",
            "facebook": "c_user=1",
        }
        for platform, cookies in incomplete.items():
            with self.subTest(platform=platform), self.assertRaises(cookie_sync.HTTPException) as error:
                cookie_sync.set_cookies(
                    cookie_sync.CookiePayload(platform=platform, cookies=cookies),
                    _req(),
                    cookie_sync.API_KEY,
                )
            self.assertEqual(error.exception.status_code, 400)

    def test_complete_instagram_cookie_set_is_accepted(self):
        with tempfile.TemporaryDirectory() as directory, \
             patch.object(cookie_sync, "COOKIE_DIR", Path(directory)), \
             patch.object(cookie_sync, "COOKIE_PATH", Path(directory) / "cookies.json"), \
             patch.object(cookie_sync, "_restart_cobalt", return_value=False):
            response = cookie_sync.set_cookies(
                cookie_sync.CookiePayload(
                    platform="instagram",
                    cookies="sessionid=s; ds_user_id=1; csrftoken=c",
                ),
                _req(),
                cookie_sync.API_KEY,
            )
        self.assertEqual(response["status"], "ok")

    def test_rejects_netscape_control_character_injection(self):
        with self.assertRaises(ValueError):
            cookie_sync._cookie_pairs("sessionid=s; name=value\n.example\tTRUE\tvalue")

    def test_delete_rejects_unknown_platform(self):
        with self.assertRaises(cookie_sync.HTTPException) as error:
            cookie_sync.delete_cookies("../evil", _req(), cookie_sync.API_KEY)
        self.assertEqual(error.exception.status_code, 400)


class QrisTests(unittest.TestCase):
    def test_dynamic_qris_injects_amount_and_recomputes_crc(self):
        dynamic = cookie_sync._qris_dynamic(_static_qris(), "5000.37")
        entries = dict(cookie_sync._tlv_parse(dynamic))
        self.assertEqual(entries["01"], "12")
        self.assertEqual(entries["54"], "5000.37")
        self.assertEqual(entries["53"], "360")
        self.assertEqual(dynamic[-4:], cookie_sync._crc16(dynamic[:-4]))

    def test_malformed_qris_raises_instead_of_500(self):
        with self.assertRaises(ValueError):
            cookie_sync._tlv_parse("zz99abc")

    def test_order_unique_suffix_always_between_1_and_99(self):
        for seed in range(0, 300):
            order_id = f"{seed:04x}abcdef012345"
            suffix = cookie_sync._order_unique_suffix(order_id)
            self.assertTrue(1 <= suffix <= 99)


class StoreIntegrityTests(unittest.TestCase):
    def test_corrupt_store_fails_loud_and_is_backed_up(self):
        with tempfile.TemporaryDirectory() as directory, \
             patch.object(cookie_sync, "PREMIUM_FILE", Path(directory) / "lic.json"):
            cookie_sync.PREMIUM_FILE.write_text("{not json")
            with self.assertRaises(cookie_sync.HTTPException) as error:
                cookie_sync._read_licenses()
            self.assertEqual(error.exception.status_code, 500)
            backups = list(cookie_sync.PREMIUM_FILE.parent.glob("*.corrupt-*"))
            self.assertEqual(len(backups), 1)

    def test_atomic_write_roundtrip(self):
        with tempfile.TemporaryDirectory() as directory, \
             patch.object(cookie_sync, "ORDER_FILE", Path(directory) / "orders.json"):
            cookie_sync._write_orders({"o1": {"status": "pending"}})
            self.assertEqual(cookie_sync._read_orders(), {"o1": {"status": "pending"}})
            self.assertFalse(list(cookie_sync.ORDER_FILE.parent.glob("*.tmp")))


class RedeemTests(unittest.TestCase):
    def test_redeem_binds_device_and_blocks_second_device(self):
        key = "ELS-ABCD-EFGH-JKLM"
        with tempfile.TemporaryDirectory() as directory, \
             patch.object(cookie_sync, "PREMIUM_FILE", Path(directory) / "lic.json"):
            cookie_sync._write_licenses({key: {"device_id": None, "redeemed_at": None}})

            response = cookie_sync.premium_redeem(
                RedeemPayload(key=key.lower(), device_id="a" * 16),
                _req("10.9.1.1"), cookie_sync.API_KEY,
            )
            self.assertEqual(response["premium"], True)

            with self.assertRaises(cookie_sync.HTTPException) as error:
                cookie_sync.premium_redeem(
                    RedeemPayload(key=key, device_id="b" * 16),
                    _req("10.9.1.2"), cookie_sync.API_KEY,
                )
            self.assertEqual(error.exception.status_code, 409)

    def test_redeem_rejects_unknown_key_and_bad_format(self):
        with tempfile.TemporaryDirectory() as directory, \
             patch.object(cookie_sync, "PREMIUM_FILE", Path(directory) / "lic.json"):
            with self.assertRaises(cookie_sync.HTTPException) as error:
                cookie_sync.premium_redeem(
                    RedeemPayload(key="ELS-ZZZZ-ZZZZ-ZZZZ", device_id="a" * 16),
                    _req("10.9.2.1"), cookie_sync.API_KEY,
                )
            self.assertEqual(error.exception.status_code, 404)
            with self.assertRaises(cookie_sync.HTTPException) as error:
                cookie_sync.premium_redeem(
                    RedeemPayload(key="NOT-A-KEY", device_id="a" * 16),
                    _req("10.9.2.2"), cookie_sync.API_KEY,
                )
            self.assertEqual(error.exception.status_code, 400)


class LicenseExpiryTests(unittest.TestCase):
    def test_expiry_aware_and_naive_timestamps(self):
        now = cookie_sync._now_utc()
        self.assertFalse(cookie_sync._license_active({}))
        self.assertTrue(cookie_sync._license_active({"device_id": "a" * 16}))
        self.assertTrue(cookie_sync._license_active(
            {"device_id": "a" * 16, "expires_at": (now + timedelta(days=1)).isoformat()},
        ))
        self.assertFalse(cookie_sync._license_active(
            {"device_id": "a" * 16, "expires_at": (now - timedelta(days=1)).isoformat()},
        ))
        # Legacy rows stored naive utcnow() strings must not crash the compare.
        self.assertFalse(cookie_sync._license_active(
            {"device_id": "a" * 16, "expires_at": "2020-01-01T00:00:00"},
        ))


class OrderFlowTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        base = Path(self._tmp.name)
        patcher = unittest.mock.patch.multiple(
            cookie_sync,
            PREMIUM_FILE=base / "lic.json",
            ORDER_FILE=base / "orders.json",
            STATIC_QRIS=_static_qris(),
            WEBHOOK_SECRET="test-whsec",
        )
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(self._tmp.cleanup)
        self.addCleanup(cookie_sync._rate_hits.clear)

    def _order(self, ip: str, device: str = "a" * 16, package: str = "monthly"):
        return cookie_sync.premium_order(
            OrderPayload(device_id=device, package_id=package),
            _req(ip), cookie_sync.API_KEY,
        )

    def test_order_requires_configured_qris(self):
        with patch.object(cookie_sync, "STATIC_QRIS", ""):
            with self.assertRaises(cookie_sync.HTTPException) as error:
                self._order("10.9.3.1")
            self.assertEqual(error.exception.status_code, 503)

    def test_order_creates_reserved_license_and_dynamic_qris(self):
        order = self._order("10.9.3.2")
        entries = dict(cookie_sync._tlv_parse(order["qris"]))
        self.assertEqual(entries["01"], "12")
        self.assertEqual(entries["54"], order["gross_amount"])
        self.assertEqual(entries["63"], cookie_sync._crc16(order["qris"][:-4]))
        orders = cookie_sync._read_orders()
        stored = orders[order["order_id"]]
        self.assertEqual(stored["status"], "pending")
        licenses = cookie_sync._read_licenses()
        self.assertIn(stored["license"], licenses)

    def test_order_caps_pending_orders_per_device(self):
        for _ in range(cookie_sync.MAX_PENDING_ORDERS_PER_DEVICE):
            self._order("10.9.3.3", device="c" * 16)
        with self.assertRaises(cookie_sync.HTTPException) as error:
            self._order("10.9.3.3", device="c" * 16)
        self.assertEqual(error.exception.status_code, 429)

    def test_admin_confirm_requires_admin_key(self):
        order = self._order("10.9.3.4")
        with self.assertRaises(cookie_sync.HTTPException) as error:
            cookie_sync.premium_admin_confirm(
                AdminConfirmPayload(admin_key="wrong", order_id=order["order_id"]),
                _req("10.9.3.4"),
            )
        self.assertEqual(error.exception.status_code, 403)

    def test_admin_confirm_activates_license_and_is_idempotent(self):
        order = self._order("10.9.3.5")
        response = cookie_sync.premium_admin_confirm(
            AdminConfirmPayload(admin_key="test-admin-key", order_id=order["order_id"]),
            _req("10.9.3.5"),
        )
        self.assertEqual(response["paid"], True)
        stored = cookie_sync._read_orders()[order["order_id"]]
        entry = cookie_sync._read_licenses()[stored["license"]]
        self.assertEqual(entry["device_id"], "a" * 16)
        self.assertIsNotNone(entry["expires_at"])
        again = cookie_sync.premium_admin_confirm(
            AdminConfirmPayload(admin_key="test-admin-key", order_id=order["order_id"]),
            _req("10.9.3.5"),
        )
        self.assertEqual(again["already_paid"], True)


    def test_order_gross_amount_is_whole_rupiah(self):
        # Unique suffix must be whole rupiah (15059), never a decimal
        # (15000.59 renders as "Rp15.000,59" in e-wallets — confusing).
        order = self._order("10.9.7.9")
        self.assertEqual(order["gross_amount"], str(int(order["gross_amount"])))

    def test_history_lists_orders_for_device_only(self):
        mine = self._order("10.9.7.10", device="d" * 16)
        self._order("10.9.7.11", device="e" * 16)  # someone else
        response = cookie_sync.premium_order_history(
            cookie_sync.HistoryPayload(device_id="d" * 16),
            _req("10.9.7.12"), cookie_sync.API_KEY,
        )
        ids = [r["order_id"] for r in response["orders"]]
        self.assertEqual(ids, [mine["order_id"]])

    def test_order_status_regenerates_qris_for_pending(self):
        order = self._order("10.9.7.13")
        response = cookie_sync.premium_order_status(
            order["order_id"], cookie_sync.API_KEY)
        entries = dict(cookie_sync._tlv_parse(response["qris"]))
        self.assertEqual(entries["54"], order["gross_amount"])


class WebhookTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        base = Path(self._tmp.name)
        patcher = unittest.mock.patch.multiple(
            cookie_sync,
            PREMIUM_FILE=base / "lic.json",
            ORDER_FILE=base / "orders.json",
            STATIC_QRIS=_static_qris(),
            WEBHOOK_SECRET="test-whsec",
        )
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(self._tmp.cleanup)
        self.addCleanup(cookie_sync._rate_hits.clear)
        self.order = cookie_sync.premium_order(
            OrderPayload(device_id="d" * 16, package_id="yearly"),
            _req("10.9.4.1"), cookie_sync.API_KEY,
        )

    def test_webhook_requires_secret_and_valid_signature(self):
        with self.assertRaises(cookie_sync.HTTPException) as error:
            cookie_sync.premium_webhook(
                PaymentWebhookPayload(order_id=self.order["order_id"],
                                      gross_amount=self.order["gross_amount"],
                                      signature="bad"),
                _req("10.9.4.2"),
            )
        self.assertEqual(error.exception.status_code, 403)

    def test_webhook_activates_order_by_id_and_sets_expiry(self):
        response = cookie_sync.premium_webhook(
            PaymentWebhookPayload(
                order_id=self.order["order_id"],
                gross_amount=self.order["gross_amount"],
                signature=_sign(self.order["order_id"], self.order["gross_amount"]),
            ),
            _req("10.9.4.3"),
        )
        self.assertEqual(response["paid"], True)
        stored = cookie_sync._read_orders()[self.order["order_id"]]
        entry = cookie_sync._read_licenses()[stored["license"]]
        self.assertEqual(entry["device_id"], "d" * 16)
        self.assertIsNotNone(entry["expires_at"])

    def test_webhook_rejects_amount_mismatch_for_known_order(self):
        wrong = "9999.99"
        with self.assertRaises(cookie_sync.HTTPException) as error:
            cookie_sync.premium_webhook(
                PaymentWebhookPayload(
                    order_id=self.order["order_id"],
                    gross_amount=wrong,
                    signature=_sign(self.order["order_id"], wrong),
                ),
                _req("10.9.4.4"),
            )
        self.assertEqual(error.exception.status_code, 409)
        self.assertEqual(
            cookie_sync._read_orders()[self.order["order_id"]]["status"], "pending",
        )

    def test_webhook_matches_fresh_pending_order_by_amount(self):
        response = cookie_sync.premium_webhook(
            PaymentWebhookPayload(
                gross_amount=self.order["gross_amount"],
                signature=_sign("", self.order["gross_amount"]),
            ),
            _req("10.9.4.5"),
        )
        self.assertEqual(response["paid"], True)
        self.assertEqual(response["order_id"], self.order["order_id"])

    def test_webhook_amount_match_ignores_stale_orders(self):
        orders = cookie_sync._read_orders()
        stale = orders[self.order["order_id"]]
        stale["created_at"] = (cookie_sync._now_utc() - timedelta(days=3)).isoformat()
        cookie_sync._write_orders(orders)
        with self.assertRaises(cookie_sync.HTTPException) as error:
            cookie_sync.premium_webhook(
                PaymentWebhookPayload(
                    gross_amount=self.order["gross_amount"],
                    signature=_sign("", self.order["gross_amount"]),
                ),
                _req("10.9.4.6"),
            )
        self.assertEqual(error.exception.status_code, 404)

    def test_webhook_amount_comparison_is_numeric_not_string(self):
        amount = self.order["gross_amount"]
        if "." in amount:
            whole, cents = amount.split(".")
            # "15000.50" vs "15000.5": numerically equal, string-different.
            equivalent = f"{whole}.{cents.rstrip('0') or '0'}"
        else:
            # Whole-rupiah amounts: compare "15059" against a legacy decimal
            # spelling of the same value to prove numeric matching.
            equivalent = f"{amount}.00"
        response = cookie_sync.premium_webhook(
            PaymentWebhookPayload(
                gross_amount=equivalent,
                signature=_sign("", equivalent),
            ),
            _req("10.9.4.7"),
        )
        self.assertEqual(response["paid"], True)

    def test_webhook_ignores_non_settlement_status(self):
        response = cookie_sync.premium_webhook(
            PaymentWebhookPayload(
                order_id=self.order["order_id"],
                gross_amount=self.order["gross_amount"],
                status="pending",
                signature=_sign(self.order["order_id"], self.order["gross_amount"]),
            ),
            _req("10.9.4.8"),
        )
        self.assertEqual(response["status"], "ignored")


class RateLimitTests(unittest.TestCase):
    def test_burst_beyond_limit_is_rejected(self):
        cookie_sync._rate_hits.clear()
        for _ in range(3):
            cookie_sync._rate_limit(_req("99.9.9.9"), "test-scope", 3, 60)
        with self.assertRaises(cookie_sync.HTTPException) as error:
            cookie_sync._rate_limit(_req("99.9.9.9"), "test-scope", 3, 60)
        self.assertEqual(error.exception.status_code, 429)
        # Different IP is unaffected.
        cookie_sync._rate_limit(_req("99.9.9.8"), "test-scope", 3, 60)


class WebhookTimestampTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        base = Path(self._tmp.name)
        patcher = unittest.mock.patch.multiple(
            cookie_sync,
            PREMIUM_FILE=base / "lic.json",
            ORDER_FILE=base / "orders.json",
            STATIC_QRIS=_static_qris(),
            WEBHOOK_SECRET="test-whsec",
        )
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(self._tmp.cleanup)
        self.addCleanup(cookie_sync._rate_hits.clear)
        self.order = cookie_sync.premium_order(
            OrderPayload(device_id="e" * 16, package_id="monthly"),
            _req("10.9.5.1"), cookie_sync.API_KEY,
        )

    def _sig(self, timestamp=None):
        oid, amt = self.order["order_id"], self.order["gross_amount"]
        msg = f"{oid}|{amt}|{timestamp}" if timestamp is not None else f"{oid}|{amt}"
        return hmac.new(b"test-whsec", msg.encode(), hashlib.sha256).hexdigest()

    def _post(self, timestamp, signature=None):
        return cookie_sync.premium_webhook(
            PaymentWebhookPayload(
                order_id=self.order["order_id"],
                gross_amount=self.order["gross_amount"],
                timestamp=timestamp,
                signature=signature or self._sig(timestamp),
            ),
            _req("10.9.5.2"),
        )

    def test_timestamped_signature_is_accepted(self):
        ts = int(cookie_sync._now_utc().timestamp())
        response = self._post(ts)
        self.assertEqual(response["paid"], True)

    def test_stale_timestamp_is_rejected(self):
        old = int(cookie_sync._now_utc().timestamp()) - 3600
        with self.assertRaises(cookie_sync.HTTPException) as error:
            self._post(old)
        self.assertEqual(error.exception.status_code, 403)
        self.assertEqual(
            cookie_sync._read_orders()[self.order["order_id"]]["status"],
            "pending",
        )

    def test_timestamp_outside_signature_is_rejected(self):
        ts = int(cookie_sync._now_utc().timestamp())
        # Signature over the legacy message (no timestamp) while a timestamp
        # is present in the payload: must not verify.
        with self.assertRaises(cookie_sync.HTTPException) as error:
            self._post(ts, signature=self._sig())
        self.assertEqual(error.exception.status_code, 403)


class LegacyDeviceMigrationTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        patcher = unittest.mock.patch.multiple(
            cookie_sync,
            PREMIUM_FILE=Path(self._tmp.name) / "lic.json",
            ORDER_FILE=Path(self._tmp.name) / "orders.json",
        )
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(self._tmp.cleanup)
        self.addCleanup(cookie_sync._rate_hits.clear)

    def test_verify_migrates_legacy_binding(self):
        legacy = "a" * 16
        current = "b" * 16
        cookie_sync._write_licenses({
            "ELS-AAAA-BBBB-CCCC": {
                "device_id": legacy, "redeemed_at": None,
            },
        })
        response = cookie_sync.premium_verify(
            cookie_sync.VerifyPayload(device_id=current, legacy_device_id=legacy),
            cookie_sync.API_KEY,
        )
        self.assertEqual(response["premium"], True)
        entry = cookie_sync._read_licenses()["ELS-AAAA-BBBB-CCCC"]
        self.assertEqual(entry["device_id"], current)

    def test_verify_does_not_migrate_someone_elses_legacy_id(self):
        cookie_sync._write_licenses({
            "ELS-AAAA-BBBB-CCCC": {
                "device_id": "c" * 16, "redeemed_at": None,
            },
        })
        response = cookie_sync.premium_verify(
            cookie_sync.VerifyPayload(device_id="b" * 16, legacy_device_id="a" * 16),
            cookie_sync.API_KEY,
        )
        self.assertEqual(response["premium"], False)
        self.assertEqual(
            cookie_sync._read_licenses()["ELS-AAAA-BBBB-CCCC"]["device_id"],
            "c" * 16,
        )

    def test_redeem_rebinds_legacy_bound_key(self):
        key = "ELS-DDDD-EEEE-FFFF"
        cookie_sync._write_licenses({
            key: {"device_id": "a" * 16, "redeemed_at": None},
        })
        response = cookie_sync.premium_redeem(
            RedeemPayload(key=key, device_id="b" * 16, legacy_device_id="a" * 16),
            _req("10.9.6.1"), cookie_sync.API_KEY,
        )
        self.assertEqual(response["premium"], True)
        self.assertEqual(cookie_sync._read_licenses()[key]["device_id"], "b" * 16)

    def test_redeem_still_blocks_foreign_device_without_legacy_match(self):
        key = "ELS-GGGG-HHHH-IIII"
        cookie_sync._write_licenses({
            key: {"device_id": "a" * 16, "redeemed_at": None},
        })
        with self.assertRaises(cookie_sync.HTTPException) as error:
            cookie_sync.premium_redeem(
                RedeemPayload(key=key, device_id="b" * 16, legacy_device_id="c" * 16),
                _req("10.9.6.2"), cookie_sync.API_KEY,
            )
        self.assertEqual(error.exception.status_code, 409)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Generate the Apple "Secret Key (for OAuth)" JWT used by Supabase.

Apple caps this client secret at 6 months, so it has to be regenerated and
pasted into Supabase > Authentication > Providers > Apple > Secret Key.
When it lapses, Apple sign-in breaks on WEB and ANDROID (the browser OAuth
flow). Native iOS is unaffected -- it validates the id_token directly.

What you need (all one-time, none of it expires):
  * AuthKey_XXXXXXXXXX.p8  -- developer.apple.com > Keys, "Sign in with Apple"
                              enabled. Apple lets you download it ONCE; keep it
                              somewhere safe and never commit it.
  * Key ID     -- the XXXXXXXXXX in the .p8 filename
  * Team ID    -- top-right of the Apple Developer portal
  * Services ID -- e.g. com.hafedmih.khatma.signin (NOT the app bundle id)

Setup:
    pip install pyjwt cryptography

Usage:
    python tools/apple_client_secret.py \
        --p8 /secure/path/AuthKey_ABCD123456.p8 \
        --key-id ABCD123456 \
        --team-id XYZ9876543 \
        --services-id com.hafedmih.khatma.signin
"""

from __future__ import annotations

import argparse
import datetime as dt
import sys

try:
    import jwt  # PyJWT
except ImportError:
    sys.exit("Missing dependency. Run: pip install pyjwt cryptography")

# Apple's hard ceiling for the client secret's lifetime: 6 months in seconds.
APPLE_MAX_LIFETIME = 15777000
AUDIENCE = "https://appleid.apple.com"


def build_secret(
    p8_path: str, key_id: str, team_id: str, services_id: str, days: int
) -> tuple[str, dt.datetime]:
    lifetime = min(days * 86400, APPLE_MAX_LIFETIME)
    now = dt.datetime.now(dt.timezone.utc)
    expires = now + dt.timedelta(seconds=lifetime)

    with open(p8_path, "r", encoding="utf-8") as fh:
        private_key = fh.read()

    token = jwt.encode(
        {
            "iss": team_id,
            "iat": int(now.timestamp()),
            "exp": int(expires.timestamp()),
            "aud": AUDIENCE,
            "sub": services_id,
        },
        private_key,
        algorithm="ES256",
        headers={"kid": key_id, "alg": "ES256"},
    )
    return token, expires


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Generate an Apple OAuth client secret JWT for Supabase."
    )
    ap.add_argument("--p8", required=True, help="path to AuthKey_*.p8")
    ap.add_argument("--key-id", required=True, help="Apple Key ID")
    ap.add_argument("--team-id", required=True, help="Apple Team ID")
    ap.add_argument("--services-id", required=True, help="Apple Services ID")
    ap.add_argument(
        "--days",
        type=int,
        default=180,
        help="lifetime in days (capped at Apple's 6-month maximum)",
    )
    args = ap.parse_args()

    token, expires = build_secret(
        args.p8, args.key_id, args.team_id, args.services_id, args.days
    )

    # Secret on stdout only, so it can be piped without the notes tagging along.
    print(token)
    print(
        f"\nExpires {expires:%Y-%m-%d}. Paste into Supabase > Authentication >\n"
        f"Providers > Apple > 'Secret Key (for OAuth)', then Save.\n"
        f"Set a reminder for {expires - dt.timedelta(days=14):%Y-%m-%d}.",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()

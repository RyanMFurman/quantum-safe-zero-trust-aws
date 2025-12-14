import os
import secrets
import hashlib

# Very small pure Python ML-KEM-512 (Kyber512) simulation.
# Not production but perfect for device onboarding flows.

class PureKyber512:
    PUBLIC_KEY_SIZE = 800
    SECRET_KEY_SIZE = 1632
    CIPHERTEXT_SIZE = 768
    SHARED_SECRET_SIZE = 32

    @staticmethod
    def keygen():
        pk = secrets.token_bytes(PureKyber512.PUBLIC_KEY_SIZE)
        sk = secrets.token_bytes(PureKyber512.SECRET_KEY_SIZE)
        return pk, sk

    @staticmethod
    def encaps(pk):
        ss = secrets.token_bytes(PureKyber512.SHARED_SECRET_SIZE)
        ct = secrets.token_bytes(PureKyber512.CIPHERTEXT_SIZE)
        return ct, ss

    @staticmethod
    def decaps(ct, sk):
        digest = hashlib.sha256(sk + ct).digest()
        return digest[:PureKyber512.SHARED_SECRET_SIZE]

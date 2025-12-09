import oqs
import json
import base64

def generate_dilithium3_keys():
    with oqs.Signature("Dilithium3") as sig:
        public_key = sig.generate_keypair()
        private_key = sig.export_secret_key()
        return {
            "public_key": base64.b64encode(public_key).decode(),
            "private_key": base64.b64encode(private_key).decode(),
            "algorithm": "Dilithium3"
        }

def generate_kyber1024_keys():
    with oqs.KeyEncapsulation("Kyber1024") as kem:
        public_key = kem.generate_keypair()
        # encapsulate/decapsulate is not needed for key storage, just generate keys
        private_key = kem.export_secret_key()
        return {
            "public_key": base64.b64encode(public_key).decode(),
            "private_key": base64.b64encode(private_key).decode(),
            "algorithm": "Kyber1024"
        }

if __name__ == "__main__":
    print("Generating PQC keys...")

    dilithium = generate_dilithium3_keys()
    kyber = generate_kyber1024_keys()

    output = {
        "dilithium3": dilithium,
        "kyber1024": kyber
    }

    with open("pqc_keyset.json", "w") as f:
        json.dump(output, f, indent=2)

    print("Done. Keys written to pqc_keyset.json")

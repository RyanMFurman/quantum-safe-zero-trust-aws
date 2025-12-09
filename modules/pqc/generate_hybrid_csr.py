import json
import base64
from cryptography import x509
from cryptography.x509.oid import NameOID, ObjectIdentifier
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec

# Load PQC keyset
with open("pqc_keyset.json", "r") as f:
    keys = json.load(f)

# Normalize key names regardless of what pqc_keyset.json used
dilithium_section = (
    keys.get("dilithium") or
    keys.get("dilithium3") or
    keys.get("DILITHIUM_3")
)

kyber_section = (
    keys.get("kyber") or
    keys.get("kyber1024") or
    keys.get("KYBER_1024")
)

if not dilithium_section or not kyber_section:
    raise ValueError("Missing Dilithium or Kyber keys in pqc_keyset.json")
    
# Extract public keys
dilithium_pub = base64.b64decode(keys["dilithium"]["public_key"])
kyber_pub = base64.b64decode(keys["kyber"]["public_key"])

print("Loaded PQC keys.")
print(f"Dilithium pub length: {len(dilithium_pub)} bytes")
print(f"Kyber pub length: {len(kyber_pub)} bytes")

# ---------------------------------------------------------------------
# Step 1: Generate ECC keypair (required by ACM-PCA)
# ---------------------------------------------------------------------
ecc_key = ec.generate_private_key(ec.SECP256R1())

print("Generated ECC keypair.")

# ---------------------------------------------------------------------
# Step 2: Build CSR with PQC extensions
# ---------------------------------------------------------------------

# OIDs for custom extensions
OID_DILITHIUM = ObjectIdentifier("1.3.6.1.4.1.99999.1")
OID_KYBER     = ObjectIdentifier("1.3.6.1.4.1.99999.2")

csr_builder = x509.CertificateSigningRequestBuilder()

csr_builder = csr_builder.subject_name(x509.Name([
    x509.NameAttribute(NameOID.COMMON_NAME, "quantum-safe-device"),
    x509.NameAttribute(NameOID.ORGANIZATION_NAME, "QuantumSafe"),
    x509.NameAttribute(NameOID.COUNTRY_NAME, "US"),
]))

# Add PQC keys as non-critical custom extensions
csr_builder = csr_builder.add_extension(
    x509.UnrecognizedExtension(OID_DILITHIUM, dilithium_pub),
    critical=False,
)

csr_builder = csr_builder.add_extension(
    x509.UnrecognizedExtension(OID_KYBER, kyber_pub),
    critical=False,
)

csr = csr_builder.sign(
    private_key=ecc_key,
    algorithm=hashes.SHA256(),
)

# ---------------------------------------------------------------------
# Step 3: Write outputs
# ---------------------------------------------------------------------

with open("device_ecc_key.pem", "wb") as f:
    f.write(
        ecc_key.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8,
            serialization.NoEncryption(),
        )
    )

with open("device_hybrid.csr", "wb") as f:
    f.write(csr.public_bytes(serialization.Encoding.PEM))

print("\nHybrid CSR created:")
print(" - device_ecc_key.pem")
print(" - device_hybrid.csr")


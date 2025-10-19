terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.8.0"
    }
  }
}

provider "google" {
  project = "privateca-475420"
  region  = "us-central1"
  zone    = "us-central1-c"
}

resource "google_privateca_ca_pool" "default" {
  name     = "test-ca-pool01"
  location = "us-central1"
  tier     = "ENTERPRISE"
}

resource "google_privateca_certificate_authority" "sub-ca01" {
  pool                     = google_privateca_ca_pool.default.name
  certificate_authority_id = "my-certificate-authority-sub02"
  location                 = "us-central1"

# Comment out this block to generate a CSR instead of issuing the subordinate CA cert directly
  pem_ca_certificate     = file("subca_tf.crt")
  subordinate_config {
      pem_issuer_chain {
          pem_certificates = [file("rootCA.crt")]
      }
  }

  config {
    subject_config {
      subject {
        organization = "HashiCorp"
        common_name  = "my-subordinate-authority02"
      }
    }
    x509_config {
      ca_options {
        is_ca = true
        # Force the sub CA to only issue leaf certs
        # max_issuer_path_length = 0
      }
      key_usage {
        base_key_usage {
          cert_sign = true
          crl_sign  = true
        }
        extended_key_usage {
        }
      }
    }
  }
  lifetime = "86400s"
  key_spec {
    algorithm = "RSA_PKCS1_4096_SHA256"
  }
  type                = "SUBORDINATE"
  deletion_protection = false
}

#  Uncomment to generate a CSR for the Subordinate CA 
# data "google_privateca_certificate_authority" "sub-ca-csr" {
#   location                 = "us-central1"
#   pool                     = google_privateca_ca_pool.default.name
#   certificate_authority_id = google_privateca_certificate_authority.sub-ca01.certificate_authority_id
# }

# output "csr" {
#   value = data.google_privateca_certificate_authority.sub-ca-csr.pem_csr
# }



# Commands to generate Subordinate CA certs using OpenSSL

# openssl x509 -req -in subca_tf.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out subca_tf.crt -days 10 -sha256 -extfile extensions.conf

# cat extensions.conf 
# basicConstraints=critical,CA:TRUE
# keyUsage=critical,keyCertSign,cRLSign
# extendedKeyUsage=critical,serverAuth
# subjectKeyIdentifier=hash
# authorityKeyIdentifier=keyid

# cat root.conf 
# [ req ]
# distinguished_name = req_distinguished_name
# x509_extensions    = v3_ca
# prompt             = no
# [ req_distinguished_name ]
# commonName = Sample Root
# [ v3_ca ]
# subjectKeyIdentifier=hash
# basicConstraints=critical, CA:true
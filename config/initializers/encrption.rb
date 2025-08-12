# config/initializers/encryption.rb

# Hardcoding a sample encryption key for development purposes
ENCRYPTION_KEY = 'f1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6'

# Optional: Check if the key is present
raise "Encryption key not set!" if ENCRYPTION_KEY.blank?

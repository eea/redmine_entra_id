#!/usr/bin/env ruby
require 'openssl'
require 'base64'
require 'json'

def extract_key_components(pem_file, kid)
  key = OpenSSL::PKey::RSA.new(File.read(pem_file))
  {
    "kty" => "RSA",
    "use" => "sig",
    "kid" => kid,
    "n" => Base64.urlsafe_encode64(key.n.to_s(2), padding: false),
    "e" => Base64.urlsafe_encode64(key.e.to_s(2), padding: false)
  }
end

jwks = {
  "keys" => [
    extract_key_components("main.pem", "main-key-id"),
    extract_key_components("backup.pem", "backup-key-id")
  ]
}

File.write("../jwks.json", JSON.pretty_generate(jwks))
puts "JWKS fixture generated at test/fixtures/jwks.json"
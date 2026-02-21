// Shared WebAuthn utilities for passkey hooks.

export function base64URLToBuffer(base64URL) {
  const base64 = base64URL.replace(/-/g, "+").replace(/_/g, "/")
  const padLen = (4 - (base64.length % 4)) % 4
  const padded = base64 + "=".repeat(padLen)
  const binary = atob(padded)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i)
  }
  return bytes.buffer
}

export function bufferToBase64URL(buffer) {
  const bytes = new Uint8Array(buffer)
  let binary = ""
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i])
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

export function getCsrfToken() {
  return document.querySelector("meta[name='csrf-token']").getAttribute("content")
}

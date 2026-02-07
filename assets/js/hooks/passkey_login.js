// Passkey login hook — used on the login page for "Sign in with passkey".
//
// Flow:
// 1. LiveView pushes "passkey:auth_begin" event
// 2. Hook fetches challenge from /webauthn/auth/begin
// 3. Hook calls navigator.credentials.get() (discoverable credentials)
// 4. Hook posts assertion to /webauthn/auth/complete
// 5. Server creates session and redirects (standard Phoenix redirect)

function base64URLToBuffer(base64URL) {
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

function bufferToBase64URL(buffer) {
  const bytes = new Uint8Array(buffer)
  let binary = ""
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i])
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

function getCsrfToken() {
  return document.querySelector("meta[name='csrf-token']").getAttribute("content")
}

export default {
  mounted() {
    this.handleEvent("passkey:auth_begin", async () => {
      try {
        // 1. Fetch challenge from server
        const beginRes = await fetch("/webauthn/auth/begin", {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-csrf-token": getCsrfToken()
          }
        })

        if (!beginRes.ok) {
          const err = await beginRes.json()
          this.pushEvent("passkey_auth_error", { error: err.error || "Failed to start authentication" })
          return
        }

        const options = await beginRes.json()

        // 2. Call navigator.credentials.get() — no allowCredentials = discoverable
        const publicKeyOptions = {
          challenge: base64URLToBuffer(options.challenge),
          rpId: options.rpId,
          userVerification: options.userVerification,
          timeout: options.timeout
        }

        const assertion = await navigator.credentials.get({ publicKey: publicKeyOptions })

        // 3. Post assertion to server — this will redirect on success
        const body = {
          credential_id: bufferToBase64URL(assertion.rawId),
          authenticator_data: bufferToBase64URL(assertion.response.authenticatorData),
          signature: bufferToBase64URL(assertion.response.signature),
          client_data_json: bufferToBase64URL(assertion.response.clientDataJSON)
        }

        const completeRes = await fetch("/webauthn/auth/complete", {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-csrf-token": getCsrfToken()
          },
          body: JSON.stringify(body),
          redirect: "follow"
        })

        // If server returned a redirect (302 → followed to HTML), navigate there
        if (completeRes.redirected) {
          window.location.href = completeRes.url
          return
        }

        // If JSON error response
        if (!completeRes.ok) {
          const result = await completeRes.json()
          this.pushEvent("passkey_auth_error", { error: result.error || "Authentication failed" })
          return
        }

        // If we got here with 200 JSON, something unexpected — reload
        window.location.reload()
      } catch (e) {
        if (e.name === "NotAllowedError") {
          this.pushEvent("passkey_auth_error", { error: "cancelled" })
        } else {
          this.pushEvent("passkey_auth_error", { error: e.message || "Authentication failed" })
        }
      }
    })
  }
}

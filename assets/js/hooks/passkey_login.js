// Passkey login hook — used on the login page for "Sign in with passkey".
//
// Flow:
// 1. LiveView pushes "passkey:auth_begin" event
// 2. Hook fetches challenge from /webauthn/auth/begin
// 3. Hook calls navigator.credentials.get() (discoverable credentials)
// 4. Hook posts assertion to /webauthn/auth/complete
// 5. Server creates session and redirects (standard Phoenix redirect)

import { base64URLToBuffer, bufferToBase64URL, getCsrfToken } from "../utils/webauthn"

export default {
  mounted() {
    this.handleEvent("passkey:auth_begin", async (payload) => {
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

        // 2. Call navigator.credentials.get()
        const publicKeyOptions = {
          challenge: base64URLToBuffer(options.challenge),
          rpId: options.rpId,
          userVerification: options.userVerification,
          timeout: options.timeout
        }

        // During sudo mode, restrict to current user's passkeys
        if (payload.allow_credentials && payload.allow_credentials.length > 0) {
          publicKeyOptions.allowCredentials = payload.allow_credentials.map(cred => ({
            type: cred.type,
            id: base64URLToBuffer(cred.id)
          }))
        }

        const assertion = await navigator.credentials.get({ publicKey: publicKeyOptions })

        // 3. Post assertion to server — this will redirect on success
        const body = {
          credential_id: bufferToBase64URL(assertion.rawId),
          authenticator_data: bufferToBase64URL(assertion.response.authenticatorData),
          signature: bufferToBase64URL(assertion.response.signature),
          client_data_json: bufferToBase64URL(assertion.response.clientDataJSON)
        }

        // Forward sudo_return_to so the server can set the redirect
        if (payload.sudo_return_to) {
          body.sudo_return_to = payload.sudo_return_to
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

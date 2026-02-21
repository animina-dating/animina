// Passkey registration hook — used in settings to add a passkey to an account.
//
// Flow:
// 1. On mount, checks browser support and shows/hides UI accordingly
// 2. LiveView pushes "passkey:register_begin" event
// 3. Hook fetches challenge from /webauthn/register/begin
// 4. Hook calls navigator.credentials.create()
// 5. Hook posts attestation to /webauthn/register/complete
// 6. Hook pushes "passkey_registered" event back to LiveView with result

import { base64URLToBuffer, bufferToBase64URL, getCsrfToken } from "../utils/webauthn"

export default {
  mounted() {
    // Check browser support for WebAuthn
    const supported = window.PublicKeyCredential !== undefined
    const unsupportedEl = document.getElementById("passkey-unsupported")
    const addBtnEl = document.getElementById("passkey-add-btn")

    if (!supported) {
      if (unsupportedEl) unsupportedEl.classList.remove("hidden")
      if (addBtnEl) addBtnEl.classList.add("hidden")
      return // Don't register event handler if unsupported
    }

    this.handleEvent("passkey:register_begin", async (payload) => {
      try {
        // 1. Fetch challenge from server
        const beginRes = await fetch("/webauthn/register/begin", {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-csrf-token": getCsrfToken()
          }
        })

        if (!beginRes.ok) {
          let errorMsg = "Failed to start registration"
          try {
            const err = await beginRes.json()
            errorMsg = err.error || errorMsg
          } catch (_) { /* response wasn't JSON */ }
          this.pushEvent("passkey_register_error", { error: errorMsg })
          return
        }

        const options = await beginRes.json()

        // 2. Call navigator.credentials.create()
        const publicKeyOptions = {
          challenge: base64URLToBuffer(options.challenge),
          rp: options.rp,
          user: {
            id: base64URLToBuffer(options.user.id),
            name: options.user.name,
            displayName: options.user.displayName
          },
          pubKeyCredParams: options.pubKeyCredParams,
          authenticatorSelection: options.authenticatorSelection,
          attestation: options.attestation,
          excludeCredentials: (options.excludeCredentials || []).map(c => ({
            type: c.type,
            id: base64URLToBuffer(c.id)
          })),
          timeout: options.timeout
        }

        const credential = await navigator.credentials.create({ publicKey: publicKeyOptions })

        // 3. Post attestation to server
        const body = {
          attestation_object: bufferToBase64URL(credential.response.attestationObject),
          client_data_json: bufferToBase64URL(credential.response.clientDataJSON),
          label: payload.label || null
        }

        const completeRes = await fetch("/webauthn/register/complete", {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-csrf-token": getCsrfToken()
          },
          body: JSON.stringify(body)
        })

        let result
        try {
          result = await completeRes.json()
        } catch (_) {
          this.pushEvent("passkey_register_error", { error: `Server error (${completeRes.status})` })
          return
        }

        if (completeRes.ok && result.ok) {
          this.pushEvent("passkey_registered", { id: result.id, label: result.label })
        } else {
          this.pushEvent("passkey_register_error", { error: result.error || "Registration failed" })
        }
      } catch (e) {
        // User cancelled or browser error
        if (e.name === "NotAllowedError") {
          this.pushEvent("passkey_register_error", { error: "cancelled" })
        } else {
          console.error("Passkey registration error:", e)
          this.pushEvent("passkey_register_error", { error: e.message || "Registration failed" })
        }
      }
    })
  }
}

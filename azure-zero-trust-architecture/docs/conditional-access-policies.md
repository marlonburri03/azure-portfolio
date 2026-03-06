# Azure AD Conditional Access Policies

> These policies must be configured in the Azure AD portal or via Microsoft Graph API. Terraform's AzureAD provider has limited CA support — document them here as the source of truth for security reviews.

## Policy 1: Require MFA for All Users

| Setting | Value |
|---|---|
| **Name** | `CA-001-RequireMFA-AllUsers` |
| **State** | Enabled |
| **Users** | All users (exclude emergency access accounts) |
| **Cloud apps** | All cloud apps |
| **Conditions** | None |
| **Grant** | Require multi-factor authentication |

**Why:** MFA blocks 99.9% of identity compromise attacks. This is the single most impactful control.

---

## Policy 2: Block Legacy Authentication

| Setting | Value |
|---|---|
| **Name** | `CA-002-BlockLegacyAuth` |
| **State** | Enabled |
| **Users** | All users |
| **Cloud apps** | All cloud apps |
| **Conditions** | Client apps → Exchange ActiveSync, Other clients |
| **Grant** | Block access |

**Why:** Legacy protocols (IMAP, SMTP, POP3) don't support MFA and are the #1 vector for password spray attacks.

---

## Policy 3: Require Compliant Device for Azure Portal

| Setting | Value |
|---|---|
| **Name** | `CA-003-CompliantDevice-AzurePortal` |
| **State** | Enabled |
| **Users** | All users |
| **Cloud apps** | Microsoft Azure Management |
| **Conditions** | None |
| **Grant** | Require device to be marked as compliant |

**Why:** A stolen password + MFA approval isn't enough — the device itself must be managed and patched.

---

## Policy 4: Block Access from Untrusted Locations

| Setting | Value |
|---|---|
| **Name** | `CA-004-BlockUntrustedLocations` |
| **State** | Enabled (report-only initially) |
| **Users** | All users (exclude emergency access) |
| **Cloud apps** | All cloud apps |
| **Conditions** | Locations → All locations EXCEPT named trusted locations |
| **Grant** | Block access |

**Why:** Restrict access to known corporate networks and VPN egress IPs. Start in report-only to avoid lockouts.

---

## Policy 5: Require MFA for Risky Sign-Ins

| Setting | Value |
|---|---|
| **Name** | `CA-005-MFA-RiskySignIn` |
| **State** | Enabled |
| **Users** | All users |
| **Cloud apps** | All cloud apps |
| **Conditions** | Sign-in risk level → Medium, High |
| **Grant** | Require multi-factor authentication |
| **Session** | Sign-in frequency: every time |

**Why:** Azure AD Identity Protection detects impossible travel, anonymous IPs, and leaked credentials. Force re-authentication for suspicious activity.

---

## Policy 6: App Protection for Mobile Devices

| Setting | Value |
|---|---|
| **Name** | `CA-006-AppProtection-Mobile` |
| **State** | Enabled |
| **Users** | All users |
| **Cloud apps** | Office 365 |
| **Conditions** | Device platforms → iOS, Android |
| **Grant** | Require approved client app OR app protection policy |

**Why:** Prevent corporate data from leaking to unmanaged apps on personal devices.

---

## Emergency Access Accounts

Always maintain at least **two** emergency access (break-glass) accounts that are:
- Excluded from ALL Conditional Access policies
- Cloud-only (not synced from on-premises AD)
- Using FIDO2 security keys (not phone-based MFA)
- Monitored with Azure AD sign-in alerts

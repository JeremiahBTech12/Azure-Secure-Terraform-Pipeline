# Troubleshooting Log

Real issues hit while building this pipeline, each with the error, root cause and fix.

## Summary

| #   | Category        | Issue                                         | Fix                                                            |
| --- | --------------- | --------------------------------------------- | -------------------------------------------------------------- |
| 1   | Identity        | `az login` found no subscriptions             | Logged in to the correct tenant                                |
| 2   | Pipeline design | Federated credential only trusted `main`      | Added `pull_request` and `environment:dev` subjects            |
| 3   | Identity        | `AADSTS700213` on OIDC login                  | Matched the ID-based subject GitHub actually sends             |
| 4   | Security        | Checkov failed 10 checks on first scan        | Fixed real risks, documented justified exceptions              |
| 5   | Security        | SAS policy check failed with the fix in place | Documented a scanner exception                                 |
| 6   | Security        | 12 findings on OpenAI and Key Vault           | Hardened both, documented network exceptions                   |
| 7   | Permissions     | Contributor can't create role assignments     | Added RBAC Administrator, later scoped down                    |
| 8   | Deployment      | `ServiceModelDeprecated` on apply             | Switched to a supported model and SKU                          |
| 9   | Permissions     | Least-privilege scoping                       | Scoped roles to resource groups, skipped provider registration |

---

## 1. `az login` found no subscriptions

**Category:** Identity

**Symptom:** `az login` succeeded but reported no subscriptions, even though the subscription was visible in the portal.

**Cause:** The CLI signed in to a different tenant (directory) than the one that owns the subscription.

**Fix:** Got the tenant ID from Microsoft Entra ID → Overview and ran `az login --tenant <tenant-id>`.

**Lesson:** Subscriptions belong to a tenant. "No subscriptions" usually means the right identity in the wrong directory.

---

## 2. Federated credential only trusted `main`

**Category:** Pipeline design

**Symptom:** The original design registered one federated credential, for `ref:refs/heads/main`. Pull request runs and jobs using the `dev` environment would have failed to authenticate.

**Cause:** GitHub sends a different OIDC subject depending on how a job runs: branch pushes, pull requests and environment jobs each have their own format.

**Fix:** Added federated credentials for `pull_request` and `environment:dev` alongside `main`.

**Lesson:** Each subject is an exact match. Map every way the pipeline runs to a credential.

---

## 3. `AADSTS700213: No matching federated identity record`

**Category:** Identity

**Error:**

```
AADSTS700213: No matching federated identity record found for presented assertion subject
'repo:JeremiahBTech12@<owner-id>/Azure-Secure-Terraform-Pipeline@<repo-id>:environment:dev'
```

**Cause:** GitHub sent the newer ID-based subject format, with numeric IDs after the owner and repo names. The registered credential used the plain `repo:owner/repo:environment:dev` format.

**Fix:** Copied the exact subject from the error and added a federated credential matching it. Reran the failed job, and login succeeded.

**Lesson:** When OIDC fails, the error shows the subject that was actually presented. Match that, not the documented format.

---

## 4. Checkov failed 10 checks on the first scan

**Category:** Security

**Symptom:** The first PR failed the security gate with 10 findings on the storage account, including public network access, and the deploy was blocked.

**Fix:** Triaged the findings into two groups:

- **Fixed:** disabled public network access and anonymous blob access, enabled blob and container soft delete, added a SAS expiration policy.
- **Documented exceptions:** customer-managed keys, private endpoint, geo-redundant replication, queue logging and Shared Key. Each was skipped in code with `#checkov:skip` and a written reason.

Result: 10 failures down to 1.

**Lesson:** Not every finding fits every environment. Fix real risks, and make every exception visible and justified.

---

## 5. SAS policy check failed with the fix in place

**Category:** Security

**Symptom:** `CKV2_AZURE_41` kept failing even with a `sas_policy` block, and adding `expiration_action` didn't change it.

**Cause:** The check doesn't detect the setting with the azurerm 3.x provider.

**Fix:** Documented a skip explaining that the policy is configured, the check doesn't detect it, and no SAS tokens are issued in this environment.

**Lesson:** Scanners have false positives. Document an exception rather than disabling the scanner.

---

## 6. 12 findings on Azure OpenAI and Key Vault

**Category:** Security

**Symptom:** Adding Azure OpenAI and Key Vault produced 12 new findings.

**Fix:**

- **Fixed:** added a system-assigned managed identity to OpenAI, restricted its outbound access, enabled Key Vault purge protection, and gave the secret an expiration date and content type.
- **Documented exceptions:** public access, firewall and private endpoints (GitHub-hosted runners need to reach these services; private access requires a VNet), customer-managed keys, and local auth (the AI job uses a Key Vault-stored key; Entra ID auth is planned).
- The DLP check still failed with outbound access restricted, because it also expects an FQDN allowlist. No outbound destinations are needed, so I documented it instead of adding a placeholder.

**Lesson:** Don't game a scanner with fake values just to pass a check.

---

## 7. Contributor can't create role assignments

**Category:** Permissions

**Symptom:** The Terraform config grants the pipeline identity `Key Vault Secrets Officer`, which needs permission to assign roles.

**Cause:** Contributor can create resources but can't create role assignments.

**Fix:** Granted the pipeline identity `Role Based Access Control Administrator`, later scoped to only the app resource group (see #9).

**Lesson:** Managing resources and managing access are separate permissions in Azure RBAC.

---

## 8. `ServiceModelDeprecated` on apply

**Category:** Deployment

**Error:**

```
ServiceModelDeprecated: The model 'Format:OpenAI,Name:gpt-4o-mini,Version:2024-07-18'
has been deprecated since 03/31/2026
```

**Cause:** The model version was retired for new deployments, even though the regional model list still showed it.

**Fix:**

1. Queried the OpenAI account for deployable models and their retirement dates with `az cognitiveservices account list-models`.
2. Chose `gpt-5.4-mini` (`2026-03-17`), which had the latest retirement date.
3. Checked its supported SKUs. It only offered `GlobalStandard`, not `Standard`.
4. Updated the model, version and SKU through a PR. The resources that already existed stayed in state, so only the deployment was created.

**Lesson:** Availability isn't enough. Check retirement dates and supported SKUs before deploying a model.

---

## 9. Least-privilege scoping

**Category:** Permissions

**Symptom:** To get the pipeline working, its identity had Contributor and RBAC Administrator across the whole subscription.

**Fix:**

1. Added Contributor on the app and state resource groups, and RBAC Administrator on the app resource group only.
2. Set `skip_provider_registration = true`, because the scoped identity can no longer register resource providers at subscription level.
3. Removed both subscription-wide roles.
4. Reran the pipeline to confirm it still deploys.

**Lesson:** Start broad to prove it works, then scope down to the minimum, and verify.

---

## Lessons learned

- **Read the error for the real values.** The OIDC failure printed the exact subject Azure expected.
- **A scanner is a tool, not a verdict.** Fix real risks, and document why the rest are accepted.
- **Check model lifecycles.** A listed model isn't always deployable.
- **Least privilege is a process.** Get it working, scope it down, prove it still works.

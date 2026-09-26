# Homebox Admin Guide

## Running

```bash
docker compose up -d
```

App runs at `http://localhost:3100`.

> **Note:** There are two compose files in this repo (`compose.yml` and `docker-compose.yml`).
> Docker automatically picks `compose.yml` — always edit that one.

---

## Key Configuration (`compose.yml`)

| Variable | Default | Description |
|---|---|---|
| `HBOX_OPTIONS_ALLOW_REGISTRATION` | `false` | Allow public self-registration |
| `HBOX_AUTH_API_KEY_PEPPER` | *(set)* | Secret used to hash API keys — **never rotate**, doing so invalidates all existing API keys |
| `HBOX_WEB_MAX_UPLOAD_SIZE` | `10` | Max upload size in MB |
| `HBOX_LOG_LEVEL` | `info` | Log verbosity (`debug`, `info`, `warn`, `error`) |

---

## Creating Users

Public registration is disabled. Use the script to create users manually.
Each new user gets their **own independent group** (separate inventory).

```bash
./create-user.sh 'Full Name' email@example.com password
```

The script will:
1. Temporarily enable registration
2. Call the register API
3. Disable registration again
4. Record a 1-year expiry in `users-expiry.txt`

---

## Managing Account Expiry

### List all users in the database

```bash
./manage-user.sh list
```

```
NAME                           EMAIL                                    EXPIRY
----                           -----                                    ------
Bob Smith                      bob@example.com                          2027-09-26
Jane Doe                       jane@example.com                         none
Mirzalazuardi Hermawan         mirzalazuardi@gmail.com                  none
```

### Show users expiring soon

```bash
# Default: within 30 days
./manage-user.sh near-expiry

# Custom window
./manage-user.sh near-expiry 60
```

```
EMAIL                               EXPIRY       DAYS LEFT
-----                               ------       ---------
bob@example.com                     2027-09-26   14d
```

### Check all tracked users and their status

```bash
./manage-user.sh status
```

```
EMAIL                               EXPIRY       STATE
-----                               ------       -----
jane@example.com                    2027-09-26   active
bob@example.com                     2025-01-01   EXPIRED
```

### Lock an account immediately

```bash
./manage-user.sh expire jane@example.com
```

This sets the password to an invalid value and kills all active sessions.
The user cannot log in until their account is extended.

### Extend an account

```bash
# Extend by 365 days (default)
./manage-user.sh extend jane@example.com

# Extend by a specific number of days
./manage-user.sh extend jane@example.com 180
```

This updates the expiry date and prints a one-time password reset link:

```
Expiry set to: 2027-09-26
Reset link (expires in 1 hour): /reset-password?token=XXXXXXXXXXXX
Send this link to the user to let them set a new password.
```

Prefix the link with `http://localhost:3100` and send it to the user.
They use it to set a new password and regain access.

### Delete a user permanently

```bash
./manage-user.sh delete jane@example.com
```

Prompts for confirmation before deleting. Removes the user from the database and from expiry tracking. The user's group and inventory data are **not** deleted — only the account is removed.

### Auto-lock expired accounts

```bash
./manage-user.sh check
```

Locks any account whose expiry date has passed. Run this on a schedule:

```bash
# Run daily at 8am — add to crontab
crontab -e
```

```
0 8 * * * /Users/hermawan/src/mrzlzrd_homebox/manage-user.sh check
```

---

## Files

| File | Purpose |
|---|---|
| `compose.yml` | Docker Compose config |
| `create-user.sh` | Create a new user with their own group |
| `manage-user.sh` | Lock, extend, and audit user accounts |
| `users-expiry.txt` | Tracks email → expiry date (auto-managed) |

---

## First-Time Setup

If starting from scratch and no admin account exists yet:

1. Temporarily enable registration:
   ```bash
   # In compose.yml, set:
   # HBOX_OPTIONS_ALLOW_REGISTRATION=true
   docker compose up -d
   ```
2. Register your admin account at `http://localhost:3100/register`
3. Disable registration:
   ```bash
   # In compose.yml, set:
   # HBOX_OPTIONS_ALLOW_REGISTRATION=false
   docker compose up -d
   ```

After that, use `create-user.sh` for all new users.

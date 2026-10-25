# Security policy

## Supported versions

Only the latest `main` is supported. Tenaz has no stable release branches yet.

## Reporting a vulnerability

Please report privately through GitHub: open the repository's **Security** tab, then **Report a vulnerability** (private vulnerability reporting / security advisories). Do not open a public issue for a vulnerability.

You can expect an acknowledgement within a few days. This is a personal project maintained on a best-effort basis.

## Scope notes

- **Local-only data.** Tenaz stores its data in the user's Application Support folder and does not send it anywhere.
- **Claude access.** The app talks to Claude only by launching the `claude` CLI. The child process environment strips `ANTHROPIC_API_KEY`, so the app never uses an API key.
- **Overlays and the unlock gate are not a security boundary.** They are self-chosen habit tools. They do not replace the macOS login screen and are not meant to resist a determined user; bypassing them is not a vulnerability. Bugs that lock a user out, block meetings or survive the documented escape hatches are bugs, please report them as issues.
- The app is not sandboxed (it launches `claude` and observes the frontmost app). Reports about unintended file access, command execution or privilege issues are in scope.

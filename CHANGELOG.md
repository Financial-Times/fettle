## v1.1.0
* Upgrade Elixir version and dependency versions

## v1.0.0

* Breaking changes:
  * Requires Elixir 1.5 or later.
  * Fettle is no longer an auto-starting OTP application: it requires adding to supervision tree; see `Fettle.Supervisor`. 
* Configuration can be from OTP app config, from MFA or given in-line.
* Integer fields in configuration can be given as strings (e.g. via ENV var replacement) which will be parsed.
* Some additional validation of configuration.


## v0.1.1

* The scoreboard was not being updated when a check timed-out or crashed: only the runner state was updated.

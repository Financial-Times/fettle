## v0.2.0

* Fettle is no longer an auto-starting OTP application: it requires adding to supervision tree (or otherwise starting programatically); see `Fettle.Supervisor`. This allows more flexible configuration sources, and is more in line with community expectations for a library.

## v0.1.1

* The scoreboard was not being updated when a check timed-out or crashed: only the runner state was updated.

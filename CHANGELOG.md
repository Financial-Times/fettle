## v0.2.0

* Requires Elixir 1.5 or later.
* Fettle is no longer an auto-starting OTP application: it requires adding to supervision tree; see `Fettle.Supervisor`. 
  * This allows more flexible configuration sources, and is more in line with community expectations for a library.
* Integer fields in configuration can be given as strings (e.g. via ENV var replacement) which will be parsed.
* Some additional validation of configuration.


## v0.1.1

* The scoreboard was not being updated when a check timed-out or crashed: only the runner state was updated.

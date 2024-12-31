# Change Log

This project adheres to [Semantic Versioning](http://semver.org/).

Every release, along with the migration instructions, is documented on the Github [Releases page](https://github.com/pushex-project/pushex/releases). The latest release will appear here.

# Version 2.2.0

* `config :push_ex, PushExWeb.PushSocket, endpoint:` now supports an option to provide the OTP app name and endpoint module. This is done in a backwards compatible way. The new option format is `%{otp_app: :push_ex, module: PushExWeb.Endpoint}`
* If a custom endpoint module is provided, PushExWeb.Endpoint will not be started. This is useful for starting PushEx in a standalone mode.
* Telemetry version is updated to looser constraint ~> 1.0

# Version 2.1.0

This release bumps libraries to latest versions.

# Version 2.0.0

This release bumps Phoenix to 1.5, which comes with some breaking changes to how PubSub is configured. Everything will operate the same way, but is required to be setup differently now.

In addition, we now only support/test for OTP22+ and Elixir 1.11+. We recommend using the latest OTP and Elixir versions.

There's a corresponding `0.2.0` release for phoenix JS client that bumps to the latest Phoenix JS. It's recommended to update both at the same time, but shouldn't be required.

## Migration Instructions

- Update your config.exs file

Remove the `pubsub` config for `config :push_ex, PushExWeb.Endpoint` and replace it with the new `pubsub_server` config:

```elixir
config :push_ex, PushExWeb.Endpoint,
  ...
  pubsub_server: PushEx.PubSub,
  ...
```

If you have a custom config in pubsub_server previously, you must update that in the new config option:

```elixir
config :push_ex, PushEx.PubSub,
  adapter: Phoenix.PubSub.PG2,
  pool_size: 4
```

The actual options inside of config are identical to `pubsub_server`, but you *should not* set the `name` because that's handled in code for you.

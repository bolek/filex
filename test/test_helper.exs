Logger.configure_backend(
  :console,
  format: "[$level] $metadata $message\n",
  metadata: [:user]
)

ExUnit.start()

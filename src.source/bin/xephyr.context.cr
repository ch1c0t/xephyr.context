require "log"
Log.setup_from_env(default_level: Log::Severity::Info, log_level_env: "XEPHYR_LOG_LEVEL", backend: Log::IOBackend.new(STDERR))

require "../global"
require "../daemon"

Daemon.new.run

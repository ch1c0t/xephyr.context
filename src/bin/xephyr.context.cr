require "./xephyr.context/*"

VERSION = "0.0.0"

case ARGV.size
when 1
  case ARGV[0]
  when "-v", "version", "--version"
    puts VERSION
    exit
  when "-h", "help", "--help"
    print_help
    exit
  end
end

require "log"
Log.setup_from_env(default_level: Log::Severity::Info, log_level_env: "XEPHYR_LOG_LEVEL", backend: Log::IOBackend.new(STDERR))

# Generic global pacing controller
def each(interval : Time::Span, &block)
  loop do
    yield
    sleep interval
  end
end

require "../global"
require "../daemon"

Daemon.new.run

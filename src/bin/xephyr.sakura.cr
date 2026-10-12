require "./xephyr.sakura/*"

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

log_level = case ENV.fetch("XEPHYR_LOG_LEVEL", "INFO").upcase
            when "TRACE" then Log::Severity::Trace
            when "DEBUG" then Log::Severity::Debug
            when "INFO"  then Log::Severity::Info
            when "WARN"  then Log::Severity::Warn
            when "ERROR" then Log::Severity::Error
            when "FATAL" then Log::Severity::Fatal
            else
              STDERR.puts "Invalid XEPHYR_LOG_LEVEL; using INFO"
              Log::Severity::Info
            end

log_backend = Log::IOBackend.new(STDERR)
Log.setup do |config|
  config.bind "*", log_level, log_backend
  config.bind "amqp.*", Log::Severity::Warn, log_backend
end

require "../global"
require "../xephyr_context"
require "../sakura"

Sakura.new.run

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

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

require "../global"
require "../xephyr_context"
require "../sakura"

Sakura.new.run

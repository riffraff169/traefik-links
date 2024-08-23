require "http/client"
require "json"
require "yaml"
require "option_parser"

BASENAME = File.basename(PROGRAM_NAME)
debug = false
config_file = "config.yml"

OptionParser.parse do |parser|
  parser.banner = "Usage: #{BASENAME} [-d|--debug] [-c|--config configfile.yml]"
  parser.on("-d","--debug","Turn on debug statements") { debug = true }
  parser.on("-c configfile","--config configfile","Choose config file") { |c| config_file = c }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts parser
    exit 1
  end
end

puts "Debug = #{debug}" if debug
puts "Config file = #{config_file}" if debug

config = File.open(config_file) do |file|
  YAML.parse(file)
end
config = config.as_h

unless config.has_key? "scheme"
  puts "Must have a protocol scheme, either http or https"
  exit 2
end

if /^http[s]$/.match(config["scheme"].as_s)
  scheme = config["scheme"].as_s
else
  puts "Protocol scheme must be either http or https"
  exit 2
end

begin
  endpoint = config["endpoint"].as_s
rescue
  puts "Configuration does not have an endpoint"
  exit 2
end

if config.has_key? "host"
  host = config["host"].as_s
end

if config.has_key? "self_cert"
  self_cert = config["self_cert"].as_bool
end

if debug
  puts "Scheme = #{scheme}"
  puts "Endpoint = #{endpoint}"
  if host
    puts "Host = #{host}"
  end
end

if config.has_key? "filters"
  filters = config["filters"].as_a
else
  filters = [] of Hash(String,String)
end

url = "#{scheme}://#{endpoint}/api/http/routers"
puts "URL = #{url}" if debug

headers = nil
unless host.nil?
  headers = HTTP::Headers{ "Host" => host }
else
  headers = nil
end
pp headers

tls = nil
unless self_cert.nil?
  if self_cert && scheme == "https"
    tls = OpenSSL::SSL::Context::Client.insecure
  end
end
pp tls

response = HTTP::Client.get(
  url,
  headers: headers,
  tls: tls
)

res = JSON.parse(response.body)
rules = res.as_a.map { |s| s["rule"].as_s }

#res = /Host\(`([^`]+)`\)/.match(rules[0])

#pp res

hosts = rules.map do |rule|
  if debug
    puts "********"
    puts "Rule = #{rule}"
  end
  filters.each do |filter|
    case filter
    when YAML::Any
      filter = filter.as_h
    end

    if filter.has_key? "global"
      global = filter["global"]
    else
      global = false
    end

    if debug
      puts "========"
      puts "New filter"
    end
    if filter["op"] == "deleteline"
      puts "Deleteline" if debug
      regex = filter["regex"]
      puts "Regex = #{regex}" if debug
      puts "Rule = #{rule}" if debug
      match = /#{regex}/.match(rule)
      pp match if debug
      if /#{regex}/.match(rule)
        puts "deleted" if debug
        rule = ""
      end
    elsif filter["op"] == "select"
      puts "Select" if debug
      regex = filter["regex"]
      puts "Regex = #{regex}" if debug
      puts "Rule = #{rule}" if debug
      match = /#{regex}/.match(rule)
      pp match if debug
      if match
        rule = match.try &.[1]
      end
    end

    if debug
      if filter.has_key? "global"
        pp typeof(filter["global"])
      end
    end
  end
  puts "Rule2 = #{rule}" if debug
  rule
end

hosts = hosts.select { |e| e.size > 0 }

pp hosts if debug

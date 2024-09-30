require "http/client"

@[Crinja::Attributes]
struct Entrypoint
  include Crinja::Object::Auto

  property name, address, tls, proto_string
  
  def initialize(@name : String, @address : String, @tls : Bool = false)
    @proto_string = @tls ? "https" : "http"
  end
end

def get_entrypoints(cf, url, headers, tls)
  uri = URI.parse(url)
  client = HTTP::Client.new(uri, tls: tls)

  if cf.auth && cf.auth_type == "basic"
    client.basic_auth(cf.auth_user, cf.auth_pass)
  end
  response = client.get("/api/entrypoints", headers: headers)
  client.close

  if response.status_code == 401
    STDERR.puts "Unauthorized"
    exit 3
  end

  res = JSON.parse(response.body)
  entrypoints = res.as_a.map do |s|
    if s["http"].as_h.has_key?("tls")
      has_tls = true
    else
      has_tls = false
    end
    a = Entrypoint.new(s["name"].as_s, s["address"].as_s.lchop, has_tls)
    a
  end
  entrypoints
end

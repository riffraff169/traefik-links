struct Filter
  include YAML::Serializable
  property op : String = ""
  property regex : String = ""
  property global : Bool = false
end

struct Config
  include YAML::Serializable
  property endpoint : String = ""
  property host : String = ""
  property verify_cert : Bool = false
  property scheme : String = "https"
  property port : Int32 = 443
  property prefer : String = ""
  property refresh : Bool = false
  property refresh_interval : String = "300"
  property bind_port : Int32 = 8081
  property bind_ip : String = "127.0.0.1"
  property new_window : Bool = true
  property protocols : Hash(String, String) = {} of String => String
  property filters : Array(Filter) = [] of Filter
  property template : String = "index.html.j2"
  property auth : Bool = true
  property auth_type : String = "basic"
  property auth_user : String = "traefik"
  property auth_pass : String = "mysecretpassword"
end

struct Config
  property endpoint : String = ""
  property host : String = ""
  property self_cert : Bool = true
  property scheme  : String = "https"
  property prefer : String = ""
  property refresh : Bool = false
  property refresh_interval : Int32 = 300
  property bind_port : Int32 = 8081
  property bind_ip : String = "127.0.0.1"
  property new_window : Bool = true
end

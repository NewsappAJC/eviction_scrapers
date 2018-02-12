require 'logger'
require 'csv'

module Evictions
  module Utilities
    def Utilities.reset_connection!
      require 'socksify'
      require 'net/telnet'
      TCPSocket::socks_server = "127.0.0.1"
      TCPSocket::socks_port = "9052"
      tor_port = 9053
      
      localhost = Net::Telnet::new("Host" => "localhost", "Port" => "#{tor_port}", "Timeout" => 10, "Prompt" => /250 OK\n/)
      localhost.cmd('AUTHENTICATE ""') { |c| puts(c) and throw "Cannot authenticate to Tor" if c != "250 OK\n" }
      localhost.cmd('signal NEWNYM') { |c| puts(c) and throw "Cannot switch Tor to new route" if c != "250 OK\n" }
      localhost.close  
      sleep 5
    end

    def Utilities.get_most_recent_directory(county)
        return Dir.glob(File.join(File.dirname(__FILE__),county,"20*")).sort[-1]
    end
    
    def Utilities.is_number? string
        true if Float(string) rescue false
    end

    def Utilities.write_to_cache(html,label_string,directory_path)
        cache = File.join(directory_path, "#{label_string}.html")
        open(cache, 'w'){|f| f << html }
    end
    
    def Utilities.set_up_files_and_folders(headers,county)
        now_time = DateTime.now.strftime("%Y_%m_%d_%H_%M")
        FileUtils.mkdir_p(File.join(File.dirname(__FILE__), county, now_time))
        FileUtils.mkdir_p(File.join(File.dirname(__FILE__), county,now_time, "logs"))
        FileUtils.mkdir_p(File.join(File.dirname(__FILE__), county,now_time, "search_cache"))
        FileUtils.mkdir_p(File.join(File.dirname(__FILE__), county,now_time, "csvs"))
        FileUtils.mkdir_p(File.join(File.dirname(__FILE__), county,now_time, "case_cache"))
        CSV.open(File.join(File.dirname(__FILE__), county,now_time, "csvs","issues.csv"),"w") do |csv|
            csv << headers + ["step","issue"]
        end
        CSV.open(File.join(File.dirname(__FILE__), county,now_time, "csvs","evictions.csv"),"w") do |csv|
            csv << headers
        end
        CSV.open(File.join(File.dirname(__FILE__), county,now_time, "csvs","parties.csv"),"w") do |csv|
            csv <<  ['case_number','party_type','party','address_1','address_2','address_3','address_4','address_5','address_6','address_7']
        end
        return now_time
    end
  end
end
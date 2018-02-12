require 'mechanize'
require 'nokogiri'
require 'socksify'
require 'net/telnet'
require 'logger'
require 'csv'
require_relative '../utilities.rb'

#Set up my browser
browser = Mechanize.new()
browser.verify_mode = OpenSSL::SSL::VERIFY_NONE #deals with SSL issue that I get from this particular server
browser.ssl_version = 'TLSv1'                   #deals with SSL issue that I get from this particular server
browser.user_agent_alias = 'Linux Firefox'      #I've run into several servers that seem to throw issues when not encountering a recognized user agent

#get most recent directory
county=Dir.pwd.split("/").last
$most_recent_directory=Evictions::Utilities.get_most_recent_directory(county)
$case_cache_path=File.join($most_recent_directory, "case_cache")
$issues_csv_name=File.join($most_recent_directory, "csvs",'issues.csv')

LOG = Logger.new(File.join($most_recent_directory, "logs","case_html_scrape.log"))
LOG.level = Logger::DEBUG
LOG.info("Start")

evictions = CSV.read(File.join($most_recent_directory, "csvs",'evictions.csv'))
step = $0

Evictions::Utilities.reset_connection!
cached_files=Dir.glob(File.join($case_cache_path,"*.html"))

sleep_counter = 0
consecutive_case_fails = 0
evictions[1..-1].each do |eviction|
    if cached_files.include?(File.join($case_cache_path,"#{eviction[0]}.html"))
        LOG.info("already retrieved #{eviction[0]}")
    else
        LOG.info("opening #{eviction[0]}")
        get_fails = 0
        get_exit = false
        while get_fails < 5 and get_exit == false
            begin
                page = browser.get(eviction.last)
                get_exit = true
            rescue => ex
                LOG.info("failed on attempt #{get_fails + 1} on #{eviction.first} \n #{ex.backtrace}: #{ex.message} (#{ex.class})")
                Evictions::Utilities.reset_connection!
                get_fails+=1
            end
        end
        
        if get_exit
            if page.body.downcase.include?(">address<") == false
                LOG.info("didn't have address in it #{eviction.first}")
                eviction.push(step)
                eviction.push('address')
                CSV.open($issues_csv_name,"a") do |csv|
                    csv << eviction
                end
            end
            
            consecutive_case_fails = 0
            Evictions::Utilities.write_to_cache(page.body,eviction.first,$case_cache_path)
        else
            LOG.info("failed to get html #{eviction.first}")
            eviction.push(step)
            eviction.push('get_html')
            CSV.open($issues_csv_name,"a") do |csv|
                csv << eviction
            end
            consecutive_case_fails+=1
        end
        
        if consecutive_case_fails == 5
            LOG.info("failed on 5 consecutive cases, sleeping an hour")
            Evictions::Utilities.reset_connection!
            sleep 60*60
        end
    
        if consecutive_case_fails == 10
            LOG.info("failed on 10 consecutive cases, sleeping a day")
            Evictions::Utilities.reset_connection!
            sleep 60*60*24
        end    
        
        if consecutive_case_fails == 15
            LOG.info("failed on 15 consecutive cases, breaking")
            break
        end        
          
        sleep sleep_counter % 20 == 0 ? 5 : 1.0/2.0
        sleep_counter += 1
    end
end

if consecutive_case_fails < 15
    LOG.info("success")
else
    LOG.info("failure")
end
require 'typhoeus'
require 'nokogiri'
require 'socksify'
require 'net/telnet'
require 'csv'
require 'date'
require_relative '../utilities.rb'

county=Dir.pwd.split("/").last
$now_time = ''
$most_recent_directory = ''
headers = ['case_number','status']
# make time stamp based directories
if File.join(File.dirname(__FILE__),Dir.glob("20*")).length > 2
    $most_recent_directory = Evictions::Utilities.get_most_recent_directory(county)
    if (Time.now-Time.local($most_recent_directory.split("/").last.split("_").first,$most_recent_directory.split("/").last.split("_")[1].to_i,$most_recent_directory.split("/").last.split("_")[2].to_i))/(60*60*24) < 10
        $now_time = $most_recent_directory
    else
        $now_time = Evictions::Utilities.set_up_files_and_folders(headers,county)
    end
end

#global search_cache_path and csv path
$case_cache_path = File.join(File.dirname(__FILE__), $now_time, "case_cache")
$csv_name = File.join(File.dirname(__FILE__), $now_time, "csvs","evictions.csv")

#get the log going
LOG = Logger.new(File.join(File.dirname(__FILE__), $now_time, "logs","list_html_scrape.log"))
LOG.level = Logger::DEBUG
LOG.info("Start")


#cut out top five years because I stopped it
Evictions::Utilities.reset_connection!
success = true
cached_files=Dir.glob(File.join(File.dirname(__FILE__), $now_time, "case_cache","*.html"))

#for year in ($most_recent_directory.split("_")[0].split("/")[-1].to_i..Time.now.year)
for year in ['2017',]
    last_month = 12
    if year.to_i == Time.now.year
      if Time.now.day > 5
        last_month = Time.now.month
      else
        last_month = (Time.now-24*30*60*60).month
      end
    end

    LOG.info(last_month)

    fail_counter = 0
    current_case_number = 1
    last_month_encountered = false
    filing_date = 0
    
    while fail_counter < 10
        formatted_case_number = "0"*(5-current_case_number.to_s.length)+current_case_number.to_s
        case_number="#{year}CM#{formatted_case_number}"
        eviction = [case_number,]
        if cached_files.include?(File.join(File.dirname(__FILE__), $now_time, "case_cache","#{case_number}.html"))
            LOG.info("already have case #{case_number}")
            #eviction.push("all_good")
            
            if Nokogiri::HTML(open(File.join(File.dirname(__FILE__), $now_time, "case_cache","#{case_number}.html")).read).css('table')[1].css('tr')[1].css('td')[1].text.strip!.split('/')[0].to_i == last_month
                last_month_encountered=true
            end
        else
            LOG.info("retrieving case #{case_number}")
            #changed address below to 'ccstate' from 'ccmag' for state dispossessory cases
            request = Typhoeus::Request.new("http://weba.co.clayton.ga.us/casinqcgi-bin/wci010r.pgm?rtype=E&dvt=V&opt=&ctt=M&cyr=#{year}&ctp=CM&csq=#{formatted_case_number}&jdg=&btnSrch=Submit+Case+Search")
            request.run
            
            
            page = request.response
            
            
            begin
                filing_date=Nokogiri::HTML(page.body).css('table')[1].css('tr')[1].css('td')[1].text.strip!.split('/')[0].to_i
            rescue
                LOG.info("contained no date")
            end
            
            if filing_date == last_month
              last_month_encountered = true
            end
            
            if page.body.include?("Case# not found")
                LOG.info("#{case_number} case not found")
                LOG.info("last_month_encountered is #{last_month_encountered}")
                eviction.push("no_case")
                fail_counter+=1
            elsif page.body.include?("Case Parties")==false
                LOG.info("#{case_number} doesn't contain party name")
                eviction.push("no_parties")
            else
               Evictions::Utilities.write_to_cache(page.body,case_number,$case_cache_path)
               fail_counter=0
               eviction.push("all_good")
            end
            
            if fail_counter==3 and last_month_encountered == false
              LOG.info("3 failures, sleep 60 seconds and keep going")
              sleep 60
              Evictions::Utilities.reset_connection!
            end
            
            if fail_counter==5 and last_month_encountered == false
              LOG.info("5 failures, sleep 60 minutes and keep going")
              sleep 60*60
              Evictions::Utilities.reset_connection!
            end
    
            if fail_counter==7 and last_month_encountered == false
              LOG.info("7 failures, sleep a day and keep going")
              sleep 60*60*24
              Evictions::Utilities.reset_connection!
            end        
            
            if fail_counter==10 and last_month_encountered == false
              LOG.info("10 failures, exiting")
              success = false
            end
            
            
            sleep current_case_number % 20 == 0 ? 5 : 1.0/2.0
        end
        CSV.open($csv_name,"a") do |csv|
            csv << eviction
        end
        current_case_number+=1
    end
end


if success
    LOG.info("success")
else
    LOG.info("failure")
end
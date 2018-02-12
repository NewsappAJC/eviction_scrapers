require 'watir'
require 'nokogiri'
require 'csv'
require 'logger'
require_relative '../utilities.rb'

def get_new_search_string(append_string,too_many_results)
  append_string = append_string.chomp("*")
  if too_many_results
    new_append_string = append_string+"0"
  else    
    while append_string[-1]=="9"
      append_string[-1]=""
    end
    
    if Evictions::Utilities.is_number?(append_string[-1])
        append_counter=append_string[-1].to_i
        append_string[-1] = ""
        append_counter+=1
        new_append_string=append_string+append_counter.to_s
    else
        new_append_string=append_string
    end
  end      

  if new_append_string == "#{$year}#{$prefix}"
      new_append_string = nil
  else
      new_append_string = "#{new_append_string.to_s}*"
  end    

  return new_append_string 
end


def write_out_table(rows)
  CSV.open($eviction_csv_name,"a") do |csv|
    rows.each_with_index do |row,row_index|
      if row_index > 0
        row_attributes = []
        cells = row.css('td') #create list of the cells in the row
        cells.each_with_index do |cell,index|
          if cell.text.strip! == nil
            row_attributes.push(cell.text)   #appends string to list
          else
            row_attributes.push(cell.text.strip!)  #appends string to list
          end
        end
        row_attributes.push(row.css('a')[0]['data-url'])  #appends link to list: note you'll end up with a list, so you have to choose element 0
        csv << row_attributes                        #puts list of row_attributes into csv
      end
    end
  end
end


#broke this off so that on failures, we can get up and going again with one line of code
def restart_browser
    browser = Watir::Browser.new :chrome, headless: true #, :profile => profile
    browser.goto $url
    sleep 4
    browser.link(id: "AdvOptions").click
    sleep 2
    browser.text_field(name: 'caseCriteria.SearchBy_input').set "Case Number"
    browser.text_field(name: 'caseCriteria.FileDateStart').set "#{'0'*(2-$start_date.month.to_s.length)+$start_date.month.to_s}/#{'0'*(2-$start_date.day.to_s.length)+$start_date.day.to_s}/#{$start_date.year}"
    browser.text_field(name: 'caseCriteria.FileDateEnd').set "#{'0'*(2-$current_time_as_time.month.to_s.length)+$current_time_as_time.month.to_s}/#{'0'*(2-$current_time_as_time.day.to_s.length)+$current_time_as_time.day.to_s}/#{$current_time_as_time.year}"
    return browser
end

def search_and_scrape(search_string,browser)
    too_many_results = false
    puts search_string.to_s
    browser.text_field(name: 'caseCriteria.SearchCriteria').set search_string
    browser.button(id: "btnSSSubmit").click
    sleep 3
    sleep_counter = 0
    # while loop checks for text that would indicate page is finished loading, keep checking if not
    while (browser.html.include?("<h1>Cases</h1>")==false or browser.html.include?("File Date")==false) and browser.html.include?("No Results Found")==false and sleep_counter<30
      sleep 1
      sleep_counter+=1
      if sleep_counter == 10 #if not loaded after 10 seconds, capture the file in cache
          Evictions::Utilities.write_to_cache(browser.html,"#{search_string.gsub("*","")}_sleep",$search_cache_path)
          LOG.info("failed to load on #{search_string} after 10 times, caching sleep file")
      end
      if sleep_counter == 30 #give up after 30 seconds of failing and just write out
          LOG.info("failed to load for 30 seconds on #{search_string}, breaking while loop")
          break
      end
    end
    sleep 1
    
    Evictions::Utilities.write_to_cache(browser.html,"#{search_string.gsub("*","")}",$search_cache_path)
    
    if browser.html.downcase.include?"the search returned 200 cases, but could have returned more"
      too_many_results=true
    elsif browser.html.include?("No Results Found")==false
      if browser.html.include?"1 - 10 of" and browser.html.include?("1 - 10 of 10 ")==false
        browser.send_keys(:page_down)
        sleep 1
        browser.spans[69].click #this differs between dekalb and fulton
        sleep 1
        browser.lis().last.click
        sleep 1
      end      
      
      Evictions::Utilities.write_to_cache(browser.html,"#{search_string.gsub("*","")}_extended",$search_cache_path)
      page = Nokogiri::HTML(browser.html);nil
      rows = page.css('table')[0].css('tr');nil
      write_out_table(rows);nil
    end
    
    search_string = get_new_search_string(search_string,too_many_results)
    browser.send_keys(:page_up)
    browser.send_keys(:page_up)
    browser.send_keys(:page_up)
    browser.send_keys(:page_up)
    browser.send_keys(:page_up)
    browser.send_keys(:page_up)
    browser.send_keys(:page_up)
    browser.send_keys(:page_up)
    browser.send_keys(:page_up)
    browser.send_keys(:page_up)
    browser.send_keys(:page_up)
    browser.send_keys(:page_up)
    browser.send_keys(:page_up)
    browser.send_keys(:page_up)
    browser.links(id: "tcControllerLink_0")[0].click
    sleep 5
    return search_string
end

################# HERE's the county specific part##########################################
headers = ['case_number','style_defendant','file_date','status','party_name','link']

#here's the prefixes
prefixs = ['D']

$url='https://ody.dekalbcountyga.gov/portal/Home/Dashboard/29#'
###########################################################################################

#Get date of last run
county=Dir.pwd.split("/").last
$most_recent_directory=Evictions::Utilities.get_most_recent_directory(county)
if $most_recent_directory != nil
  logged_run_date=File.open(File.join($most_recent_directory,"logs","list_scrape.log"), &:readline).split(" ")[4]
  last_run_date=Time.local(logged_run_date.split("-")[0],logged_run_date.split("-")[1].to_i,logged_run_date.split("-")[2].to_i)
  $start_date = last_run_date-60*60*24*30
else
  $start_date = Time.local(2018,1,1)
end


# make time stamp based directories
$current_time_as_time=Time.now
$now_time = Evictions::Utilities.set_up_files_and_folders(headers,county)



#global search_cache_path and csv path
$search_cache_path = File.join(File.dirname(__FILE__), $now_time, "search_cache")
$eviction_csv_name = File.join(File.dirname(__FILE__), $now_time, "csvs","evictions.csv")

#get the log going
LOG = Logger.new(File.join(File.dirname(__FILE__), $now_time, "logs","list_scrape.log"))
LOG.level = Logger::DEBUG
LOG.info("Start")

success = true #hopefully for use in setting off process stages
for $prefix in prefixs
    for $year in ($start_date.year-2000..$current_time_as_time.year-2000)
        search_string = "#{$year}#{$prefix}*"
        
        browser=restart_browser
        
        while search_string != nil
            LOG.info("#{search_string}")
            search_fails = 0
            search_exit = false
            while search_fails < 10 and search_exit == false
                begin
                    search_string = search_and_scrape(search_string,browser)
                    search_exit = true
                    success = true
                rescue => ex
                    search_fails+=1
                    LOG.info("failed on #{search_fails + 1} attempt")
                    LOG.info("#{ex.backtrace}: #{ex.message} (#{ex.class})")
                    
                    if search_fails == 5
                        LOG.info("failed 5 times, sleeping an hour")
                        sleep 60*60
                    end
                    
                    if search_fails == 7
                        LOG.info("failed 7 times, sleeping a day")
                        sleep 60*60*24
                    end 
                    
                    browser.close
                    browser=restart_browser
                    success = false
                end
            end
        end
    end
end

if success
    LOG.info("success")
else
    LOG.info("failure")
end
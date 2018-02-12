require 'watir'
require 'nokogiri'
require 'csv'
require 'logger'

def clean_text(element)
    if element.text.strip! == nil
        return_value=element.text   #appends string to list
    else
        return_value=element.text.strip!  #appends string to list
    end
    return return_value
end

def reformat_date(gem_date)
    return "#{gem_date.strftime("%m")}/#{gem_date.strftime("%d")}/#{gem_date.strftime("%Y")}"
end

def write_to_search_cache(html,date_start,date_end,page)
    search_cache = File.join($search_cache_path, "search_#{date_start.year}_#{date_start.month}_#{date_start.day}__#{date_end.year}_#{date_end.month}_#{date_end.day}_#{page}.html")
    open(search_cache, 'w'){|f| f << html }
end

def process_page(browser)
    noko_page = Nokogiri::HTML(browser.html);nil
    rows = noko_page.css('table#ctl00_ContentPlaceHolder1_GridView1').css('tr')
    CSV.open($csv_name,"a") do |csv|
        rows.each_with_index do |row,index|
            if index > 0
                case_attributes=[]
                case_attributes.push(clean_text(row.css('td')[0]))
                case_attributes.push(clean_text(row.css('td')[1]))
                case_attributes.push(clean_text(row.css('td')[2]))
                case_attributes.push(index-1)
                csv << case_attributes
            end
        end
    end
end

def search(browser,date_start,date_end)
    browser.text_field(id: 'ctl00_ContentPlaceHolder1_beginDate').set reformat_date(date_start)
    browser.text_field(id: 'ctl00_ContentPlaceHolder1_endDate').set reformat_date(date_end)
    browser.select_list(id: "ctl00_ContentPlaceHolder1_categoryList").select("26")
    browser.select_list(id: "ctl00_ContentPlaceHolder1_ddlPageSize").select("50")
    browser.button(id: "ctl00_ContentPlaceHolder1_Button1").click
    sleep 10
    return browser
end

def restart_browser(date_end)
    browser = Watir::Browser.new :chrome, headless: true
    browser.goto $url
    browser.text_field(id: 'ctl00_ContentPlaceHolder1_beginDate').set reformat_date(date_end)
    browser.text_field(id: 'ctl00_ContentPlaceHolder1_endDate').set reformat_date(date_end)
    browser.select_list(id: 'ctl00_ContentPlaceHolder1_courtList').select('MG')
    browser.button(id: "ctl00_ContentPlaceHolder1_Button1").click
    sleep 3
    return browser
end

def run_scraper(browser, date_start, date_end)
    LOG.info("searching #{reformat_date(date_start)} to #{reformat_date(date_end)}")
    browser=search(browser,date_start,date_end)
    if browser.html.downcase.include?"opps!"
        write_to_search_cache(browser.html,date_start,date_end,"#{counter.to_s}_opps")
        raise "Got Opps error page"
    else
        counter = 1
        write_to_search_cache(browser.html,date_start,date_end,counter.to_s)
        process_page(browser)
        counter+=1

        while browser.link(text: counter.to_s).exists?
            LOG.info("working on page #{counter}")
            browser.link(text: counter.to_s).click
            sleep 5
            write_to_search_cache(browser.html,date_start,date_end,counter.to_s)
            process_page(browser)
            counter+=1
        end
    end
end


# make time stamp based directories
$now_time = DateTime.now.strftime("%Y_%m_%d_%H_%M")
FileUtils.mkdir_p(File.join(File.dirname(__FILE__), $now_time))
FileUtils.mkdir_p(File.join(File.dirname(__FILE__), $now_time, "logs"))
FileUtils.mkdir_p(File.join(File.dirname(__FILE__), $now_time, "search_cache"))
FileUtils.mkdir_p(File.join(File.dirname(__FILE__), $now_time, "csvs"))

#global search_cache_path and csv path
$search_cache_path = File.join(File.dirname(__FILE__), $now_time, "search_cache")
$csv_name = File.join(File.dirname(__FILE__), $now_time, "csvs","evictions.csv")

#get the log going
LOG = Logger.new(File.join(File.dirname(__FILE__), $now_time, "logs","list_scrape.log"))
LOG.level = Logger::DEBUG
LOG.info("Start")


$url='https://www.gwinnettcourts.com/casesearch/advanced.aspx'


headers = ['case_number','case','category','number']
CSV.open($csv_name,"w") do |csv|
    csv << headers
end


date_end = Time.local($now_time.split("_").first,$now_time.split("_")[1],$now_time.split("_")[2])
date_start=date_end
date_terminate = Time.local(2017,1,1)
browser = restart_browser(date_end)
success = true
while date_start > date_terminate
    search_fails = 0
    search_exit = false
    date_end = date_start - 24*60*60
    date_start = date_end - 90*24*60*60
    if date_start <= date_terminate and date_end > date_terminate
        date_start = date_terminate
    end
    
    while search_fails < 10 and search_exit == false        
        begin
            run_scraper(browser, date_start, date_end)
            search_exit = true
            success=true
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
            browser = restart_browser(date_end)
            success = false
        end
    end
end

if success
    LOG.info("success")
else
    LOG.info("failure")
end
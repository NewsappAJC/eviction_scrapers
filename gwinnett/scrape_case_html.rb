require 'mechanize'
require 'nokogiri'
require 'socksify'
require 'net/telnet'
require 'csv'
require 'logger'

def get_html(case_number,form)
    form['ctl00$ContentPlaceHolder1$CaseNumber']=case_number
    result_page = form.submit()
    result_form = result_page.form()
    result_form['__EVENTTARGET']='ctl00$ContentPlaceHolder1$GridView1'
    result_form['__EVENTARGUMENT']='Select$0'
    case_page = result_form.submit()
    return case_page
end

def get_clean_form
    browser = Mechanize.new()
    browser.verify_mode = OpenSSL::SSL::VERIFY_NONE #deals with SSL issue that I get from this particular server
    browser.ssl_version = 'TLSv1'                   #deals with SSL issue that I get from this particular server
    browser.user_agent_alias = 'Linux Firefox'      #I've run into several servers that seem to throw issues when not encountering a recognized user agent
    reset_connection
    page=browser.get('https://www.gwinnettcourts.com/casesearch/bycasenumber.aspx')
    form=page.form()
    form['ctl00$ContentPlaceHolder1$Button1']='Search'
    form['ctl00$ContentPlaceHolder1$ddlPageSize']='10'
    return form
end

def get_clean_form_wrapper
    form_fail_counter = 0
    form_contains_correct_action = false
    while form_contains_correct_action==false and form_fail_counter < 6
        form=get_clean_form
        if form.action == "bycasenumber.aspx"
            form_contains_correct_action=true
        else
            form_fail_counter+=1
            LOG.info("form page error #{form_fail_counter}")
            sleep 3
        end
        
        if form_fail_counter == 6
            LOG.info("couldn't load form")
            break
        end
    end
    return form
end

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

#Gwinnett specific
form = get_clean_form_wrapper

evictions[1..-1].each do |eviction|
    case_number=eviction[0]
    if cached_files.include?(File.join($most_recent_directory, "case_cache","#{eviction[0]}.html"))
        LOG.info("already retrieved #{case_number}")
    else
        LOG.info("opening #{case_number}")
        get_fails = 0
        get_exit = false
        while get_exit==false and get_fails<5
            begin
                page = get_html(case_number,form)
                if page.body.downcase.include?("oops!")
                    if get_fails < 3
                        LOG.info("got opps #{get_fails} times on #{case_number}, sleep 2 minutes")
                        sleep 60*2
                    else
                        LOG.info("got opps #{get_fails} times on #{case_number}, sleep 5 minutes")
                        sleep 60*5
                    end
                    raise "got opps message"
                end
                get_exit=true
            rescue => ex
                LOG.info("failed on attempt #{get_fails + 1} on #{eviction.first} \n #{ex.backtrace}: #{ex.message} (#{ex.class})")
                Evictions::Utilities.reset_connection!
                form=get_clean_form_wrapper
                get_fails+=1
            end
        end
        
        if get_exit
            if page.body.downcase.include?("#{case_number.downcase}") == false
                LOG.info("didn't have case_number in it #{eviction.first}")
                eviction.push(step)
                eviction.push('case_number')
                CSV.open($issues_csv_name,"a") do |csv|
                    csv << eviction
                end
            end
            
            consecutive_case_fails = 0
            write_to_case_cache(page.body,eviction.first)
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
    

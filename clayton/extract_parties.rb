require 'nokogiri'
require 'csv'
require 'logger'

require_relative '../utilities.rb'

step=$0
county=Dir.pwd.split("/").last
$most_recent_directory=Evictions::Utilities.get_most_recent_directory(county)

LOG = Logger.new(File.join($most_recent_directory, "logs","extract_parties.log"))
LOG.level = Logger::DEBUG

LOG.info("Start")

evictions = CSV.read(File.join($most_recent_directory, "csvs",'evictions.csv'))
$issues_csv_name = File.join($most_recent_directory, "csvs","issues.csv")
$parties_csv_name = File.join($most_recent_directory, "csvs","parties.csv")

evictions[1..-1].each do |eviction|
  begin
  html = File.join($most_recent_directory,"case_cache","#{eviction[0]}.html")
  page = Nokogiri::HTML(File.open(html).read);nil
  last_party_side=''
  rows=page.css('table')[2].css('tr.body11')
  rows[0..-2].each do |row|
      if row.text.include?"Plaintiff"
        last_party_side='plaintiff'
      elsif row.text.include?("Defendant")
        last_party_side='defendant'
      end
        
      if row.css('td')[1].text.strip.length > 5
        party_attributes=[]
        party_attributes.push(eviction[0])
        party_attributes.push(last_party_side)

        if row.css('td')[1].css('div').length==1
          for child in row.css('td')[1].css('div')[0].children
            child_text=child.text.strip
            if child_text.strip != ''
              party_attributes.push(child_text)
            end
          end
        else
          party_attributes.push(row.css('td')[1].text.strip)
        end
        CSV.open($parties_csv_name,"a") do |csv|
          csv << party_attributes
        end
      end
        
      if row.css('td')[3].text.length > 6
        party_attributes=[]
        party_attributes=[]
        party_attributes.push(eviction[0])
        party_attributes.push("#{last_party_side} - attorney")
          
        if row.css('td')[3].css('div').length==1
          for child in row.css('td')[3].css('div')[0].children
            child_text=child.text.strip
            if child_text.strip != ''
              party_attributes.push(child_text)
            end
          end
        else
          party_attributes.push(row.css('td')[3].text.strip)
        end
        CSV.open($parties_csv_name,"a") do |csv|
          csv << party_attributes
        end
      end
    end
  rescue => ex
    LOG.info("failed parsing parties from #{eviction[0]}")
    LOG.info("#{ex.backtrace}: #{ex.message} (#{ex.class})")
    issue = ""
    if "#{ex.backtrace}: #{ex.message} (#{ex.class})".include?"No such file"
      issue = "no_file"
    else
      issue = "other"
    end
    
    CSV.open($issues_csv_name,"a") do |csv|
      csv << eviction + [step,issue]
    end
  end
end
    
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
    if page.text.downcase.include?("party")
      for row in page.css('ul#ctl00_ContentPlaceHolder1_ListView2_itemPlaceholderContainer')[0].css('li')
        party_attributes = []
        party_attributes.push(eviction[0])
        for child in row.children
          if child.text != "" and child.text != ") "
              party_attributes.push(child.text.strip)
          end
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

LOG.info("success")
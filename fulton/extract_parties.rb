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
      
      for row in page.css('div#divPartyInformation_body')[0].css('div.row')
        party_divs=row.css('div.col-md-8')
        attorney_divs = row.css('div.col-md-4')
        for div in party_divs
          party_attributes = []
          party_attributes.push(eviction[0])
          if div.text.downcase.include?("plaintiff")
            party_attributes.push("plaintiff")   #appends string to list
          else
            party_attributes.push("defendant")  #appends string to list
          end
          for p in [div.css('p').first,div.css('p').last]
            for child in p.children
              child_text=child.text.strip
              if child_text != "" and child_text[0..8] != "Plaintiff" and child_text[0..8] != "Defendant" 
                party_attributes.push(child_text)
              end
            end
          end
          CSV.open($parties_csv_name,"a") do |csv|
            csv << party_attributes
          end
        end
        for attorney_div in attorney_divs
          party_attributes = []
          party_attributes.push(eviction[0])
          if row.text.downcase.include?("plaintiff")
            party_attributes.push("plaintiff-attorney")   #appends string to list
          else
            party_attributes.push("defendant-attorney")  #appends string to list
          end
          party_attributes.push(attorney_div.css('div.tyler-toggle-container').text.strip)
          CSV.open($parties_csv_name,"a") do |csv|
            csv << party_attributes
          end
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
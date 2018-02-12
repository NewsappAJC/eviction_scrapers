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
    if page.text.downcase.include?("parties")
      target_table = page.css('table')[0]
      for table in page.css('table')
        if table.text.downcase.include?("expn date")
          target_table=table
        end
      end
    
      rows=target_table.css('tr')
      for row in rows
          if row['valign'] == 'top' and row['align']==nil
              party_attributes=[eviction[0],]
              if row.text.downcase.include?("attorney") and row.text.downcase.include?("plaintiff")
                  party_attributes.push("attorney - plaintiff")
              elsif row.text.downcase.include?("attorney") and row.text.downcase.include?("defendant")
                  party_attributes.push("attorney - defendant")
              elsif row.text.downcase.include?("plaintiff")
                  party_attributes.push("plaintiff")   #appends string to list
              elsif row.text.downcase.include?("defendant")
                  party_attributes.push("defendant")  #appends string to list
              else
                  party_attributes.push("other")
              end
            
            party_attributes.push(row.css('td').last.text.strip)   #gets name
          elsif row['align']=='left'
              party_attributes.push(row.css('td')[3].text.strip)
              for child in row.css('td')[1].children
                child_text=child.text.strip
                  if child_text != ""
                      if child_text.gsub("-","").gsub(")","").gsub("(","").gsub(" ","").gsub("+","").to_i >1000000
                          party_attributes.push("PHONE: #{child_text}")
                      else
                          party_attributes.push(child_text)
                      end
                  end
              end
              CSV.open($parties_csv_name,"a") do |csv|
                csv << party_attributes
              end
          end
      end
    else
      raise "no parties"
    end
  rescue => ex
    LOG.info("failed parsing parties from #{eviction[0]}")
    LOG.info("#{ex.backtrace}: #{ex.message} (#{ex.class})")
    issue = ""
    if "#{ex.backtrace}: #{ex.message} (#{ex.class})".include?"No such file"
      issue = "no_file"
    elsif "#{ex.backtrace}: #{ex.message} (#{ex.class})".include?"no parties"
      issue = "no_parties"
    else
      issue = "other"
    end
    
    CSV.open($issues_csv_name,"a") do |csv|
      csv << eviction + [step,issue]
    end
  end
end
    
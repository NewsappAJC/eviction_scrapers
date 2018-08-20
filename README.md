Eviction Case Scrapers
======================

Jeff started this repo with an eye toward one day building an automatic process for reproducing and updating the evictions database. But, then he left/it seems like the appetite probably wasn't there to build this out.

The programs scrape eviction court cases from Clayton, Cobb, DeKalb, Fulton and Gwinnett counties' magistrate court websites since the last time it ran (with some margin of error into the past, I believe, because of how some websites were set up). In the case of the latter 3, one program (list_scraper.rb) scrapes a list of cases and another (scrape_case_html.rb) goes back and grabs the full HTML page for each case. In the case of Cobb and Clayton, the scraper scrapes cases by incrementing upward, so, it gets the full HTML in the first pass. For all counties, another program (extract_parties.rb) extracts parties to each case.

One could quite easily repurpose these to scrape other kinds of cases. Just change the search criteria.

For what it is worth, I doubt anyone is going to really operate these. But, if they are interested, I would recommend augumenting this code with code from my repo "ruby_scraping". In there, you'll find folders ending in "magistrate" for each of these counties. In those, you'll find files labeled something like "extract_events" or "extract_docket_info" which would complete the picture by extracting additional information on what happened in each case.

Additionally, if one is interested and doesn't have much experience in scraping, I'd say that these are probably the most principled scrapers I made at the AJC. They incorporate everything I'd learned up to this point about scraping. It does things like:

+ running through Tor (when possible - not in Fulton or DeKalb) so that IP addresses change up routinely and we don't get the AJC blocked
+ running on headless chrome browsers where necessary (Fulton and DeKalb), so, one could learn how Watir works
+ pretty good logging logic
+ self-contained: it's made to run on a server and be able to eventually be set up to update automatically
+ things are more or less broken off in rational ways to make functions that are able to be reused


Anyway, just to get this up and running, install RVM and get your environment straight (ask John if you need help with this) and then you can run "bundle install" to install the necessary gems to run the scrapers. I'd recommend tweaking the date criteria to match the timeframe that interests you as well.

Best wishes!

Jeff
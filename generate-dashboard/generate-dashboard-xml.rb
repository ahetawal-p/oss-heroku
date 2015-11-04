#!/usr/bin/env ruby

require 'rubygems'
require 'sqlite3'
require 'date'
require 'yaml'

# Generate a data file for a GitHub organizations.
# It contains the metadata for the organization, and the metrics.
def generate_dashboard_xml(dashboard_config, client)
  
  organizations = dashboard_config['organizations']
  data_directory = dashboard_config['data-directory']
  private_access = dashboard_config['private-access']
  unless(private_access)
    private_access = []
  end
  reports = dashboard_config['reports']
  
  sync_db=SQLite3::Database.new(File.join(data_directory, 'db/gh-sync.db'));
  
  unless(File.exists?("#{data_directory}/dash-xml/"))
    Dir.mkdir("#{data_directory}/dash-xml/")
  end
  
  # First, generate the metadata needed to build navigation
  # Which other orgs form a part of this site?
  metadata = " <metadata>\n"
  metadata << "  <navigation>\n"
  organizations.each do |org|
    metadata << "    <organization>#{org}</organization>\n"
  end
  metadata << "  </navigation>\n"
  
  # Which Source Reports are configured?
  metadata << "  <reports>\n"
  reports.each do |report|
    metadata << "    <report>#{report}</report>\n"
  end
  metadata << "  </reports>\n"
  
  metadata << " </metadata>\n"
  
  organizations.each do |org|
    dashboard_file=File.open("#{data_directory}/dash-xml/#{org}.xml", 'w')
  
    dashboard_file.puts "<github-dashdata dashboard='#{org}' includes_private='#{private_access.include?(org)}'>"
    dashboard_file.puts metadata
    dashboard_file.puts " <organization name='#{org}'>"
  
    # Generate XML for Team data if available
    teams=sync_db.execute("SELECT DISTINCT(t.id), t.name, t.description FROM team t, repository r, team_to_repository ttr WHERE t.id=ttr.team_id AND ttr.repository_id=r.id AND r.org=?", [org])
    teams.each do |teamRow|
      # TODO: Indicate if a team has read-only access to a repo, not write.
      escaped=teamRow[1].gsub(/[ \/&:]/, '_')
      dashboard_file.puts "  <team escaped_name='#{escaped}' name='#{teamRow[1]}'>"
      desc=teamRow[2]
      if(desc)
        desc=desc.gsub(/&/, "&amp;").gsub(/</, "&lt;").gsub(/>/, "&gt;")
      end
      dashboard_file.puts "    <description>#{desc}</description>"
  
      # Load the ids for repos team has access to
      repos=sync_db.execute("SELECT r.name FROM team_to_repository ttr, repository r WHERE ttr.team_id=? AND ttr.repository_id=r.id AND r.fork=0", [teamRow[0]])
      dashboard_file.puts "    <repos>"
      repos.each do |teamRepoRow|
        dashboard_file.puts "        <repo>#{teamRepoRow[0]}</repo>"
      end
      dashboard_file.puts "    </repos>"
  
      # Load the ids for the members of the team
      members=sync_db.execute("SELECT m.login FROM team_to_member ttm, member m WHERE ttm.team_id=? AND ttm.member_id=m.id", [teamRow[0]])
      dashboard_file.puts "    <members>"
      members.each do |teamMemberRow|
        dashboard_file.puts "      <member>#{teamMemberRow[0]}</member>"
      end
      dashboard_file.puts "    </members>"
      dashboard_file.puts "  </team>"
    end
  
  
    # Generate XML for Repo data, including time-indexed metrics
    # TODO: How to integrate internal ticketing mapping
    repos=sync_db.execute("SELECT id, name, homepage, private, fork, has_wiki, language, stars, watchers, forks, created_at, updated_at, pushed_at, size, description FROM repository WHERE org=?", [org])
    repos.each do |repoRow|
      repoName=repoRow[1]
      # TODO: Add open ones
   # BUG? Might need to be org/repo for repo and not repo[1]
      closedIssueCount=sync_db.execute( "SELECT COUNT(*) FROM issues WHERE org='#{org}' AND repo='#{repoRow[1]}' AND state='closed'" )[0][0]
      privateRepo=(repoRow[3]==1)
      isFork=(repoRow[4]==1)
      hasWiki=(repoRow[5]==1)
      closedPullRequestCount=sync_db.execute( "SELECT COUNT(*) FROM pull_requests WHERE org='#{org}' AND repo='#{repoRow[1]}' AND state='closed'" )[0][0]
      dashboard_file.puts "  <repo name='#{repoRow[1]}' homepage='#{repoRow[2]}' private='#{privateRepo}' fork='#{isFork}' closed_issue_count='#{closedIssueCount}' closed_pr_count='#{closedPullRequestCount}' open_issue_count='???' has_wiki='#{hasWiki}' language='#{repoRow[6]}' stars='#{repoRow[7]}' watchers='#{repoRow[8]}' forks='#{repoRow[9]}' created_at='#{repoRow[10]}' updated_at='#{repoRow[11]}' pushed_at='#{repoRow[12]}' size='#{repoRow[13]}'>"
      desc=repoRow[14].gsub(/&/, "&amp;").gsub(/</, "&lt;").gsub(/>/, "&gt;")
      dashboard_file.puts "    <description>#{desc}</description>"
  
  
        # Get the issues specifically
        issues=sync_db.execute("SELECT id, item_number, assignee_login, user_login, state, title, body, org, repo, created_at, updated_at, comment_count, pull_request_url, merged_at, closed_at FROM items WHERE org=? AND repo=? AND state='open'", [org, "#{org}/#{repoName}"])
        dashboard_file.puts "    <issues count='#{issues.length}'>"
        issues.each do |issueRow|
          isPR=(issueRow[12] != nil)
          title=issueRow[5].gsub(/&/, "&amp;").gsub(/</, "&lt;")
          age=((Time.now - Time.parse(issueRow[9])) / (60 * 60 * 24)).round
          internal=sync_db.execute("SELECT employee_email FROM member WHERE login=?", [issueRow[3]])
          unless(internal.empty? or internal.any?)
            amznLogin=internal[0][0].split('@')[0]
            internalText=" internal='#{amznLogin}'"
          end
          # TODO: Add labels as a child of issue.
          dashboard_file.puts "      <issue id='#{issueRow[0]}' number='#{issueRow[1]}' user='#{issueRow[3]}' state='#{issueRow[4]}' created_at='#{issueRow[9]}' age='#{age}' updated_at='#{issueRow[10]}' pull_request='#{isPR}' comments='#{issueRow[11]}'#{internalText}>#{title}</issue>"
        end
        dashboard_file.puts "    </issues>"
    
        # Issue + PR Reports
        dashboard_file.puts "  <issue-data id='#{repoRow[1]}'>"
        orgRepo="#{org}/#{repoRow[1]}"
        # Yearly Issues Opened
        openedIssues=sync_db.execute( "SELECT strftime('%Y',created_at) as year, COUNT(*) FROM issues WHERE org='#{org}' AND repo='#{orgRepo}' AND state='open' GROUP BY year ORDER BY year DESC" )
        openedIssues.each do |issuecount|
          dashboard_file.puts "    <issues-opened id='#{orgRepo}' year='#{issuecount[0]}' count='#{issuecount[1]}'/>"
        end
        closedIssues=sync_db.execute( "SELECT strftime('%Y',closed_at) as year, COUNT(*) FROM issues WHERE org='#{org}' AND repo='#{orgRepo}' AND state='closed' GROUP BY year ORDER BY year DESC" )
     closedIssues.each do |issuecount|
          dashboard_file.puts "    <issues-closed id='#{orgRepo}' year='#{issuecount[0]}' count='#{issuecount[1]}'/>"
        end
      
        # Yearly Pull Requests 
        openedPrs=sync_db.execute( "SELECT strftime('%Y',created_at) as year, COUNT(*) FROM pull_requests WHERE org='#{org}' AND repo='#{orgRepo}' AND state='open' GROUP BY year ORDER BY year DESC" )
        openedPrs.each do |prcount|
          dashboard_file.puts "    <prs-opened id='#{orgRepo}' year='#{prcount[0]}' count='#{prcount[1]}'/>"
        end
        closedPrs=sync_db.execute( "SELECT strftime('%Y',closed_at) as year, COUNT(*) FROM pull_requests WHERE org='#{org}' AND repo='#{orgRepo}' AND state='closed' GROUP BY year ORDER BY year DESC" )
        closedPrs.each do |prcount|
          dashboard_file.puts "    <prs-closed id='#{orgRepo}' year='#{prcount[0]}' count='#{prcount[1]}'/>"
        end
    
        # Time to Close
        # TODO: Get rid of the copy and paste here
        dashboard_file.puts "    <age-count>"
        # 1 hour  = 0.0417
        ageCount=sync_db.execute( "SELECT COUNT(*) FROM issues WHERE julianday(closed_at) - julianday(created_at) < 0.0417 AND org='#{org}' AND repo='#{orgRepo}' AND state='closed'" )
        dashboard_file.puts "      <issue-count age='1 hour'>#{ageCount[0][0]}</issue-count>"
        # 3 hours = 0.125
        ageCount=sync_db.execute( "SELECT COUNT(*) FROM issues WHERE julianday(closed_at) - julianday(created_at) > 0.0417 AND julianday(closed_at) - julianday(created_at) <= 0.125 AND org='#{org}' AND repo='#{orgRepo}' AND state='closed'" )
        dashboard_file.puts "      <issue-count age='3 hours'>#{ageCount[0][0]}</issue-count>"
        # 9 hours = 0.375
        ageCount=sync_db.execute( "SELECT COUNT(*) FROM issues WHERE julianday(closed_at) - julianday(created_at) > 0.125 AND julianday(closed_at) - julianday(created_at) <= 0.375 AND org='#{org}' AND repo='#{orgRepo}' AND state='closed'" )
        dashboard_file.puts "      <issue-count age='9 hours'>#{ageCount[0][0]}</issue-count>"
        # 1 day
        ageCount=sync_db.execute( "SELECT COUNT(*) FROM issues WHERE julianday(closed_at) - julianday(created_at) > 0.375 AND julianday(closed_at) - julianday(created_at) <= 1 AND org='#{org}' AND repo='#{orgRepo}' AND state='closed'" )
        dashboard_file.puts "      <issue-count age='1 day'>#{ageCount[0][0]}</issue-count>"
        # 7 days
        ageCount=sync_db.execute( "SELECT COUNT(*) FROM issues WHERE julianday(closed_at) - julianday(created_at) > 1 AND julianday(closed_at) - julianday(created_at) <= 7 AND org='#{org}' AND repo='#{orgRepo}' AND state='closed'" )
        dashboard_file.puts "      <issue-count age='1 week'>#{ageCount[0][0]}</issue-count>"
        # 30 days
        ageCount=sync_db.execute( "SELECT COUNT(*) FROM issues WHERE julianday(closed_at) - julianday(created_at) > 7 AND julianday(closed_at) - julianday(created_at) <= 30 AND org='#{org}' AND repo='#{orgRepo}' AND state='closed'" )
        dashboard_file.puts "      <issue-count age='1 month'>#{ageCount[0][0]}</issue-count>"
        # 90 days
        ageCount=sync_db.execute( "SELECT COUNT(*) FROM issues WHERE julianday(closed_at) - julianday(created_at) > 30 AND julianday(closed_at) - julianday(created_at) <= 90 AND org='#{org}' AND repo='#{orgRepo}' AND state='closed'" )
        dashboard_file.puts "      <issue-count age='1 quarter'>#{ageCount[0][0]}</issue-count>"
        # 355 days
        ageCount=sync_db.execute( "SELECT COUNT(*) FROM issues WHERE julianday(closed_at) - julianday(created_at) > 90 AND julianday(closed_at) - julianday(created_at) <= 365 AND org='#{org}' AND repo='#{orgRepo}' AND state='closed'" )
        dashboard_file.puts "      <issue-count age='1 year'>#{ageCount[0][0]}</issue-count>"
        # over a year
        ageCount=sync_db.execute( "SELECT COUNT(*) FROM issues WHERE julianday(closed_at) - julianday(created_at) > 365 AND org='#{org}' AND repo='#{orgRepo}' AND state='closed'" )
        dashboard_file.puts "      <issue-count age='over 1 year'>#{ageCount[0][0]}</issue-count>"
        # REPEATING FOR PRs
        # 1 hour  = 0.0417
        ageCount=sync_db.execute( "SELECT COUNT(*) FROM pull_requests WHERE julianday(closed_at) - julianday(created_at) < 0.0417 AND org='#{org}' AND repo='#{orgRepo}' AND state='closed'" )
        dashboard_file.puts "      <pr-count age='1 hour'>#{ageCount[0][0]}</pr-count>"
        # 3 hours = 0.125
        ageCount=sync_db.execute( "SELECT COUNT(*) FROM pull_requests WHERE julianday(closed_at) - julianday(created_at) > 0.0417 AND julianday(closed_at) - julianday(created_at) <= 0.125 AND org='#{org}' AND repo='#{orgRepo}' AND state='closed'" )
        dashboard_file.puts "      <pr-count age='3 hours'>#{ageCount[0][0]}</pr-count>"
        # 9 hours = 0.375
        ageCount=sync_db.execute( "SELECT COUNT(*) FROM pull_requests WHERE julianday(closed_at) - julianday(created_at) > 0.125 AND julianday(closed_at) - julianday(created_at) <= 0.375 AND org='#{org}' AND repo='#{orgRepo}' AND state='closed'" )
        dashboard_file.puts "      <pr-count age='9 hours'>#{ageCount[0][0]}</pr-count>"
        # 1 day
        ageCount=sync_db.execute( "SELECT COUNT(*) FROM pull_requests WHERE julianday(closed_at) - julianday(created_at) > 0.375 AND julianday(closed_at) - julianday(created_at) <= 1 AND org='#{org}' AND repo='#{orgRepo}' AND state='closed'" )
        dashboard_file.puts "      <pr-count age='1 day'>#{ageCount[0][0]}</pr-count>"
        # 7 days
        ageCount=sync_db.execute( "SELECT COUNT(*) FROM pull_requests WHERE julianday(closed_at) - julianday(created_at) > 1 AND julianday(closed_at) - julianday(created_at) <= 7 AND org='#{org}' AND repo='#{orgRepo}' AND state='closed'" )
        dashboard_file.puts "      <pr-count age='1 week'>#{ageCount[0][0]}</pr-count>"
        # 30 days
        ageCount=sync_db.execute( "SELECT COUNT(*) FROM pull_requests WHERE julianday(closed_at) - julianday(created_at) > 7 AND julianday(closed_at) - julianday(created_at) <= 30 AND org='#{org}' AND repo='#{orgRepo}' AND state='closed'" )
        dashboard_file.puts "      <pr-count age='1 month'>#{ageCount[0][0]}</pr-count>"
        # 90 days
        ageCount=sync_db.execute( "SELECT COUNT(*) FROM pull_requests WHERE julianday(closed_at) - julianday(created_at) > 30 AND julianday(closed_at) - julianday(created_at) <= 90 AND org='#{org}' AND repo='#{orgRepo}' AND state='closed'" )
        dashboard_file.puts "      <pr-count age='1 quarter'>#{ageCount[0][0]}</pr-count>"
        # 355 days
        ageCount=sync_db.execute( "SELECT COUNT(*) FROM pull_requests WHERE julianday(closed_at) - julianday(created_at) > 90 AND julianday(closed_at) - julianday(created_at) <= 365 AND org='#{org}' AND repo='#{orgRepo}' AND state='closed'" )
        dashboard_file.puts "      <pr-count age='1 year'>#{ageCount[0][0]}</pr-count>"
        # over a year
        ageCount=sync_db.execute( "SELECT COUNT(*) FROM pull_requests WHERE julianday(closed_at) - julianday(created_at) > 365 AND org='#{org}' AND repo='#{orgRepo}' AND state='closed'" )
        dashboard_file.puts "      <pr-count age='over 1 year'>#{ageCount[0][0]}</pr-count>"
        dashboard_file.puts "    </age-count>"
    
        dashboard_file.puts "  </issue-data>"
    
        dashboard_file.puts "  <release-data>"
        releases=sync_db.execute( "SELECT DISTINCT(id), html_url, name, published_at, author FROM releases WHERE org='#{org}' AND repo='#{repoRow[1]}' ORDER BY published_at DESC" )
        releases.each do |release|
          dashboard_file.puts "    <release id='#{release[0]}' url='#{release[1]}' name='#{release[2]}' published_at='#{release[3]}' author='#{release[4]}'/>"
        end
        dashboard_file.puts "  </release-data>"
    
    
      dashboard_file.puts "  </repo>"
    end
  
    # Generate XML for Member data
    # TODO: This is available for non-private too, just not stored in the DB
    members=sync_db.execute("SELECT DISTINCT(login), two_factor_disabled, employee_email FROM member m, repository r, team_to_member ttm, team_to_repository ttr WHERE m.id=ttm.member_id AND ttm.team_id=ttr.team_id AND ttr.repository_id=r.id AND r.org=?", [org])
    members.each do |memberRow|  
      # TODO: Include whether the individual is in ldap
      dashboard_file.puts "  <member name='#{memberRow[0]}' employee_email='#{memberRow[2]}' disabled_2fa='#{memberRow[1]}'/>"
    end
  
    # Copy the review xml into the dashboard xml
    # TODO: This is clunky, but simpler than having xslt talk to more than one file at a time. Replace this, possibly along with XSLT.
    #       Quite possible that there's no need for the review xml file to be separate in the first place.
    dashboard_file.puts File.open("#{data_directory}/review-xml/#{org}.xml").read
  
    dashboard_file.puts " </organization>"
    dashboard_file.puts "</github-dashdata>"
  end

end

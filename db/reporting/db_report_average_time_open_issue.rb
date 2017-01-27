
class AverageIssueOpenedDbReporter < DbReporter

  def name()
    return "Average Issue Time Opened"
  end

  def report_class()
    return 'issue-report'
  end

  def describe()
    return "This report shows the average time each repo's open issues have been opened"
  end

  def db_columns()
    return [ ['Repo', 'org/repo'], "Count of open issues", "Average age of open issues" ]
  end

  def db_report(context, org, sync_db)

    text = ""
    issue_query="SELECT repo, COUNT(id), ROUND(AVG(now()::date - created_at::date)::numeric, 2) as age FROM issues WHERE state='open' AND org=? GROUP BY org, repo ORDER BY age"

    issue_data=sync_db[issue_query, org]
    issue_data.each do |row|
      text << "  <reporting class='issue-report' repo='#{org}/#{row[:repo]}' type='AverageIssueOpenedDbReporter'><field>#{org}/#{row[:repo]}</field><field>#{row[:count]}</field><field>#{row[:age].to_s('f')}</field></reporting>\n"
    end
    return text
  end

end

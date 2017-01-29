require_relative '../util.rb'

def reset_store_html(sync_db, endpoint)
	sync_db[ "DELETE FROM result_store where endpoint=?", endpoint].delete
end

def store_html(context, endpoint, html_content)
	sync_db = get_db_handle(context.dashboard_config)
	begin
		sync_db.transaction do
			reset_store_html(sync_db, endpoint)
			sync_db[ "INSERT INTO result_store (endpoint, html) VALUES (?, ?)", endpoint, html_content].insert
			context.feedback.print "Updated html content for #{endpoint} \n"
		end
	end
	rescue => e
      puts "Error during processing: #{$!}"
      puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
end

namespace :linuxfr do
  desc "Daily crontab"
  task :daily => [
    :delete_old_passive_accounts,
    :daily_karma,
    'sitemap:refresh',
    'friendly_id:remove_old_slugs'
  ]

  desc "New day => update karma and give new votes"
  task :daily_karma => :environment do
    Account.find_each {|a| a.daily_karma }
  end

  desc "Delete old accounts that were never activated"
  task :delete_old_passive_accounts => :environment do
    Account.unconfirmed.where(["created_at <= ?", DateTime.now - 1.day]).delete_all
  end
end

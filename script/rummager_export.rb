#!/usr/bin/env ruby
# Export, to stdout, a dump of all data needed to rebuild search indexes.
# By default, exports the data for the "government" search index.  If the
# --detailed flag is supplied on the command line, exports the data for the
# "detailed" search index.

$LOAD_PATH << File.expand_path("../", File.dirname(__FILE__))

require 'logger'
logger = Logger.new(STDERR)
logger.info "Booting rails..."
require 'config/environment'
logger.info "Booted"

classes_to_index = if ARGV.include?("--detailed")
  Whitehall.searchable_classes_for_detailed_guides_index
else
  Whitehall.searchable_classes_for_government_index
end

logger.info "Counting docs to index..."
counts_by_class = classes_to_index.each_with_object({}) do |klass, hash|
  count = klass.searchable_instances.count
  logger.info("%20s: %d" % [klass.name, count])
  hash[klass] = count
end

total_count = counts_by_class.values.inject(&:+)

start = Time.zone.now
done = 0
classes_to_index.each do |klass|
  batch_start = Time.zone.now
  rate = [done / (batch_start - start), 0.1].max
  count = counts_by_class[klass]
  total_remaining = total_count - done
  total_time_remaining = (total_count - done) / rate
  time_remaining_this_batch = count / rate
  eta = batch_start + total_time_remaining
  logger.info "Exporting #{klass.name} (this batch of #{count} will take #{time_remaining_this_batch}s. #{total_remaining} to go will eta #{eta})"
  association = klass.searchable_instances

  eager_loads = [:document, :organisations, :attachments, :world_locations]
  eager_loads.each do |sym|
    if klass.reflect_on_association(sym)
      association = association.includes(sym)
    end
  end
  i = 0
  association.find_each do |obj|
    s = obj.search_index
    puts %Q[{"index": {"_type": "edition", "_id": "#{s['link']}"}}]
    puts s.to_json
    if i > 0 and i % 1000 == 0
      logger.info " .. #{i}"
    end
    done += 1
    i += 1
  end
  batch_took = Time.zone.now - batch_start
  logger.info("Export of %s complete in %.1fs rate %.2f/s (estimated %.1fs)" % [klass.name, batch_took, count / batch_took, time_remaining_this_batch])
end

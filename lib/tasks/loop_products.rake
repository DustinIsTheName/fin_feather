task :loop_products, [:test] => :environment do |t, args|
  rem = args[:test] || 0

  if Time.now.hour % 3 == rem.to_i
    puts "running"
    axis = Axis.new
    axis.delay.loop_products
  else
    puts "not the time"
  end
end
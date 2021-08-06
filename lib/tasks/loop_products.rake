task :loop_products => :environment do |t, args|
  if Time.now.hour % 3 == 0
    puts "running"
    axis = Axis.new
    axis.loop_products
  else
    puts "not the time"
  end
end
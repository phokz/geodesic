#!/usr/bin/env ruby

require 'roo'
require 'pry'

file = 'input.xlsx'

#tower_center = { lat: 13.03058, lon: 7.547028}; tower_height = 100 # Katsina
tower_center = { lat: 9.649857218502738, lon: 6.515274651228064 }; tower_height = 74.0 # Niger


xlsx = Roo::Spreadsheet.open(file)
sheet  = xlsx.sheet(0)
b = false
sheet.each_row_streaming do |item|
 state = item[1].value
 facility = item[2].value.downcase.gsub(/[^a-z]/,'_')
 lat = item[6].value
 lon = item[7].value
 next if state != 'Niger'
 puts "./runme3.rb #{facility} #{tower_center[:lat]} #{tower_center[:lon]} #{lat} #{lon} #{tower_height} 250"
 system "./runme3.rb", facility, tower_center[:lat].to_s, tower_center[:lon].to_s, lat.to_s, lon.to_s, tower_height.to_s, 250.to_s
end

